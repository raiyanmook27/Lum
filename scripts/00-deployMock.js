const { ethers, network } = require("hardhat")

async function mockStart() {
    const lum = await ethers.getContractFactory("Lum")
    await lum.deploy()
    const tx = await lum.requestRandomWords()
    const txReceipts = await tx.wait(1)
    const requestId = txReceipts.events[1].args.requestId
    await mock(requestId, lum)
    console.log("Requested Id:", requestId)
}
async function mock(requestId, lum) {
    const vrfCoordinatorMock = await ethers.getContract("VRFCoordinatorV2Mock")
    await vrfCoordinatorMock.fulfillRandomWords(requestId, lum.address)
    console.log("mocked")
}

mockStart()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
