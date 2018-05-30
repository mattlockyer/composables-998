

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
  
  // implementation of the owns method from cryptokitties
  function _owns(address _claimant, uint256 _tokenId) internal view returns(bool) {
    return (tokenOwner[_tokenId] == _claimant);
  }
  
  // override the transferNFTP method to include check of NFT ownership
  function safeTransferChild(
    address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data
  ) public {
    // require that the composable nft is owned by sender
    require(_owns(msg.sender, _tokenId));
    transferChild(_to, _tokenId, _childContract, _childTokenId);
    childReceived(_childContract, _childTokenId, _data);
  }
  
}