const { expect } = require("chai")
const { ethers } = require("hardhat")
describe("Lum Unit Test.", () => {
    let lum, sendValue, vrfCoordinatorMock
    const id_const = "0xb771cd9cffecb27cf78b446990d845eb96f8b414f9bf010fa3e5368f06d92973"
    beforeEach(async () => {
        accounts = await ethers.getSigners()
        const LumContractInst = await ethers.getContractFactory("Lum")
        const vrfCoordinatorMockInst = await ethers.getContractFactory("VRFCoordinatorV2Mock")

        lum = await LumContractInst.deploy()
        vrfCoordinatorMock = await vrfCoordinatorMockInst.deploy()
        sendValue = ethers.utils.parseEther("1.0")
    })

    describe("createGroup()", () => {
        beforeEach(async () => {
            await lum.createGroup("raiyan")
        })
        it("should create an group id", async () => {
            expect(await (await lum.groupDetails(id_const)).id).to.equal(id_const)
        })
        it("should emit a Group created event", async function () {
            await expect(lum.createGroup("raiyan")).to.emit(lum, "GroupCreated")
        })
    })
    describe("numberOfGroups()", () => {
        it("should return the number of groups", async function () {
            await lum.createGroup("raiyan")
            expect(await lum.numberOfGroups()).to.equal(1)
        })
    })
    describe("getGroupId()", () => {
        it("should return a group id", async function () {
            await lum.createGroup("raiyan")
            expect(await lum.getGroupId(0)).to.equal(id_const)
        })
    })
    describe("getNum_Members()", () => {
        it("should return a group id", async function () {
            await lum.createGroup("raiyan")
            expect(await lum.getNum_Members()).to.equal(4)
        })
    })

    describe("joinGroup()", () => {
        // check if group exist
        it("should revert if group doesn't exist", async () => {
            await lum.createGroup("raiyanM")
            await expect(lum.joinGroup(id_const)).to.be.revertedWith("Group doesn't exist")
        })
        //check if members are full
        it("should revert if group is full", async () => {
            await lum.createGroup("raiyan")
            const address2 = accounts[1]
            const address3 = accounts[2]
            const address4 = accounts[3]
            const address5 = accounts[4]

            await lum.connect(address2).joinGroup(id_const)
            await lum.connect(address3).joinGroup(id_const)
            await lum.connect(address4).joinGroup(id_const)

            await expect(lum.connect(address5).joinGroup(id_const)).to.be.revertedWith(
                "Group is full"
            )
        })
        it("should join a group", async () => {
            await lum.createGroup("raiyan")
            const address2 = accounts[1]
            await lum.connect(address2).joinGroup(id_const)
            expect((await lum.NumberOfGroupMembers(id_const)).toNumber()).to.equal(2)
        })
        it("should emit a group joined event", async () => {
            await lum.createGroup("raiyan")
            await expect(lum.joinGroup(id_const)).to.emit(lum, "GroupJoined")
        })
    })
    describe("DepositFunds()", () => {
        beforeEach(async () => {
            await lum.createGroup("raiyan")
        })
        it("should revert if caller isn't a member", async function () {
            await expect(
                lum.connect(accounts[1]).depositFunds(id_const)
            ).to.be.revertedWithCustomError(lum, "Lum__CallerNonExistent")
        })
        it("should revert if ether not enough", async () => {
            await expect(lum.depositFunds(id_const)).to.be.revertedWithCustomError(
                lum,
                "Lum__NotEnoughEth"
            )
        })
        it.only("should revert if member already paid", async function () {
            await lum.depositFunds(id_const, { value: sendValue })
            await expect(
                lum.depositFunds(id_const, { value: sendValue })
            ).to.be.revertedWithCustomError(lum, "Lum__CallerAlreadyPaid")
        })
        it("should deposit funds to the group account", async function () {
            await lum.depositFunds(id_const, { value: sendValue })

            expect(await lum.balanceOf(id_const)).to.equal(sendValue)
        })
        it.only("should update member payment status", async () => {
            await lum.depositFunds(id_const, { value: sendValue })
            expect(await lum.getMemberPaymentStatus(accounts[0].address, id_const)).to.equal(0)
        })
        it("should emit an event when deposit is successful", async () => {
            await expect(lum.depositFunds(id_const, { value: sendValue })).to.emit(
                lum,
                "GroupFunded"
            )
        })
    })

    describe("FullfilRandomWords", () => {
        beforeEach(async () => {
            await lum.createGroup("raiyan")
        })

        it.only("picks a lummer address", async () => {
            for (let i = 1; i < 4; i++) {
                lum.connect(accounts[i]).joinGroup(id_const)
            }
        })
    })
})
