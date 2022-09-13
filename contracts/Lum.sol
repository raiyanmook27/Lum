// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./ILum.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

/***************ERRORS****************/
error Lum__CallerNonExistent();
error Lum__CallerAlreadyPaid();
error Lum__NotEnoughEth();

/**
 * @dev * A contract that creates a group of users who can deposit funds into contract
 * daily and every week a member of the group is sent all the funds, the process starts again.
 * till every member of the group gets paid.
 *
 */
contract Lum is Context, ILum, ReentrancyGuard {
    /***********ENUMS**********************/
    enum STATUS {
        PAID,
        NOT_PAID
    }

    /**************STRUCTS****************/
    struct Group {
        bytes32 id;
        string name;
        uint8 number_of_members;
    }

    struct Member {
        address mem_Address;
        STATUS paid_status;
    }

    /********STATE VARIABLES***********/
    bytes32[] private s_group;
    mapping(bytes32 => Group) private s_groupById;
    mapping(bytes32 => Member[]) private s_group_mems;
    mapping(bytes32 => uint256) private s_group_balances;
    uint8 private constant NUM_MEMBERS = 4;
    uint256 private LumDuration = 10 seconds;

    //string private immutable i_duration;

    /***********MODIFIERS***********/
    /**
     * @dev modifier to check if the group exist
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkGroupExist(bytes32 _id) {
        require(s_groupById[_id].id == _id, "Group doesn't exist");
        _;
    }

    /**
     * @dev modifier to check if the group is full
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkMembersFull(bytes32 _id) {
        require(s_group_mems[_id].length < s_groupById[_id].number_of_members, "Group is full");
        _;
    }

    /**
     * @dev check if caller is a member
     */
    modifier checkIfMemberExist(bytes32 groupId, address caller) {
        uint256 mem_length = s_group_mems[groupId].length;
        bool is_exist;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (s_group_mems[groupId][i].mem_Address == caller) {
                is_exist = true;
            }
        }
        if (!is_exist) {
            revert Lum__CallerNonExistent();
        }
        _;
    }

    /**
     * @dev check if caller already paid
     */
    modifier checkIfMemberAlreadyPaid(bytes32 groupId, address caller) {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;
        bool has_paid;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (members[i].mem_Address == caller && members[i].paid_status == STATUS.PAID) {
                has_paid = true;
            }
        }
        if (has_paid) {
            revert Lum__CallerAlreadyPaid();
        }
        _;
    }

    // /**
    //  * @dev Sets the value {name}.
    //  *
    //  * @notice name is immutable can only be set once during
    //  * construction
    //  */
    // constructor(bytes32 name) {
    //     _name = name;
    // }

    /**
     * @dev see {ILum.sol-createGroup}.
     *
     */
    function createGroup(string memory _name) external override {
        bytes32 id = keccak256(abi.encode(_name, _msgSender(), NUM_MEMBERS));
        //check if it calls saves gas
        s_group.push(id);
        s_groupById[id] = Group(id, _name, NUM_MEMBERS);
        s_group_mems[id].push(Member(_msgSender(), STATUS.NOT_PAID));
        emit GroupCreated(id);
    }

    /**
     * @dev see {ILum.sol-startLum}.
     */
    function startLum() external override {}

    function numberOfGroups() external view override returns (uint256) {
        return s_group.length;
    }

    function joinGroup(bytes32 groupId)
        external
        override
        checkGroupExist(groupId)
        checkMembersFull(groupId)
    {
        s_group_mems[groupId].push(Member(_msgSender(), STATUS.NOT_PAID));
        emit GroupJoined(groupId, _msgSender());
    }

    function depositFunds(bytes32 groupId)
        public
        payable
        override
        nonReentrant
        checkGroupExist(groupId)
        checkIfMemberExist(groupId, msg.sender)
        checkIfMemberAlreadyPaid(groupId, msg.sender)
    {
        if (msg.value == 0) {
            revert Lum__NotEnoughEth();
        }

        s_group_balances[groupId] += msg.value;

        UpdatePaymentStatus(groupId, msg.sender);

        emit GroupFunded(msg.sender, groupId, msg.value);
    }

    function getMemberPaymentStatus(address member_Address, bytes32 groupId)
        public
        view
        returns (STATUS paymentStat)
    {
        Member[] storage members = s_group_mems[groupId];
        uint256 mem_length = members.length;

        for (uint256 i = 0; i < mem_length; ++i) {
            if (members[i].mem_Address == member_Address) {
                paymentStat = members[i].paid_status;
            }
        }
    }

    function UpdatePaymentStatus(bytes32 groupId, address memberAddress) private {
        Member[] storage members = s_group_mems[groupId];

        uint256 mem_length = members.length;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (members[i].mem_Address == memberAddress) {
                members[i].paid_status = STATUS.PAID;
            }
        }
    }

    function getGroupId(uint256 num) external view override returns (bytes32) {
        return s_group[num];
    }

    function getNum_Members() external pure override returns (uint256) {
        return NUM_MEMBERS;
    }

    // /**
    //  * @dev Returns the details of a group based on 'groupId'.
    //  */
    function groupDetails(bytes32 groupId) external view returns (Group memory) {
        return s_groupById[groupId];
    }

    function NumberOfGroupMembers(bytes32 groupId) external view override returns (uint256) {
        return s_group_mems[groupId].length;
    }

    function balanceOf(bytes32 groupId) external view override returns (uint256) {
        return s_group_balances[groupId];
    }
}
