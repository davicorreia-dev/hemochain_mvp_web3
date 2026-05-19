require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const RPC_URL  = process.env.SEPOLIA_RPC_URL || "";
const PRIV_KEY = process.env.PRIVATE_KEY     || "0x0000000000000000000000000000000000000000000000000000000000000001";

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { 
      evmVersion: "cancun",
      optimizer: { enabled: true, runs: 200 } 
    },
  },
  networks: {
    sepolia: {
      url:      RPC_URL,
      accounts: [PRIV_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
};