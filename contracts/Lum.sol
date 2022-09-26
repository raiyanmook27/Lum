// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./ILum.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "hardhat/console.sol";
import "./MultiSig.sol";

/***************ERRORS****************/
error Lum__CallerNonExistent();
error Lum__CallerAlreadyPaid();
error Lum__NotEnoughEth();
error Lum__UpkeepNotNeeded();
error Lum_NotAllMembersPaid();
error Lum__NotAuthorized();

/**
 * @title Lum
 * @dev * A contract that creates a group of users who can deposit funds into contract
 * daily and every week a member of the group is sent all the funds, the process starts again.
 * till every member of the group gets paid.
 * @author Raiyan Mukhtar
 *
 */
contract Lum is Context, ILum, ReentrancyGuard, VRFConsumerBaseV2, KeeperCompatibleInterface {
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
    //change mappings to open Zepellins EnumerableMap
    bytes32[] private s_group;
    mapping(bytes32 => Group) private s_groupById;
    mapping(bytes32 => Member[]) private s_group_mems;
    mapping(bytes32 => uint256) private s_group_balances;
    uint8 private constant NUM_MEMBERS = 4;
    address private lummerAddress;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private s_groupId;
    address private groupCreator;

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_requestId;

    //string private immutable i_duration;
    MultiSig multSig;

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

    modifier onlyCreator() {
        if (_msgSender() != groupCreator) {
            revert Lum__NotAuthorized();
        }
        _;
    }

    // /**
    //  * @dev Sets the value {name}.
    //  *
    //  * @notice name is immutable can only be set once during
    //  * construction
    //  */
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

    /**
     *
     * @dev see {ILum.sol-startLum}.
     */
    function startLum(bytes32 groupId) external override onlyCreator {
        s_groupId = groupId;
        //get owners
    }

    function setMultiSig(address _multiSig) external {
        multSig = MultiSig(_multiSig);
    }

    function allMembersPaymentStatus(bytes32 groupId) internal view returns (bool) {
        Member[] memory members = s_group_mems[groupId];
        uint256 mem_length = members.length;
        uint256 mem_count;
        for (uint256 i = 0; i < mem_length; i++) {
            if (members[i].paid_status == STATUS.PAID) {
                mem_count++;
            }
        }
        if (mem_count == mem_length) {
            return true;
        } else {
            return false;
        }
    }

    /***
     * @dev This is the function the chainlink Keeper nodes call
     * they check for if 'UpKeep' returns true.
     * The follwing should be true inorder to return true.
     * 1. The time interval should have passed.
     * 2. subscription is funded.
     * 3. group exist
     * 4. all members have paid
     */
    function checkUpkeep(
        //calldata doesnt work with bytes
        bytes memory /*checkData*/
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /*performData*/
        )
    {
        //check time elapsed
        bool groupExists = s_groupById[s_groupId].id == s_groupId;
        bool hasMembersPaid = allMembersPaymentStatus(s_groupId);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        upkeepNeeded = (groupExists && hasMembersPaid && timePassed);
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
    ) internal override nonReentrant {
        uint256 indexOfLummer = randomWords[0] % NUM_MEMBERS;
        s_lastTimeStamp = block.timestamp;
        lummerAddress = s_group_mems[s_groupId][indexOfLummer].mem_Address;

        emit lummerAddressPicked(lummerAddress);
    }

    /**
     *
     * @dev see {ILum.sol-createGroup}.
     *
     */
    function createGroup(string memory _name) external override {
        groupCreator = _msgSender();
        bytes32 id = keccak256(abi.encode(_name, _msgSender(), NUM_MEMBERS));
        //check if it calls saves gas
        s_group.push(id);
        s_groupById[id] = Group(id, _name, NUM_MEMBERS);
        s_group_mems[id].push(Member(_msgSender(), STATUS.NOT_PAID));
        emit GroupCreated(id);
    }

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

    function getMembersAddress(bytes32 groupId) public view returns (address[] memory) {
        address[] memory ownersAddress = new address[](4);
        uint256 length = s_group_mems[groupId].length;
        Member[] memory members = s_group_mems[groupId];
        for (uint256 i = 0; i < length; i++) {
            ownersAddress[i] = members[i].mem_Address;
        }
        return ownersAddress;
    }

    function balanceOf(bytes32 groupId) external view override returns (uint256) {
        return s_group_balances[groupId];
    }

    function getLummAddress() external view returns (address) {
        return lummerAddress;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function get_TimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
