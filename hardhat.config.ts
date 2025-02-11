import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-chai-matchers";

import "@openzeppelin/hardhat-upgrades";
import "hardhat-gas-reporter";
require("dotenv").config(); // To manage environment variables

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28", // Solidity compiler version
    settings: {
      optimizer: {
        enabled: true, // Enable optimization for gas usage
        runs: 200, // Optimizations run
      },
    },
  },
  defaultNetwork: "localhost",
  networks: {
    hardhat: {
      // Hardhat network settings (default for local testing)
      chainId: 31337, // Chain ID for the Hardhat network
      accounts: {
        count: 10, // Adjust this number as needed
      },
    },
    localhost: {
      url: process.env.LOCALHOST_URL, // Localhost URL
      accounts: [process.env.KEY as string], // Local deployer's private key
    },
    mainnet: {
      url: process.env.MAINNET_URL, // Mainnet URL
      accounts: [process.env.PRIVATE_KEY as string], // Mainnet deployer's private key
    },
    testnet: {
      url: process.env.TESTNET_URL, // Ropsten network URL
      accounts: [process.env.PRIVATE_KEY as string], // Deployer's private key for Ropsten
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY, // API key for contract verification on Etherscan
  },
  paths: {
    artifacts: "./artifacts", // Folder where compiled contract artifacts are stored
    sources: "./contracts", // Folder containing Solidity contracts
    tests: "./test", // Folder where test files are located
    cache: "./cache", // Cache folder
  },
  mocha: {
    timeout: 20000, // Timeout for tests (in milliseconds)
  },
  gasReporter: {
    enabled: true, // Enables gas reporting for test runs
    // enabled: process.env.REPORT_GAS ? true : false, // Enables gas reporting for test runs
    currency: "USD", // Reporting gas costs in USD
    gasPrice: 20, // Default gas price to be used
    outputFile: "gas-report.txt", // Output file for gas report
    L2: "base",
    L2Etherscan: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
