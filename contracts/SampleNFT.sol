

//jshint ignore: start

pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';

contract SampleNFT is ERC721Token {

  /**************************************
   * ERC-721 Setup Methods for Testing
   **************************************/

  //pass through constructor, remove?
  constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}

  /// wrapper on minting new 721
  function mint721(address _to) public returns(uint256) {
    _mint(_to, allTokens.length + 1);
    return allTokens.length;
  }



}