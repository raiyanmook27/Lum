# Lum

 A smart contract that creates a group of users who can deposit funds into contract
 daily and every week a member of the group is sent all the funds, the process starts again.


## Features to be implemented
- [X] create interface for Lum contract.
- [X] a creator should be able to create a group(specify number members and how long to pay users).
- [X] members should be able to join a group.
- [X] A group should have a balance.
- [X] A member should be able to pay into a groups account.
- [X] picks a user at random using Chainlinks VRF.
- [ ] use Chainlinks Keepers to send ether to the random user.


# Usage 

## Deploy
> yarn hardhat deploy

## Testing 
> yarn hardhat test


