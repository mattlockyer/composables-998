

//jshint ignore: start

const Composable = artifacts.require("./Composable.sol");
const SampleNFT = artifacts.require("./SampleNFT.sol");

//tools for overloaded functions
const web3Abi = require('web3-eth-abi');
const web3Utils = require('web3-utils');

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
  
  let composable, sampleNFT, alice = accounts[0], bob = accounts[1];
  
  it('should be deployed, Composable', async () => {
    composable = await Composable.deployed();
    assert(composable !== undefined, 'Composable was not deployed');
  });
  
  it('should be deployed, SampleNFT', async () => {
    sampleNFT = await SampleNFT.deployed();
    assert(sampleNFT !== undefined, 'SampleNFT was not deployed');
  });
  
  it('should mint a 721 token, Composable', async () => {
    const tokenId = await composable.mint721.call(alice);
    assert(tokenId.equals(1), 'Composable 721 token was not created or has wrong tokenId');
    const tx = await composable.mint721(alice);
  });
  
  it('should mint a 721 token, SampleNFT', async () => {
    const tokenId = await sampleNFT.mint721.call(alice);
    assert(tokenId.equals(1), 'SampleNFT 721 token was not created or has wrong tokenId');
    const tx = await sampleNFT.mint721(alice);
  });
  
  
  
  
  it('should safeTransferFrom', async () => {
    //the call to overloaded function (thanks truffle / Consensys... ugh!)
    //parent tokenId is a string because it's passed as bytes data
    // const tokenId = await sampleNFT.contract.safeTransferFrom['address,address,uint256,bytes']
    //   .call(alice, composable.address, 1, "1");
    //the tx
    
    //console.log(SampleNFT.abi);
    
    const transferMethodTransactionData = web3Abi.encodeFunctionCall(
      SampleNFT.abi[13], [alice, composable.address, 1, web3Utils.fromAscii("1")]
    );
    const tx = await web3.eth.sendTransaction({
      from: alice, to: sampleNFT.address, data: transferMethodTransactionData, value: 0, gas: 500000
    });
    assert(tx != undefined, 'no tx using safeTransferFrom');
  });
  
  
  
  
  it('should own sampleNFT, Composable', async () => {
    const address = await sampleNFT.ownerOf.call(1);
    assert(address == composable.address, 'composable does not own sampleNFT');
  });
  
  it('should transfer composable to bob', async () => {
    const success = await composable.transferFrom.call(alice, bob, 1);
    assert(success, 'transfer did not work');
    const tx = await composable.transferFrom(alice, bob, 1);
  });
  
  it('should own the composable, Bob', async () => {
    const address = await composable.ownerOf.call(1);
    assert(address == bob, 'composable not owned by bob');
  });
  
  it('should transfer child to alice', async () => {
    const success = await composable.transferChild.call(alice, 1, sampleNFT.address, 1, { from: bob });
    assert(success, 'transfer did not work');
    const tx = await composable.transferChild(alice, 1, sampleNFT.address, 1, { from: bob });
  });
  
  it('should own sampleNFT, alice', async () => {
    const address = await sampleNFT.ownerOf.call(1);
    assert(address == alice, 'alice does not own sampleNFT');
  });
  
});

//jshint ignore: end
