const { expect, assert } = require("chai")
const { ethers } = require("hardhat")

describe("Lum Contract Tests.......", () => {
    let lum, deployer
    beforeEach(async () => {
        /**
         * @notice get a deployer
         */
        accounts = await ethers.getSigners()

        deployer = accounts[0]

        const lumContract = await ethers.getContractFactory("Lum", deployer)

        lum = await lumContract.deploy()
    })
    describe("createGroup", () => {
        it("should create an group", async () => {
            await lum.createGroup("Raiyan")
            const num = expect(await lum.numberOfGroups()).to.equal(1)
        })
        it("should emit a Group Created", async () => {
            await expect(lum.createGroup("Raiyan")).to.emit(lum, "GroupCreated")
        })
    })
})
