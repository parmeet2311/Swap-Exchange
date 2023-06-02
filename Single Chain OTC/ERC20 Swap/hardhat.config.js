require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("solidity-coverage")
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity:
  {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545/",
    },
    ethereum: {
      url: process.env.ETH_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
    goerli: {
      url: process.env.GOERLI_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY],
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },

  gasReporter: {
    enabled: true,
    currency: 'USD',
    token: 'ETH',
    gasPriceApi: 'api.etherscan.io/api?module=proxy&action=eth_gasPrice',
    coinmarketcap: process.env.COINMARKETCAP,
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHSCAN_API_KEY,
      goerli: process.env.ETHSCAN_API_KEY,
      sepolia: process.env.ETHSCAN_API_KEY,
    },
  },
};