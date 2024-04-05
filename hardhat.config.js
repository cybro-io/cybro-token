require('@nomicfoundation/hardhat-verify');
require('@nomicfoundation/hardhat-chai-matchers');
require("hardhat-contract-sizer");
require('hardhat-dependency-compiler');
require('hardhat-deploy');
require('hardhat-gas-reporter');
require('hardhat-tracer');
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.24',
      }
    ]
  },
  etherscan: {
    apiKey: {
      blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
      blast: process.env.BLASTSCAN_API_KEY
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io"
        }
      },
      {
        network: "blast",
        chainId: 81457,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/81457/etherscan",
          browserURL: "https://blastexplorer.io"
        }
      }
    ]
  },
  networks: {
    blast_sepolia: {
      url: 'https://sepolia.blast.io',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    },
    blast: {
      url: 'https://rpc.blast.io',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    },
  }
};
