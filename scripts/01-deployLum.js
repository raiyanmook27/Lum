const { getNamedAccounts, deployments, network, run, ethers } = require("hardhat")

async function startLum() {
    const lum = await ethers.getContractFactory("Lum")
    console.log("lum Started")
}
startLum()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
