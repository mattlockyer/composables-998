

//jshint ignore: start

pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';

contract Composable is ERC721Token {
  
  //pass through constructor, remove?
  constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}
  
  /// wrapper on minting new 721
  function mint721(address _to, uint256 _tokenId) public returns (uint256) {

    _mint(_to, _tokenId);
    
    return allTokens.length;
  }
  
}