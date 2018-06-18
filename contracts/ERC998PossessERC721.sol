

//jshint ignore: start

pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";

interface ERC998NFT {
  event ReceivedChild(address indexed _from, uint256 indexed _tokenId, address indexed _childContract, uint256 _childTokenId);
  event TransferChild(uint256 indexed tokenId, address indexed _to, address indexed _childContract, uint256 _childTokenId);

  function ownerOfChild(address _childContract, uint256 _childTokenId) external view returns (uint256 tokenId);
  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4);
  function transferChild(address _to, address _childContract, uint256 _childTokenId) external;
  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId) external;
  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId, bytes _data) external;
  function isApprovedOrOwnerOf(address _sender, address childContract, uint256 _childTokenId) public view returns (bool);
  function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external;
}

interface ERC998NFTEnumerable {
  function totalChildContracts(uint256 _tokenId) external view returns(uint256);
  function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
  function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256);
  function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}

contract ERC998PossessERC721 is ERC721Token, ERC998NFT, ERC998NFTEnumerable {

  //from zepellin ERC721Receiver.sol
  bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;

  // tokenId => child contract
  mapping(uint256 => address[]) private childContracts;

  // tokenId => (child address => contract index+1)
  mapping(uint256 => mapping(address => uint256)) private childContractIndex;

  // tokenId => (child address => array of child tokens)
  mapping(uint256 => mapping(address => uint256[])) private childTokens;

  // tokenId => (child address => (child token => child index+1)
  mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private childTokenIndex;

  // child address => childId => tokenId
  mapping(address => mapping(uint256 => uint256)) internal childTokenOwner;

  function isApprovedOrOwnerOf(address _sender, address childContract, uint256 _childTokenId) public view returns (bool) {
    uint256 tokenId = ownerOfChild(childContract,_childTokenId);
    if(super.isApprovedOrOwner(_sender, tokenId)) {
      return true;
    }
    address ownerUpOneLevel = ownerOf(tokenId);
    return ERC998PossessERC721(ownerUpOneLevel).isApprovedOrOwnerOf(_sender, this, tokenId);
  }


  function removeChild(uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
    uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][_childTokenId];
    require(tokenIndex != 0, "Child token not owned by token.");

    // remove child token
    uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length-1;
    uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
    childTokens[_tokenId][_childContract][tokenIndex-1] = lastToken;
    childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;
    childTokens[_tokenId][_childContract].length--;
    delete childTokenIndex[_tokenId][_childContract][_childTokenId];
    delete childTokenOwner[_childContract][_childTokenId];

    // remove contract
    if(lastTokenIndex == 0) {
      uint256 contractIndex = childContractIndex[_tokenId][_childContract];
      uint256 lastContractIndex = childContracts[_tokenId].length - 1;
      address lastContract = childContracts[_tokenId][lastContractIndex];
      childContracts[_tokenId][contractIndex] = lastContract;
      childContractIndex[_tokenId][lastContract] = contractIndex;
      childContracts[_tokenId].length--;
      delete childContractIndex[_tokenId][_childContract];
    }
  }

  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, _childContract, _childTokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).safeTransferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId, bytes _data) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, _childContract, _childTokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).safeTransferFrom(this, _to, _childTokenId, _data);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function transferChild(address _to, address _childContract, uint256 _childTokenId) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, _childContract, _childTokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).transferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
    /**************************************
   * TODO move to library
   **************************************/
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      tokenId := calldataload(132)
    }
    if(_data.length < 32) {
      tokenId = tokenId >> 256 - _data.length * 8;
    }
    //END TODO

    require(this == ERC721Basic(msg.sender).ownerOf(_childTokenId), "This contract does not own the child token.");

    receiveChild(_from, tokenId, msg.sender, _childTokenId);
    return ERC721_RECEIVED;
  }


  function receiveChild(address _from,  uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
    require(exists(_tokenId), "tokenId does not exist.");
    require(childTokenIndex[_tokenId][_childContract][_childTokenId] == 0, "Cannot receive child token because it has already been received.");
    uint256 childTokensLength = childTokens[_tokenId][_childContract].length;
    if(childTokensLength == 0) {
      childContractIndex[_tokenId][_childContract] = childContracts[_tokenId].length;
      childContracts[_tokenId].push(_childContract);
    }
    childTokens[_tokenId][_childContract].push(_childTokenId);
    childTokenIndex[_tokenId][_childContract][_childTokenId] = childTokensLength + 1;
    childTokenOwner[_childContract][_childTokenId] = _tokenId;
    emit ReceivedChild(_from, _tokenId, _childContract, _childTokenId);
  }

  // this contract has to be approved first by _childContract
  function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
    receiveChild(_from, _tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).transferFrom(_from, this, _childTokenId);
  }

  function ownerOfChild(address _childContract, uint256 _childTokenId) public view returns (uint256 tokenId) {
    tokenId = childTokenOwner[_childContract][_childTokenId];
    if(tokenId == 0) {
        require(childTokenIndex[tokenId][_childContract][_childTokenId] != 0, "Child token is not owned by any tokens.");
    }
    return tokenId;
  }
  
  function childExists(address _childContract, uint256 _childTokenId) external view returns (bool) {
    uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
    return childTokenIndex[tokenId][_childContract][_childTokenId] != 0;
  }

  function totalChildContracts(uint256 _tokenId) external view returns(uint256) {
    return childContracts[_tokenId].length;
  }

  function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract) {
    require(_index < childContracts[_tokenId].length, "Contract address does not exist for this token and index.");
    return childContracts[_tokenId][_index];
  }

  function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256) {
    return childTokens[_tokenId][_childContract].length;
  }

  function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId) {
    require(_index < childTokens[_tokenId][_childContract].length, "Token does not own a child token at contract address and index.");
    return childTokens[_tokenId][_childContract][_index];
  }

}

