module.exports = {
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    },
    compilers: {
        solc: {
          version: "^0.4.21"
        }
    }

  /*
    networks: {
        development: {
          host: "127.0.0.1",
          port: 9545,
          gas: 8000000,
          network_id: "*" // Match any network id

        }
      }
      */
};