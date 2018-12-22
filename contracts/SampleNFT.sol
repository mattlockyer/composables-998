//jshint ignore: start

pragma solidity >=0.4.21 <0.6.0;

import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol';

contract SampleNFT is ERC721Full {

    uint256 private tokenCount;

  /**************************************
   * ERC-721 Setup Methods for Testing
   **************************************/

  //pass through constructor, remove?
  constructor(string memory _name, string memory _symbol) public ERC721Full(_name, _symbol) {}

  /// wrapper on minting new 721
  function mint721(address _to) public returns(uint256) {
      tokenCount++;
      _mint(_to,  tokenCount);
      return tokenCount;
  }

}
