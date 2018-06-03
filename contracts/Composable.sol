

//jshint ignore: start

pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "./ERC998PossessERC721.sol";
import "./ERC998PossessERC20.sol";

contract Composable is ERC721Token, ERC998PossessERC721, ERC998PossessERC20 {

  /**************************************
  * ERC-721 Setup Methods for Testing
  **************************************/

  // pass through constructor, remove?
  constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}

  // wrapper on minting new 721
  function mint721(address _to) public returns(uint256) {
    _mint(_to, allTokens.length + 1);
    return allTokens.length;
  }
  
  /**************************************
  * TODO Where should this go? We shouldn't include this in every contract...
  **************************************/
  // implementation of the owns method from cryptokitties
  function _owns(address _claimant, uint256 _tokenId) internal view returns(bool) {
    return (tokenOwner[_tokenId] == _claimant);
  }
  
  /**************************************
  * We MUST override transferChild from this contract
  *
  * TODO is there a better way to handle the check of _owns for tokenID?
  **************************************/
  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) public {
    //how can we push down to extension?
    require(_owns(msg.sender, _tokenId));
    super.transferChild(_to, _tokenId, _childContract, _childTokenId);
  }

  function transferChildToComposable(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data) public {
    //how can we push down to extension?
    require(_owns(msg.sender, _tokenId));
    super.transferChildToComposable(_to, _tokenId, _childContract, _childTokenId, _data);
  }
  
  
}