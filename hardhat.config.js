require("@nomicfoundation/hardhat-toolbox")
require("@nomicfoundation/hardhat-chai-matchers")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

const RINKEBY_RPC_URL =
    process.env.RINKEBY_RPC_URL ||
    "https://eth-rinkeby.alchemyapi.io/v2/qHe54-rytGu8yNd0iCKHs175dNHfl3PN"

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.9",
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },
    },
}
