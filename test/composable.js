

//jshint ignore: start

const Composable = artifacts.require("./Composable.sol");

/**************************************
* Helpers
**************************************/
const promisify = (inner) => new Promise((resolve, reject) =>
  inner((err, res) => {
    if (err) { reject(err) }
    resolve(res);
  })
);
const getBalance = (account, at) => promisify(cb => web3.eth.getBalance(account, at, cb));
const timeout = ms => new Promise(res => setTimeout(res, ms))

/**************************************
* Tests
**************************************/
contract('Composable', function(accounts) {
  
  let composable;
  
  it('should be deployed', async () => {
    composable = await Composable.deployed();
    assert(composable !== undefined, 'composable was not deployed');
  });
  

});

//jshint ignore: end
