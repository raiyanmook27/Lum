// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

/**
 * @dev Interface of Lum defining functions
 */
interface ILum {
    /**
     * @dev Emitted when a group is created with the 'groupId'
     */
    event GroupCreated(bytes32 indexed groupId);

    /**
     * @dev Emitted when a user joined a group.
     */
    event GroupJoined(bytes32 indexed groupId, address indexed _member);

    /**
     * @dev Emitted when a members funds the group.
     */
    event GroupFunded(address indexed member, bytes32 indexed groupId, uint256 indexed amount);

    /**
     * @dev Emitted when lum starts.
     */
    event LumStarted(bytes32 indexed groupId);

    /**
     * @dev emits the random address picked.
     */
    event LummerReceiver(address indexed lummerAddress);

    /**
     * @dev Emitted when a caller withdraws funds
     */
    event FundsWithdrawn(address indexed lummer, uint256 indexed amount, bytes32 gtoupId);

    /**
     * @notice creates a group.
     *
     * @dev use a keccak256 to hash the name,the caller and number of
     * members as a group id.
     *
     * Emits a {GroupCreated} event.
     */
    function createGroup(string memory _name, uint256 _amount) external;

    /**
     *@dev deposit funds to Lum contract
     *
     */
    function depositFunds(bytes32 groupId) external payable;

    /**
     * @dev a member joins a group.
     *
     * @param groupId -> id of a group
     *
     * Emits a {GroupJoined} event.
     */
    function joinGroup(bytes32 groupId) external;

    /**
     * @dev Returns the number of groups.
     */
    function numberOfGroups() external view returns (uint256);

    /**
     * @dev starts the lum process.
     */
    function startLum(bytes32 groupId) external;

    /**
     * @dev returns the number of members in a group
     */
    function getNum_Members() external returns (uint256);

    function numberOfGroupMembers(bytes32 groupId) external view returns (uint256);

    /**
     * @dev return the balance of a group with id
     * @param groupId -> an id of a group
     */
    function balanceOf(bytes32 groupId) external view returns (uint256);

    /**
     * @dev caller with draws funds from group balance
     */
    function withdraw(bytes32 groupId) external;

    /**
     * @dev returns all groups in the contract
     */
    //function getAllGroups() external view returns (bytes32[] memory);
}
