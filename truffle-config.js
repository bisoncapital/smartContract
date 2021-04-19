require("babel-register");
require("babel-polyfill");
require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");
const privateKeysETH = process.env.PRIVATE_KEYS || "";
const privateKeysBNB = process.env.PRIVATE_KEYS_BNB || "";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
    },
    rinkeby: {
      provider: new HDWalletProvider(
        [privateKeysETH], // Array of account private keys
        `wss://rinkeby.infura.io/ws/v3/${process.env.INFURA_API_KEY}` // Url to an Ethereum Node
      ),
      network_id: 4,
      timeoutBlocks: 50000,
    },
    liveETH: {
      provider: new HDWalletProvider(
        [privateKeysETH], // Array of account private keys
        `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}` // Url to an Ethereum Node
      ),
      network_id: 1,
      gas: 5000000,
      gasPrice: 24000000000,
    },
    testnetBNB: {
      provider: new HDWalletProvider(
        [privateKeysBNB], // Array of account private keys
        "https://data-seed-prebsc-1-s1.binance.org:8545/" // Url to an Ethereum Node
      ),
      network_id: 97,
      timeoutBlocks: 200,
      confirmations: 5,
      production: true, // Treats this network as if it was a public net. (default: false)
    },
    bsc: {
      provider: new HDWalletProvider(
        [privateKeysBNB], // Array of account private keys
        "https://bsc-dataseed1.binance.org/" // Url to an Ethereum Node
      ),
      network_id: 56,
      timeoutBlocks: 200,
      confirmations: 10,
      production: true, // Treats this network as if it was a public net. (default: false)
      skipDryRun: true,
    },
  },
  plugins: ["truffle-plugin-verify"],
  api_keys: {
    bscscan: process.env.BSC_API_KEY,
    //etherscan: process.env.ETHERSCAN_API_KEY,
  },
  compilers: {
    solc: {
      version: "0.7.1",
    },
  },
};
