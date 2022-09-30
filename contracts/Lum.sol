// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./ILum.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/***************ERRORS****************/
error Lum__CallerNonExistent();
error Lum__CallerAlreadyPaid();
error Lum__NotEnoughEth();
error Lum__UpkeepNotNeeded();
error Lum_NotAllMembersPaid();
error Lum__CallerAlreadyWithdrew();
error Lum__TransferFailed();

/**
 * @title Lum
 * @dev * A contract that creates a group of users who can deposit funds into contract
 * daily and every week a member of the group is sent all the funds, the process starts again.
 * till every member of the group gets paid.
 * @author Raiyan Mukhtar
 *
 */
contract Lum is Context, ILum, ReentrancyGuard, VRFConsumerBaseV2, KeeperCompatibleInterface {
    /****LIBRARIES*******/
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /***********ENUMS**********************/
    enum Status {
        PAID,
        NOT_PAID
    }

    /**************STRUCTS****************/
    struct Group {
        bytes32 id;
        string name;
        uint8 number_of_members;
        uint256 lum_amount;
    }

    struct Member {
        address mem_Address;
        Status paid_status;
        bool withdrawn;
    }

    /********STATE VARIABLES***********/
    //change mappings to open Zepellins EnumerableMap
    bytes32[] private s_group;
    EnumerableSet.Bytes32Set private s_group_enum;
    mapping(bytes32 => Group) private s_groupById;
    mapping(bytes32 => Member[]) private s_group_mems;
    mapping(bytes32 => uint256) private s_group_balances;
    EnumerableMap.Bytes32ToUintMap private s_group_balances_enum;
    mapping(bytes32 => address) private s_group_randomAddress;
    uint8 private constant NUM_MEMBERS = 4;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private s_groupId;

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_requestId;

    /*********EVENTS**************/
    event IdRequested(uint256 indexed requestId);
    event lummerAddressPicked(address indexed lumAddress);

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
        require(s_group_mems[_id].length < s_groupById[_id].number_of_members, "Group full");
        _;
    }

    /**
     * @dev check if caller is a member
     */
    modifier checkIfMemberExist(bytes32 groupId, address caller) {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;
        bool is_exist;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (members[i].mem_Address == caller) {
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
            if (members[i].mem_Address == caller && members[i].paid_status == Status.PAID) {
                has_paid = true;
            }
        }
        if (has_paid) {
            revert Lum__CallerAlreadyPaid();
        }
        _;
    }

    modifier checkIfMemberAlreadyWithdrew(bytes32 groupId, address caller) {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;
        bool has_withdrew;
        for (uint256 i = 0; i < mem_length; ++i) {
            if (members[i].mem_Address == caller && members[i].withdrawn) {
                has_withdrew = true;
            }
        }
        if (has_withdrew) {
            revert Lum__CallerAlreadyWithdrew();
        }
        _;
    }

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Lum__UpkeepNotNeeded();
        }
        s_requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit IdRequested(s_requestId);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfLummer = randomWords[0] % NUM_MEMBERS;
        s_lastTimeStamp = block.timestamp;
        address randomAddress = s_group_mems[s_groupId][indexOfLummer].mem_Address;
        s_group_randomAddress[s_groupId] = randomAddress;
        emit lummerAddressPicked(randomAddress);
    }

    /**
     *
     * @dev see {ILum.sol-createGroup}.
     *
     */
    function createGroup(string memory _name, uint256 _amount) external override {
        bytes32 id = keccak256(abi.encode(_name, _msgSender(), NUM_MEMBERS));
        //check if it calls saves gas
        //s_group.push(id);
        s_group_enum.add(id);
        s_groupById[id] = Group(id, _name, NUM_MEMBERS, _amount);
        s_group_mems[id].push(Member(_msgSender(), Status.NOT_PAID, false));
        s_group_balances_enum.set(id, 0);
        emit GroupCreated(id);
    }

    /**
     * @dev see {ILum.sol-joinGroup}.
     */
    function joinGroup(bytes32 groupId)
        external
        override
        checkGroupExist(groupId)
        checkMembersFull(groupId)
    {
        s_group_mems[groupId].push(Member(_msgSender(), Status.NOT_PAID, false));
        emit GroupJoined(groupId, _msgSender());
    }

    /**
     *
     * @dev see {ILum.sol-startLum}.
     */
    function startLum(bytes32 groupId)
        external
        override
        checkGroupExist(groupId)
        checkIfMemberAlreadyWithdrew(groupId, _msgSender())
        nonReentrant
    {
        address randomAddress = s_group_randomAddress[groupId];
        require(_msgSender() == randomAddress, "Not Authorized");

        uint256 lumAmount = s_groupById[groupId].lum_amount;
        //Effects
        // s_group_balances[groupId] -= lumAmount;
        uint256 prevVal = s_group_balances_enum.get(groupId);
        s_group_balances_enum.set(groupId, prevVal - lumAmount);
        UpdateWithdrawStatus(groupId, _msgSender());
        s_group_randomAddress[groupId] = address(0);
        //interaction
        (bool sent, ) = randomAddress.call{value: lumAmount}("");
    }
    function getNumMembers() external pure override returns (uint256) {
        return NUM_MEMBERS;
    }

        if (!sent) {
            revert Lum__TransferFailed();
        }
        emit FundsWithdrawn(randomAddress, lumAmount, groupId);
    }

    function getMemberPaymentStatus(address memberAddress, bytes32 groupId)
        public
        view
        returns (Status paymentStat)
    {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;

        for (uint256 i = 0; i < mem_length; ) {
            if (members[i].mem_Address == memberAddress) {
                paymentStat = members[i].paid_status;
            }

            unchecked {
                ++i;
            }
        }
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfLummer = randomWords[0] % NUM_MEMBERS;
        s_lastTimeStamp = block.timestamp;
        lummerAddress = s_group_mems[s_groupId][indexOfLummer].mem_Address;

        emit lummerAddressPicked(lummerAddress);
    }

    function UpdatePaymentStatus(bytes32 groupId, address memberAddress) private {
        Member[] storage members = s_group_mems[groupId];

        uint256 mem_length = members.length;
        for (uint256 i = 0; i < mem_length; ) {
            if (members[i].mem_Address == memberAddress) {
                members[i].paid_status = Status.PAID;
            }
            unchecked {
                ++i;
            }
        }
    }

    function UpdateWithdrawStatus(bytes32 groupId, address memberAddress) private {
        Member[] storage members = s_group_mems[groupId];

        uint256 mem_length = members.length;
        for (uint256 i = 0; i < mem_length; ) {
            if (members[i].mem_Address == memberAddress) {
                members[i].withdrawn = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    function allMembersPaymentStatus(bytes32 groupId) private view returns (bool) {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;
        uint256 mem_count;
        for (uint256 i = 0; i < mem_length; i++) {
            if (members[i].paid_status == Status.PAID) {
                mem_count++;
            }
        }
        if (mem_count == mem_length) {
            return true;
        } else {
            return false;
        }
    }
}
