// const HDWalletProvider = require('@truffle/hdwallet-provider');
// const infuraKey = "";

// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
     },
    //  rinkeby: {
    //   provider: () =>  new HDWalletProvider({
    //     mnemonic: {
    //       phrase: mnemonic
    //     },
    //     providerOrUrl: `https://rinkeby.infura.io/v3/${infuraKey}`
    //   }),
    //   network_id: 4,       // rinkeby's id
    //   gas: 4500000,        // rinkeby has a lower block limit than mainnet
    //   gasPrice: 10000000000
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 10000
  },
  
  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.11"
    }
  },


};
