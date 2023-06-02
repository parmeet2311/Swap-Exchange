require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("solidity-coverage")
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

module.exports = {
  solidity:
  {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        }
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        }
      },
    ],

    overrides: {
      "contracts/ZetaSwap.sol": {
        version: "0.8.7",
      }
    },
  },
  
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545/",
    },
    // athens: {
    //   url: process.env.ATHENS_RPC,
    //   accounts: [process.env.PRIVATE_KEY],
    // },
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
      athens: process.env.ATHENS_API_KEY,
    },
  },

};