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
     * @notice creates a group.
     *
     * @dev use a keccak256 to hash the name,the caller and number of
     * members as a group id.
     *
     * Emits a {GroupCreated} event.
     */
    function createGroup(string memory name) external;

    /**
     * @dev a member joins a group.
     *
     * @param groupId -> id of a group
     *
     * Emits a {GroupJoined} event.
     */
    // function joinGroup(bytes32 groupId) external;

    /**
     * @dev Returns the number of groups.
     */
    function numberOfGroups() external view returns (uint256);

    // /**
    //  * @dev Returns the details of a group based on 'groupId'.
    //  */
    // function groupDetails(bytes32 groupId) external view returns (uint256);

    // /**
    //  * @dev Returns the number of members in a group based on 'groupId'.
    //  */
    // function numberOfMembers(bytes32 groupId) external view returns (uint256);
}
