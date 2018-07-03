

//jshint ignore: start

pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "zeppelin-solidity/contracts/AddressUtils.sol";

interface ERC998ERC721TopDown {
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

interface ERC998ERC721TopDownEnumerable {
  function totalChildContracts(uint256 _tokenId) external view returns(uint256);
  function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
  function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256);
  function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}

interface ERC998ERC223TopDown {
  event ReceivedERC223(address indexed _from, uint256 indexed _tokenId, address indexed _erc223Contract, uint256 _value);
  event TransferERC223(uint256 indexed _tokenId, address indexed _to, address indexed _erc223Contract, uint256 _value);

  function tokenFallback(address _from, uint256 _value, bytes _data) external;
  function balanceOfERC223(uint256 _tokenId, address __erc223Contract) external view returns(uint256);
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value) external;
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value, bytes _data) external;
  function transferFromERC20(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) external;
  function isApprovedOrOwnerOf(address _sender, address childContract, uint256 _childTokenId) public view returns (bool);

}

interface ERC998ERC223TopDownEnumerable {
  function totalERC223Contracts(uint256 _tokenId) external view returns(uint256);
  function erc223ContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address);
}

interface ERC20AndERC223TransferFunctions {
  function transferFrom(address _from, address _to, uint _value) public returns (bool success);
  function transfer(address to, uint value) public returns (bool success);
  function transfer(address to, uint value, bytes data) public returns (bool success);
}

contract ComposableTopDown is ERC721Token, ERC998ERC721TopDown, ERC998ERC721TopDownEnumerable,
                                     ERC998ERC223TopDown, ERC998ERC223TopDownEnumerable {


  constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}

  // wrapper on minting new 721
  function mint721(address _to) public returns(uint256) {
    _mint(_to, allTokens.length + 1);
    return allTokens.length;
  }
  //from zepellin ERC721Receiver.sol
  //old version
  bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;
  //new version


  ////////////////////////////////////////////////////////
  // ERC998ERC721 and ERC998ERC721Enumerable implementation
  ////////////////////////////////////////////////////////

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

  // use staticcall opcode to enforce no state changes in external call
  // using staticcall prevents reentrance attacks
  function staticCall(address theContract, bytes calldata) internal view returns (bool callSuccess, bytes32 result) {
    assembly {
      callSuccess := staticcall(gas, theContract, add(calldata, 0x20), mload(calldata), calldata, 0x20)
      result := mload(calldata)
    }
    return (callSuccess, result);
  }

  function isApprovedOrOwnerOf(address _sender, address _childContract, uint256 _childTokenId) public view returns (bool) {
    uint256 tokenId;
    if(_childContract == address(0)) {
      tokenId = _childTokenId;
    }
    else {
      tokenId = ownerOfChild(_childContract,_childTokenId);
    }
    address towner = ownerOf(tokenId);
    if(_sender == towner || _sender == getApproved(tokenId) || isApprovedForAll(towner, _sender)) {
      return true;
    }
    if(towner == address(this)) {
      return isApprovedOrOwnerOf(_sender, this, tokenId);
    }
    else {
      bytes memory calldata = abi.encodeWithSelector(/* isApprovedOrOwnerOf */ 0xed9ac0eb, _sender, this, tokenId);
      (bool success, bytes32 result) = staticCall(towner, calldata);
      require(success, "isApprovedOrOwnerOf static call failed");
      return uint256(result) == 0x01;
    }
  }

  function removeChild(uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
    uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][_childTokenId];
    require(tokenIndex != 0, "Child token not owned by token.");

    // remove child token
    uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length-1;
    uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
    if(_childTokenId == lastToken) {
      childTokens[_tokenId][_childContract][tokenIndex-1] = lastToken;
      childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;
    }
    childTokens[_tokenId][_childContract].length--;
    delete childTokenIndex[_tokenId][_childContract][_childTokenId];
    delete childTokenOwner[_childContract][_childTokenId];

    // remove contract
    if(lastTokenIndex == 0) {
      uint256 lastContractIndex = childContracts[_tokenId].length - 1;
      address lastContract = childContracts[_tokenId][lastContractIndex];
      if(_childContract != lastContract) {
        uint256 contractIndex = childContractIndex[_tokenId][_childContract];
        childContracts[_tokenId][contractIndex] = lastContract;
        childContractIndex[_tokenId][lastContract] = contractIndex;
      }
      childContracts[_tokenId].length--;
      delete childContractIndex[_tokenId][_childContract];
    }
  }

  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, address(0), tokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).safeTransferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId, bytes _data) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, address(0), tokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721Basic(_childContract).safeTransferFrom(this, _to, _childTokenId, _data);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function transferChild(address _to, address _childContract, uint256 _childTokenId) external {
    uint256 tokenId = ownerOfChild(_childContract, _childTokenId);
    require(isApprovedOrOwnerOf(msg.sender, address(0), tokenId));
    removeChild(tokenId, _childContract, _childTokenId);
    //this is here to be compatible with cryptokitties and other old contracts that require being owner and approved
    // before transferring.
    //does not work with current standard which does not allow approving self, so we must let it fail in that case.
    _childContract.call(/* approve(address,uint256) */ 0x095ea7b3, this, _childTokenId);
    ERC721Basic(_childContract).transferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  // this contract has to be approved first by _childContract
  function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
    receiveChild(_from, _tokenId, _childContract, _childTokenId);
    address childTokenOwnerAddress = ERC721Basic(_childContract).ownerOf(_childTokenId);
    require(childTokenOwnerAddress == msg.sender ||
      ERC721Basic(_childContract).getApproved(_tokenId) == msg.sender ||
      ERC721Basic(_childContract).isApprovedForAll(childTokenOwnerAddress, msg.sender));
    ERC721Basic(_childContract).transferFrom(_from, this, _childTokenId);
  }



  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
    require(msg.sender.isContract(), "msg.sender is not a contract.");
    /**************************************
    * TODO move to library
    **************************************/
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      // new onERC721Received
      //tokenId := calldataload(164)
      tokenId := calldataload(132)
    }
    if(_data.length < 32) {
      tokenId = tokenId >> 256 - _data.length * 8;
    }
    //END TODO

    //require(this == ERC721Basic(msg.sender).ownerOf(_childTokenId), "This contract does not own the child token.");

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

  ////////////////////////////////////////////////////////
  // ERC998ERC223 and ERC998ERC223Enumerable implementation
  ////////////////////////////////////////////////////////

  // tokenId => token contract
  mapping(uint256 => address[]) erc223Contracts;

  // tokenId => (token contract => token contract index)
  mapping(uint256 => mapping(address => uint256)) erc223ContractIndex;
  
  // tokenId => (token contract => balance)
  mapping(uint256 => mapping(address => uint256)) erc223Balances;
  
  function balanceOfERC223(uint256 _tokenId, address _erc223Contract) external view returns(uint256) {
    return erc223Balances[_tokenId][_erc223Contract];
  }

  function removeERC223(uint256 _tokenId, address _erc223Contract, uint256 _value) private {
    if(_value == 0) {
      return;
    }
    uint256 erc223Balance = erc223Balances[_tokenId][_erc223Contract];
    require(erc223Balance >= _value, "Not enough token available to transfer.");
    uint256 newERC223Balance = erc223Balance - _value;
    erc223Balances[_tokenId][_erc223Contract] = newERC223Balance;
    if(newERC223Balance == 0) {
      uint256 lastContractIndex = erc223Contracts[_tokenId].length - 1;
      address lastContract = erc223Contracts[_tokenId][lastContractIndex];
      if(_erc223Contract != lastContract) {
        uint256 contractIndex = erc223ContractIndex[_tokenId][_erc223Contract];
        erc223Contracts[_tokenId][contractIndex] = lastContract;
        erc223ContractIndex[_tokenId][lastContract] = contractIndex;
      }
      erc223Contracts[_tokenId].length--;
      delete erc223ContractIndex[_tokenId][_erc223Contract];
    }
  }
  
  
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value) external {
    require(isApprovedOrOwnerOf(msg.sender, address(0),_tokenId));
    removeERC223(_tokenId, _erc223Contract, _value);
    require(ERC20AndERC223TransferFunctions(_erc223Contract).transfer(_to, _value), "ERC20 transfer failed.");
    emit TransferERC223(_tokenId, _to, _erc223Contract, _value);
  }
  
  // implementation of ERC 223
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value, bytes _data) external {
    require(isApprovedOrOwnerOf(msg.sender, address(0), _tokenId));
    require(erc223Balances[_tokenId][_erc223Contract] >= _value, "Not enough token available to transfer.");
    erc223Received(this, _tokenId, _erc223Contract, _value);
    require(ERC20AndERC223TransferFunctions(_erc223Contract).transfer(_to, _value, _data), "ERC223 transfer failed.");
    emit TransferERC223(_tokenId, _to, _erc223Contract, _value);
  }
  
  function erc223Received(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) private {
    require(exists(_tokenId), "tokenId does not exist.");
    if(_value == 0) {
      return;
    }
    uint256 erc223Balance = erc223Balances[_tokenId][_erc223Contract];
    if(erc223Balance == 0) {
      erc223ContractIndex[_tokenId][_erc223Contract] = erc223Contracts[_tokenId].length;
      erc223Contracts[_tokenId].push(_erc223Contract);
    }
    erc223Balances[_tokenId][_erc223Contract] += _value;
    emit ReceivedERC223(_from, _tokenId, _erc223Contract, _value);
  }
  
  // used by ERC 223
  function tokenFallback(address _from, uint256 _value, bytes _data) external {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the token to.");
    require(msg.sender.isContract(), "msg.sender is not a contract");
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
    erc223Received(_from, tokenId, msg.sender, _value);
  }
  
  // this contract has to be approved first by _erc223Contract
  function transferFromERC20(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) external {
    require(isApprovedOrOwnerOf(msg.sender, address(0), _tokenId));
    erc223Received(_from, _tokenId, _erc223Contract, _value);
    require(ERC20AndERC223TransferFunctions(_erc223Contract).transferFrom(_from, this, _value), "ERC20 transfer failed.");
  }
  
  function erc223ContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address) {
    require(_index < erc223Contracts[_tokenId].length, "Contract address does not exist for this token and index.");
    return erc223Contracts[_tokenId][_index];
  }
  
  function totalERC223Contracts(uint256 _tokenId) external view returns(uint256) {
    return erc223Contracts[_tokenId].length;
  }
  
}