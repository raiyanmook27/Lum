const networkConfig = {
    default: {
        name: "hardhat",
        keepersUpdateInterval: "30",
    },
    4: {
        name: "rinkeby",
        subscriptionId: "19180",
        gasLane: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // 30 gwei
        keepersUpdateInterval: "30",
        callbackGasLimit: "500000", // 500,000 gas
        vrfCoordinatorV2: "0x6168499c0cFfCaCD319c818142124B7A15E857ab",
    },
5: {
        name: "goerli",
        subscriptionId: "1531",
        gasLane: "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15", // 30 gwei
        keepersUpdateInterval: "30",
        callbackGasLimit: "500000", // 500,000 gas
        vrfCoordinatorV2: "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D",
//private key:a1a7b06aeba2ea6fb37c0a76723867cbec5a68e91cc44a0cca2f1eded7fac3b3
//https://goerli.infura.io/v3/
    },
    31337: {
        name: "localhost",
        subscriptionId: "588",
        gasLane: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // 30 gwei
        keepersUpdateInterval: "30",
        callbackGasLimit: "500000", // 500,000 gas
    },
}

const developmentChains = ["hardhat", "localhost"]
module.exports = { networkConfig, developmentChains }
