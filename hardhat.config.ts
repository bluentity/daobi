import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
// import "hardhat-gas-reporter";
import "solidity-coverage";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  networks: {
    polygon: {
      url: "https://rpc-mainnet.maticvigil.com",
      // accounts: [process.env.PRIVATE_KEY || ""],
    },
    polygonAmoy: {
      url: "https://rpc-amoy.maticvigil.com",
      // accounts: [process.env.PRIVATE_KEY || ""],
    },
  },

  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  etherscan: {
    apiKey: {
      polygon: process.env.POLYSCAN_API_KEY,
      polygonAmoy: process.env.POLYSCAN_API_KEY,
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        }
      }
    ]
  },
};

export default config;
