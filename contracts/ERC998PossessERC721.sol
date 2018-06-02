

//jshint ignore: start

pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Receiver.sol";

contract ERC998PossessERC721 is ERC721Receiver {

  /**************************************
  * ERC998PossessERC721 Begin
  **************************************/
  
  /**************************************
  * Child Mappings
  **************************************/
  
  // tokenId => child contract
  mapping(uint256 => address[]) private childContracts;
    
  // tokenId => (child address => contract index+1)
  mapping(uint256 => mapping(address => uint256)) private childContractIndex;
  
  // tokenId => (child address => array of child tokens)
  mapping(uint256 => mapping(address => uint256[])) private childTokens;
  
  // tokenId => (child address => (child token => child index+1)
  mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private childTokenIndex;
  
  /**************************************
  * Events
  **************************************/
  
  event Received(address indexed _from, uint256 _childTokenId, bytes _data);
  
  event Added(uint256 indexed _tokenId, address _childContract, uint256 _childTokenId);
  
  event TransferChild(address _from, address _to, uint256 _childTokenId);
  
  
  /**************************************
  * Transfer and Receive Methods
  **************************************/
  
  function childReceived(address _from, uint256 _childTokenId, bytes _data) private {
    // convert _data bytes to uint256, owner nft tokenId passed as uint in bytes
    // bytesToUint(_data) i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 _tokenId;
    assembly { 
      _tokenId := mload(add(_data, 32)) 
    }
    if(_data.length < 32) {
      _tokenId = _tokenId >> 256 - _data.length * 8;
    }

    uint256 childTokensLength = childTokens[_tokenId][_from].length;
    if(childTokensLength == 0) {
      childContracts[_tokenId].push(_from);
      childContractIndex[_tokenId][_from] = childContracts[_tokenId].length;
    }
    childTokens[_tokenId][_from].push(_childTokenId);
    childTokenIndex[_tokenId][_from][_childTokenId] = childTokensLength+1;

    emit Added(_tokenId, _from, _childTokenId);
  }
    

  // receiving NFT to composable, _data is bytes (string) tokenId
  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    childReceived(msg.sender, _childTokenId, _data);
    return ERC721_RECEIVED;
  }

  function transferChild_(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) internal {
    uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][_childTokenId];
    require(tokenIndex != 0, "Child token not owned by tokenId.");

    // remove child token
    uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length-1;
    uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
    childTokens[_tokenId][_childContract][tokenIndex-1] = lastToken;
    childTokens[_tokenId][_childContract].length--;
    delete childTokenIndex[_tokenId][_childContract][_childTokenId];
    childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;

    // remove contract
    if(lastTokenIndex == 0) {
        uint256 contractIndex = childContractIndex[_tokenId][_childContract];
        uint256 lastContractIndex = childContracts[_tokenId].length - 1;
        address lastContract = childContracts[_tokenId][lastContractIndex];
        childContracts[_tokenId][contractIndex-1] = lastContract;
        childContracts[_tokenId].length--;
        delete childContractIndex[_tokenId][_childContract];
        childContractIndex[_tokenId][lastContract] = contractIndex;
    }

    emit TransferChild(this, _to, _childTokenId);
  }

  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
    transferChild_(_to, _tokenId, _childContract, _childTokenId);
    //require that the child was transfered safely to it's destination
    require(
      _childContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")), this, _to, _childTokenId
      )
    );
  }

  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes data) external {
    transferChild_(_to, _tokenId, _childContract, _childTokenId);
    //require that the child was transfered safely to it's destination
    require(
      _childContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")), this, _to, _childTokenId, data
      )
    );
  }
  
  /**************************************
  * Public View Functions (wallet integration)
  **************************************/
  
  // returns the child contracts owned by a composable
  function childContractsOwnedBy(uint256 _tokenId) public view returns (address[]) {
    return childContracts[_tokenId];
  }
  
  // returns the childs owned by the composable for a specific child contract
  function childsOwnedBy(uint256 _tokenId, address _childContract) public view returns (uint256[]) {
    return childTokens[_tokenId][_childContract];
  }
  
  // check if child is owned by this composable
  function childIsOwned(
    uint256 _tokenId, address _childContract, uint256 _childTokenId
  ) public view returns (bool) {
    return childTokenIndex[_tokenId][_childContract][_childTokenId] != 0;    
  }
  
}
