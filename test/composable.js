

//jshint ignore: start

// contracts
const Composable = artifacts.require("./Composable.sol");
const SampleNFT = artifacts.require("./SampleNFT.sol");
const SampleERC20 = artifacts.require("./SampleERC20.sol");

// tools for overloaded function calls
const web3Abi = require('web3-eth-abi');
const web3Utils = require('web3-utils');

/**************************************
* Helpers
**************************************/

const logEvent = (func) => {
  const event = func({ _from: web3.eth.coinbase }, { fromBlock: 0, toBlock: 'latest' });
  event.watch(function(error, result){
    console.log(' * ' + result.event);
    if (result.args._from) console.log(result.args._from);
    if (result.args._to) console.log(result.args._to);
    if (result.args._tokenId) console.log(result.args._tokenId.toNumber());
    if (result.args._childContract) console.log(result.args._childContract);
    if (result.args._childTokenId) console.log(result.args._childTokenId.toNumber());
    if (result.args._data) console.log(result.args._data);
  });
}
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
  
  let composable, sampleNFT, sampleERC20, alice = accounts[0], bob = accounts[1];
  
  /**************************************
  * NOTE
  *
  * Transferring composables requires a bytes of bytes32 in hex
  * to specify the receiving token index in the composable
  *
  * The following creates bytes of length 32 representing 1, 2 and 3
  **************************************/
  const bytes1 = web3Utils.padLeft(web3Utils.toHex(1), 32);
  const bytes2 = web3Utils.padLeft(web3Utils.toHex(2), 32);
  const bytes3 = web3Utils.padLeft(web3Utils.toHex(3), 32);
  
  it('should be deployed, Composable', async () => {
    composable = await Composable.deployed();
    
    /**************************************
    * If you need event logging
    **************************************/
    
    // logEvent(composable.Received);
    // logEvent(composable.Added);
    // logEvent(composable.TransferChild);
    
    
    assert(composable !== undefined, 'Composable was not deployed');
  });
  
  it('should be deployed, SampleNFT', async () => {
    sampleNFT = await SampleNFT.deployed();
    assert(sampleNFT !== undefined, 'SampleNFT was not deployed');
  });
  
  it('should be deployed, SampleERC20', async () => {
    sampleERC20 = await SampleERC20.deployed();
    assert(sampleERC20 !== undefined, 'SampleERC20 was not deployed');
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
  
  it('should safeTransferFrom SampleNFT to Composable', async () => {
    // HAD TO HAND ROLL THIS TEST BECAUSE TRUFFLE SUCKS!!!
    // no call support to overloaded functions (thanks truffle / Consensys... ugh!)
    // parent tokenId is a string because it's passed as bytes data
    // safeTransferFrom is index 13 on zeppelin ERC721
    const safeTransferFrom = SampleNFT.abi.filter(f => f.name === 'safeTransferFrom' && f.inputs.length === 4)[0];
    
    const transferMethodTransactionData = web3Abi.encodeFunctionCall(
      safeTransferFrom, [alice, composable.address, 1, bytes1]
    );
    const tx = await web3.eth.sendTransaction({
      from: alice, to: sampleNFT.address, data: transferMethodTransactionData, value: 0, gas: 500000
    });
    assert(tx != undefined, 'no tx using safeTransferFrom');
  });
  
  it('should own sampleNFT, Composable', async () => {
    const owned = await composable.childExists(sampleNFT.address, 1);
    assert(owned, 'composable does not own sampleNFT');
  });
  
  /**************************************
  * Checking array, should have added sampleNFT after transfer
  **************************************/
  
  it('should have 1 child contract address sampleNFT', async () => {
    const contracts = await composable.totalChildContracts.call(1);
    const contract = await composable.childContractByIndex.call(1, 0);
    //we have to guess the child contract instance to find the address?
    //do we need to know the child contract address?
    //why can't we return the child contracts array?
    const example = await composable.childContractsByToken.call(1);
    
    assert(example[0] === SampleNFT.address, 'testing example failed, wrong contract address');
    
    assert(contracts.toNumber() === 1 && contract === SampleNFT.address, 'composable does not have the right childs contract');
  });
  
  /**************************************
  * Transferring and Composable "1" to Bob
  **************************************/
  
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
    const tx = await composable.transferChild(alice, 1, sampleNFT.address, 1, { from: bob });
  });
  
  it('should own sampleNFT, alice', async () => {
    const address = await sampleNFT.ownerOf.call(1);
    assert(address == alice, 'alice does not own sampleNFT');
  });
  
  /**************************************
  * Checking arrays, should be removed from transfer
  **************************************/
  
  it('should NOT have a sampleNFT contract', async () => {
    const contracts = await composable.totalChildContracts.call(1);
    assert(contracts.toNumber() === 0, 'composable has wrong number of child contracts');
  });
  
  it('should NOT have an child', async () => {
    const owned = await composable.childExists(sampleNFT.address, 1);
    assert(!owned, 'composable owns a SampleNFT and SHOULD NOT');
  });
  
  /**************************************
  * Checking Child transfer from Composable to Composable
  **************************************/
  
  it('should mint a 721 token, Composable "2" for Alice', async () => {
    const tokenId = await composable.mint721.call(alice);
    assert(tokenId.equals(2), 'Composable 721 token was not created or has wrong tokenId');
    const tx = await composable.mint721(alice);
  });
  
  it('should mint a 721 token, SampleNFT', async () => {
    const tokenId = await sampleNFT.mint721.call(alice);
    assert(tokenId.equals(2), 'SampleNFT 721 token was not created or has wrong tokenId');
    const tx = await sampleNFT.mint721(alice);
  });
  
  it('should own the composable, Alice', async () => {
    const address = await composable.ownerOf.call(2);
    assert(address == alice, 'composable not owned by alice');
  });
  
  it('should safeTransferFrom SampleNFT "2" to Composable "2"', async () => {
    const transferMethodTransactionData = web3Abi.encodeFunctionCall(
      SampleNFT.abi[13], [alice, composable.address, 2, bytes2]
    );
    const tx = await web3.eth.sendTransaction({
      from: alice, to: sampleNFT.address, data: transferMethodTransactionData, value: 0, gas: 500000
    });
    assert(tx != undefined, 'no tx using safeTransferFrom');
  });
  
  it('should own sampleNFT "2", Composable "2"', async () => {
    const owned = await composable.childExists(sampleNFT.address, 2);
    assert(owned, 'composable does not own sampleNFT 2');
  });
  
  it('should transfer child to from composable 2 to composable 1', async () => {
    const tx = await composable.safeTransferChild(composable.address, 2, sampleNFT.address, 2, bytes1);
  });
  
  it('should own sampleNFT 2, composable', async () => {
    const address = await sampleNFT.ownerOf.call(2);
    assert(address == composable.address, 'composable does NOT own sampleNFT 2');
  });
  
  it('should have 1 child contract addresses SampleNFT', async () => {
    const contracts = await composable.childContractsOwnedBy.call(1);
    assert(contracts.length === 1, 'composable does not have the right amount of contracts');
  });
  
  it('should have 1 child of type sampleNFT of ID "2"', async () => {
    const childs = await composable.childsOwnedBy.call(1, sampleNFT.address);
    assert(childs.length === 1 && childs[0].equals(2), 'composable does not own right childs');
  });
  
  /**************************************
  * Checking Composable in Composable
  **************************************/
  
  it('should safeTransferFrom Composable "2" to Composable "1"', async () => {
    // safeTransferFrom is index 16 on Composable abi
    
    const safeTransferFrom = Composable.abi.filter(f => f.name === 'safeTransferFrom' && f.inputs.length === 4)[0];
    
    const transferMethodTransactionData = web3Abi.encodeFunctionCall(
      safeTransferFrom, [alice, composable.address, 2, bytes1 ]
    );
    const tx = await web3.eth.sendTransaction({
      from: alice, to: composable.address, data: transferMethodTransactionData, value: 0, gas: 500000
    });
    assert(tx != undefined, 'no tx using safeTransferFrom');
  });
  
  /**************************************
  * Checking Arrays
  **************************************/
  
  it('should have 2 child contract addresses: Composable and SampleNFT', async () => {
    const contracts = await composable.childContractsOwnedBy.call(1);
    assert(contracts.length === 2, 'composable does not have the right amount of contracts');
  });
  
  it('should have 1 child of type Composable of ID "2"', async () => {
    const num = await composable.childsOwnedBy.call(1, composable.address);
    assert(num.length === 1 && num[0].equals(2), 'composable does not own right child for Composable');
  });
  
  it('should transfer child 2 to from composable 1 to composable 2', async () => {
    const tx = await composable.safeTransferChild(composable.address, 1, sampleNFT.address, 2, bytes2, { from: bob });
  });
  
  it('should have 1 child contract Composable', async () => {
    const contracts = await composable.childContractsOwnedBy.call(1);
    assert(contracts.length === 1 && contracts[0] === composable.address, 'composable does not have the right amount of contracts');
  });
  
  /**************************************
  * Testing ERC998PossessERC20
  **************************************/
  
  
  it('should mint a 721 token, Composable "3" for Alice', async () => {
    const tokenId = await composable.mint721.call(alice);
    assert(tokenId.equals(3), 'Composable 721 token was not created or has wrong tokenId');
    const tx = await composable.mint721(alice);
  });
  
  it('should mint ERC20', async () => {
    const success = await sampleERC20.mint.call(alice, 1000);
    assert(success, 'did not mint ERC20');
    const tx = await sampleERC20.mint(alice, 1000);
  });
  
  it('should have an ERC20 balance', async () => {
    const balance = await sampleERC20.balanceOf.call(alice);
    assert(balance.equals(1000), 'incorrect balance');
  });
  
  it('should safeTransferFrom half the value from the ERC20 to the composable "3"', async () => {
    const success = await sampleERC20.safeTransferFromERC20.call(alice, composable.address, 500, bytes3);
    //console.log(success);
    assert(success, 'did not transfer');
    const tx = await sampleERC20.safeTransferFromERC20(alice, composable.address, 500, bytes3);
  });
  
  it('should have half the balance of sampleERC20 in composable "3"', async () => {
    const contracts = await composable.ftpContractsOwnedBy.call(3);
    //console.log(contracts, sampleERC20.address);
    assert(contracts.length === 1, 'ERC20 balance of composable NOT correct');
  });
  
  it('should have half the balance of sampleERC20 in composable "3"', async () => {
    const balance = await composable.ftpBalanceOf.call(3, sampleERC20.address);
    assert(balance.equals(500), 'ERC20 balance of composable NOT correct');
  });
  
  it('should transfer half the balance in composable "3" to bob', async () => {
    const success = await composable.safeTransferFTP.call(bob, 3, sampleERC20.address, 250, bytes1);
    assert(success, 'did not transfer ERC20 from composable');
    const tx = await composable.safeTransferFTP(bob, 3, sampleERC20.address, 250, bytes1);
  });
  
  it('composable "3" should have 250 tokens', async () => {
    const balance = await composable.ftpBalanceOf.call(3, sampleERC20.address);
    //console.log(balance.toNumber());
    assert(balance.equals(250), 'ERC20 balance of composable NOT correct');
  });
  
  it('bob should have 250 tokens', async () => {
    const balanceOf = await sampleERC20.balanceOf.call(bob);
    //console.log(balanceOf.toNumber());
    assert(balanceOf.equals(250), 'ERC20 balance of composable NOT correct');
  });
  
  
});

//jshint ignore: end
