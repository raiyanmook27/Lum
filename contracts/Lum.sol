// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./ILum.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
    bytes32[] private groups;
    mapping(bytes32 => Group) private groupsById;
    mapping(bytes32 => Member[]) private group_mems;
    mapping(bytes32 => uint256) private group_balances;
    //bytes32 private _name;
    uint8 private constant NUM_MEMBERS = 4;

    //string private immutable i_duration;

    /***********MODIFIERS***********/
    /**
     * @dev modifier to check if the group exist
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkGroupExist(bytes32 _id) {
        require(groupsById[_id].id == _id, "Group doesn't exist");
        _;
    }

    /**
     * @dev modifier to check if the group is full
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkMembersFull(bytes32 _id) {
        require(group_mems[_id].length < groupsById[_id].number_of_members, "Group is full");
        _;
    }

    /**
     * @dev check if caller is a member
     */
    modifier checkIfMemberExist(bytes32 groupId, address caller) {
        uint256 mem_length = group_mems[groupId].length;
        bool is_exist;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (group_mems[groupId][i].mem_Address == caller) {
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
        uint256 mem_length = group_mems[groupId].length;
        bool has_paid;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (group_mems[groupId][i].paid_status == STATUS.PAID) {
                has_paid = true;
            }
        }
        if (has_paid) {
            revert Lum__CallerNonExistent();
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
        bytes32 id = keccak256(abi.encode(_name, msg.sender, NUM_MEMBERS));
        //check if it calls saves gas
        groups.push(id);
        groupsById[id] = Group(id, _name, NUM_MEMBERS);
        group_mems[id].push(Member(msg.sender, STATUS.NOT_PAID));
        emit GroupCreated(id);
    }

    function numberOfGroups() external view override returns (uint256) {
        return groups.length;
    }

    function joinGroup(bytes32 groupId)
        external
        override
        checkGroupExist(groupId)
        checkMembersFull(groupId)
    {
        group_mems[groupId].push(Member(msg.sender, STATUS.NOT_PAID));
        emit GroupJoined(groupId, msg.sender);
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
        uint256 amount = msg.value;
        if (amount == 0) {
            revert Lum__NotEnoughEth();
        }

        group_balances[groupId] += amount;

        paymentStatus(groupId, msg.sender);

        emit GroupFunded(msg.sender, groupId, msg.value);
    }

    function paymentStatus(bytes32 groupId, address memberAddress) private {
        uint256 mem_length = group_mems[groupId].length;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (group_mems[groupId][i].mem_Address == memberAddress) {
                group_mems[groupId][i].paid_status = STATUS.PAID;
            }
        }
    }

    function getGroupId(uint256 num) external view override returns (bytes32) {
        return groups[num];
    }

    function getNum_Members() external pure override returns (uint256) {
        return NUM_MEMBERS;
    }

    // /**
    //  * @dev Returns the details of a group based on 'groupId'.
    //  */
    function groupDetails(bytes32 groupId) external view returns (Group memory) {
        return groupsById[groupId];
    }

    function NumberOfGroupMembers(bytes32 groupId) external view override returns (uint256) {
        return group_mems[groupId].length;
    }

    function balanceOf(bytes32 groupId) external view override returns (uint256) {
        return group_balances[groupId];
    }
}
