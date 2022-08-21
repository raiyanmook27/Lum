// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "./ILum.sol";

/**
 * @dev * A contract that creates a group of users who can deposit funds into contract
 * daily and every week a member of the group is sent all the funds, the process starts again.
 * till every member of the group gets paid.
 *
 */
contract Lum is ILum {
    /***********ENUMS**********************/
    enum STATUS {
        PAID,
        NOT_PAID
    }

    /**************STRUCTS****************/
    struct Group {
        bytes32 id;
        bytes32 name;
        uint8 number_of_members;
    }

    struct Member {
        address mem_Addy;
        STATUS paid_status;
    }

    /********STATE VARIABLES***********/
    mapping(bytes32 => Group) private groups;
    mapping(bytes32 => Member[]) private group_mems;
    bytes32 private _name;
    uint8 private constant NUM_MEMBERS = 4;

    //string private immutable i_duration;

    /***********MODIFIERS***********/
    /**
     * @dev modifier to check if the group exist
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkGroupExist(bytes32 _id) {
        require(groups[_id].id == _id, "Group doesn't exist.....");
        _;
    }

    /**
     * @dev modifier to check if the group is full
     * using {_id}.
     * @param _id -> id of a specific group.
     */
    modifier checkMembersFull(bytes32 _id) {
        require(group_mems[_id].length < groups[_id].number_of_members, "Group is full...");
        _;
    }

    /**
     * @dev Sets the value {name}.
     *
     * @notice name is immutable can only be set once during
     * construction
     */
    constructor(bytes32 name) {
        _name = name;
    }

    /**
     * @dev see {ILum.sol-createGroup}.
     *
     */
    function createGroup() external override {
        bytes32 id = keccak256(abi.encode(_name, msg.sender, NUM_MEMBERS));
        //check if it calls saves gas
        groups[id] = Group(id, _name, NUM_MEMBERS);
        group_mems[id].push(Member(msg.sender, STATUS.NOT_PAID));
        emit GroupCreated(id);
    }
}
