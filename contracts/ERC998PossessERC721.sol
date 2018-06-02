

//jshint ignore: start

pragma solidity ^0.4.24;

interface ERC998NFT {
  event ReceivedChild(uint256 indexed _tokenId, address indexed _childContract, uint256 _childTokenId, address indexed _from);
  event TransferChild(address indexed _to, bytes _data, uint256 indexed _childTokenId);

  function childOwnerOf(address _childContract, uint256 _childTokenId) external view returns (uint256 tokenId);
  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4);
  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external;
  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes data) external;
}

interface ERC998NFTEnumerable {
  function totalChildContracts(uint256 _tokenId) external view returns(uint256);
  function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
  function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256);
  function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}


contract ERC998PossessERC721 is ERC998NFT, ERC998NFTEnumerable {
  
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
  mapping(address => mapping(uint256 => uint256)) private childTokenOwner;

  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 _tokenId;
    assembly {
      _tokenId := calldataload(132)
    }
    if(_data.length < 32) {
      _tokenId = _tokenId >> 256 - _data.length * 8;
    }

    address childContract = msg.sender;

    uint256 childTokensLength = childTokens[_tokenId][childContract].length;
    if(childTokensLength == 0) {
      childContractIndex[_tokenId][childContract] = childContracts[_tokenId].length;
      childContracts[_tokenId].push(childContract);
    }
    childTokens[_tokenId][childContract].push(_childTokenId);
    childTokenIndex[_tokenId][childContract][_childTokenId] = childTokensLength + 1;
    childTokenOwner[childContract][_childTokenId] = _tokenId;

    emit ReceivedChild(_tokenId, childContract, _childTokenId, _from);
    return ERC721_RECEIVED;
  }

  function removeChild(uint256 _tokenId, address _childContract, uint256 _childTokenId) internal {
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

  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
    removeChild(_tokenId, _childContract, _childTokenId);
    //require that the child was transfered safely to it's destination
    require(
      _childContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")), this, _to, _childTokenId
      )
    );
    emit TransferChild(_to, new bytes(0), _childTokenId);
  }

  function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data) external {
    removeChild(_tokenId, _childContract, _childTokenId);
    //require that the child was transfered safely to it's destination
    require(
      _childContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")), this, _to, _childTokenId, _data
      )
    );
    emit TransferChild(_to, _data, _childTokenId);
  }

  function childOwnerOf(address _childContract, uint256 _childTokenId) external view returns (uint256 tokenId) {
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
