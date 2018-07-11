/**********************************
/* Author: Nick Mudge
/* This implementation was written by Nick Mudge <nick@perfectabstractions.com>, https://medium.com/@mudgen.
/* Chat with us on Discord in the NFTy Magicians server: https://discord.gg/uxkHy3
/**********************************/

//jshint ignore: start

pragma solidity ^0.4.24;

import "./ERC721.sol";
import "./ERC721Receiver.sol";
import "./SafeMath.sol";

interface ERC998ERC721TopDown {
  event ReceivedChild(address indexed _from, uint256 indexed _tokenId, address indexed _childContract, uint256 _childTokenId);
  event TransferChild(uint256 indexed tokenId, address indexed _to, address indexed _childContract, uint256 _childTokenId);


  // gets the address and token that owns the supplied tokenId. isParent says if parentTokenId is a parent token or not.
  function tokenOwnerOf(uint256 _tokenId) external view returns (address tokenOwner, uint256 parentTokenId, uint256 isParent);
  function ownerOfChild(address _childContract, uint256 _childTokenId) external view returns (uint256 parentTokenId, uint256 isParent);
  function onERC721Received(address _operator, address _from, uint256 _childTokenId, bytes _data) external returns(bytes4);
  function onERC998Removed(address _operator, address _toContract, uint256 _childTokenId, bytes _data) external;
  function transferChild(address _to, address _childContract, uint256 _childTokenId) external;
  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId) external;
  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId, bytes _data) external;
  // getChild function enables older contracts like cryptokitties to be transferred into a composable
  // The _childContract must approve this contract. Then getChild can be called.
  function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external;
}

interface ERC998ERC721TopDownEnumerable {
  function totalChildContracts(uint256 _tokenId) external view returns(uint256);
  function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
  function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256);
  function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}

interface ERC998ERC20TopDown {
  event ReceivedERC20(address indexed _from, uint256 indexed _tokenId, address indexed _erc223Contract, uint256 _value);
  event TransferERC20(uint256 indexed _tokenId, address indexed _to, address indexed _erc223Contract, uint256 _value);

  function tokenOwnerOf(uint256 _tokenId) external view returns (address tokenOwner, uint256 parentTokenId, uint256 isParent);
  function tokenFallback(address _from, uint256 _value, bytes _data) external;
  function balanceOfERC20(uint256 _tokenId, address __erc223Contract) external view returns(uint256);
  function transferERC20(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value) external;
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value, bytes _data) external;
  function getERC20(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) external;

}

interface ERC998ERC20TopDownEnumerable {
  function totalERC20Contracts(uint256 _tokenId) external view returns(uint256);
  function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address);
}

interface ERC20AndERC223 {
  function transferFrom(address _from, address _to, uint _value) external returns (bool success);
  function transfer(address to, uint value) external returns (bool success);
  function transfer(address to, uint value, bytes data) external returns (bool success);
  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

contract ComposableTopDown is ERC721, ERC998ERC721TopDown, ERC998ERC721TopDownEnumerable,
                                     ERC998ERC20TopDown, ERC998ERC20TopDownEnumerable {
  // tokenOwnerOf.selector;
  uint256 constant TOKEN_OWNER_OF = 0x89885a59;
  uint256 constant OWNER_OF_CHILD = 0xeadb80b8;

  uint256 tokenCount = 0;

  // tokenId => token owner
  mapping (uint256 => address) internal tokenIdToTokenOwner;

  // root token owner address => (tokenId => approved address)
  mapping (address => mapping (uint256 => address)) internal rootOwnerAndTokenIdToApprovedAddress;

  // token owner address => token count
  mapping (address => uint256) internal tokenOwnerToTokenCount;

  // token owner => (operator address => bool)
  mapping (address => mapping (address => bool)) internal tokenOwnerToOperators;


  //constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}

  // wrapper on minting new 721
  function mint(address _to) public returns(uint256) {
    tokenCount++;
    uint256 tokenCount_ = tokenCount;
    tokenIdToTokenOwner[tokenCount_] = _to;
    tokenOwnerToTokenCount[_to]++;
    return tokenCount_;
  }
  //from zepellin ERC721Receiver.sol
  //old version
  bytes4 constant ERC721_RECEIVED_OLD = 0xf0b9e5ba;
  //new version
  bytes4 constant ERC721_RECEIVED_NEW = 0x150b7a02;

  ////////////////////////////////////////////////////////
  // ERC721 implementation
  ////////////////////////////////////////////////////////

  function isContract(address _addr) internal view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(_addr) }
    return size > 0;
  }

  function tokenOwnerOf(uint256 _tokenId) external view returns (address tokenOwner, uint256 parentTokenId, uint256 isParent) {
    tokenOwner = tokenIdToTokenOwner[_tokenId];
    require(tokenOwner != address(0));
    if(tokenOwner == address(this)) {
      (parentTokenId, isParent) = ownerOfChild(address(this), _tokenId);
    }
    else {
      bool callSuccess;
      // 0xeadb80b8 == ownerOfChild(address,uint256)
      bytes memory calldata = abi.encodeWithSelector(0xeadb80b8, address(this), _tokenId);
      assembly {
        callSuccess := staticcall(gas, tokenOwner, add(calldata, 0x20), mload(calldata), calldata, 0x40)
        if callSuccess {
          parentTokenId := mload(calldata)
          isParent := mload(add(calldata,0x20))
        }
      }
      if(callSuccess && isParent >> 8 == OWNER_OF_CHILD) {
        isParent = TOKEN_OWNER_OF << 8 | uint8(isParent);
      }
      else {
        isParent = TOKEN_OWNER_OF << 8;
        parentTokenId = 0;
      }
    }
    return (tokenOwner, parentTokenId, isParent);
  }

  // returns the owner at the top of the tree of composables
  function ownerOf(uint256 _tokenId) public view returns (address rootOwner) {
    rootOwner = tokenIdToTokenOwner[_tokenId];
    require(rootOwner != address(0));
    uint256 isParent = 1;
    bool callSuccess;
    bytes memory calldata;
    while(uint8(isParent) > 0) {
      if(rootOwner == address(this)) {
        (_tokenId, isParent) = ownerOfChild(address(this), _tokenId);
        if(uint8(isParent) > 0) {
          rootOwner = tokenIdToTokenOwner[_tokenId];
        }
      }
      else {
        if(isContract(rootOwner)) {
          //0x89885a59 == "tokenOwnerOf(uint256)"
          calldata = abi.encodeWithSelector(0x89885a59, _tokenId);
          assembly {
            callSuccess := staticcall(gas, rootOwner, add(calldata, 0x20), mload(calldata), calldata, 0x60)
            if callSuccess {
              rootOwner := mload(calldata)
              _tokenId := mload(add(calldata,0x20))
              isParent := mload(add(calldata,0x40))
            }
          }
          if(callSuccess == false || isParent >> 8 != TOKEN_OWNER_OF) {
            //0x6352211e == "ownerOf(uint256)"
            calldata = abi.encodeWithSelector(0x6352211e, _tokenId);
            assembly {
              callSuccess := staticcall(gas, rootOwner, add(calldata, 0x20), mload(calldata), calldata, 0x20)
              if callSuccess {
                rootOwner := mload(calldata)
              }
            }
            require(callSuccess, "rootOwnerOf failed");
            isParent = 0;
          }
        }
        else {
          isParent = 0;
        }
      }
    }
    return rootOwner;
  }

  function balanceOf(address _tokenOwner)  external view returns (uint256) {
    require(_tokenOwner != address(0));
    return tokenOwnerToTokenCount[_tokenOwner];
  }


  function approve(address _approved, uint256 _tokenId) external {
    address tokenOwner = tokenIdToTokenOwner[_tokenId];
    address rootOwner = ownerOf(_tokenId);
    require(tokenOwner != address(0));
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender]
    || tokenOwner == msg.sender  || tokenOwnerToOperators[tokenOwner][msg.sender]);

    rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] = _approved;
    emit Approval(rootOwner, _approved, _tokenId);
  }

  function getApproved(uint256 _tokenId) public view returns (address)  {
    address rootOwner = ownerOf(_tokenId);
    return rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId];
  }

  function setApprovalForAll(address _operator, bool _approved) external {
    require(_operator != address(0));
    tokenOwnerToOperators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  function isApprovedForAll(address _owner, address _operator ) external  view returns (bool)  {
    require(_owner != address(0));
    require(_operator != address(0));
    return tokenOwnerToOperators[_owner][_operator];
  }



  function _transferFrom(address _from, address _to, uint256 _tokenId) private {
    address tokenOwner = tokenIdToTokenOwner[_tokenId];
    require(tokenOwner == _from);
    require(_to != address(0));
    address rootOwner = ownerOf(_tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
    rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] == msg.sender ||
    tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);

    // clear approval
    if(rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] != address(0)) {
      delete rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId];
    }

    // remove and transfer token
    if(_from != _to) {
      assert(tokenOwnerToTokenCount[_from] > 0);
      tokenOwnerToTokenCount[_from]--;
      tokenIdToTokenOwner[_tokenId] = _to;
      tokenOwnerToTokenCount[_to]++;
    }
    emit Transfer(_from, _to, _tokenId);

    if(isContract(_from)) {
      //0x0da719ec == "onERC998Removed(address,address,uint256,bytes)"
      bytes memory calldata = abi.encodeWithSelector(0x0da719ec, msg.sender, _to, _tokenId,"");
      assembly {
        let success := call(gas, _from, 0, add(calldata, 0x20), mload(calldata), calldata, 0)
      }
    }

  }

  function transferFrom(address _from, address _to, uint256 _tokenId) external {
    _transferFrom(_from, _to, _tokenId);
  }

  function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
    _transferFrom(_from, _to, _tokenId);
    if(isContract(_to)) {
      bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "");
      require(retval == ERC721_RECEIVED_OLD);
    }
  }

  function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes _data) external {
    _transferFrom(_from, _to, _tokenId);
    if(isContract(_to)) {
      bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
      require(retval == ERC721_RECEIVED_OLD);
    }
  }

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

  function onERC998Removed(address _operator, address _toContract, uint256 _childTokenId, bytes _data) external {
    uint256 tokenId = childTokenOwner[msg.sender][_childTokenId];
    removeChild(tokenId, msg.sender, _childTokenId);
  }


  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId) external {
    (uint256 tokenId, uint256 isParent) = ownerOfChild(_childContract, _childTokenId);
    require(uint8(isParent) > 0);
    address tokenOwner = tokenIdToTokenOwner[tokenId];
    require(_to != address(0));
    address rootOwner = ownerOf(tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
      rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender ||
      tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721(_childContract).safeTransferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function safeTransferChild(address _to, address _childContract, uint256 _childTokenId, bytes _data) external {
    (uint256 tokenId, uint256 isParent) = ownerOfChild(_childContract, _childTokenId);
    require(uint8(isParent) > 0);
    address tokenOwner = tokenIdToTokenOwner[tokenId];
    require(_to != address(0));
    address rootOwner = ownerOf(tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
      rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender ||
      tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);
    removeChild(tokenId, _childContract, _childTokenId);
    ERC721(_childContract).safeTransferFrom(this, _to, _childTokenId, _data);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  function transferChild(address _to, address _childContract, uint256 _childTokenId) external {
    (uint256 tokenId, uint256 isParent) = ownerOfChild(_childContract, _childTokenId);
    require(uint8(isParent) > 0);
    address tokenOwner = tokenIdToTokenOwner[tokenId];
    require(_to != address(0));
    address rootOwner = ownerOf(tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
      rootOwnerAndTokenIdToApprovedAddress[rootOwner][tokenId] == msg.sender ||
      tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);
    removeChild(tokenId, _childContract, _childTokenId);
    //this is here to be compatible with cryptokitties and other old contracts that require being owner and approved
    // before transferring.
    //does not work with current standard which does not allow approving self, so we must let it fail in that case.
    //0x095ea7b3 == "approve(address,uint256)"
    bytes memory calldata = abi.encodeWithSelector(0x095ea7b3, this, _childTokenId);
    assembly {
      let success := call(gas, _childContract, 0, add(calldata, 0x20), mload(calldata), calldata, 0)
    }
    ERC721(_childContract).transferFrom(this, _to, _childTokenId);
    emit TransferChild(tokenId, _to, _childContract, _childTokenId);
  }

  // this contract has to be approved first in _childContract
  function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
    receiveChild(_from, _tokenId, _childContract, _childTokenId);
    require(_from == msg.sender ||
      ERC721(_childContract).isApprovedForAll(_from, msg.sender) ||
      ERC721(_childContract).getApproved(_childTokenId) == msg.sender);
    ERC721(_childContract).transferFrom(_from, this, _childTokenId);
    //cause out of gas error if circular ownership
    ownerOf(_tokenId);
  }

  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
    require(isContract(msg.sender), "msg.sender is not a contract.");
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
    //cause out of gas error if circular ownership
    ownerOf(tokenId);
    return ERC721_RECEIVED_OLD;
  }


  function onERC721Received(address _operator, address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
    require(isContract(msg.sender), "msg.sender is not a contract.");
    /**************************************
    * TODO move to library
    **************************************/
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      // new onERC721Received
      tokenId := calldataload(164)
      //tokenId := calldataload(132)
    }
    if(_data.length < 32) {
      tokenId = tokenId >> 256 - _data.length * 8;
    }
    //END TODO

    //require(this == ERC721Basic(msg.sender).ownerOf(_childTokenId), "This contract does not own the child token.");

    receiveChild(_from, tokenId, msg.sender, _childTokenId);
    //cause out of gas error if circular ownership
    ownerOf(tokenId);
    return ERC721_RECEIVED_NEW;
  }


  function receiveChild(address _from,  uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
    require(tokenIdToTokenOwner[_tokenId] != address(0), "_tokenId does not exist.");
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

  function ownerOfChild(address _childContract, uint256 _childTokenId) public view returns (uint256 parentTokenId, uint256 isParent) {
    parentTokenId = childTokenOwner[_childContract][_childTokenId];
    if(parentTokenId == 0 && childTokenIndex[parentTokenId][_childContract][_childTokenId] == 0) {
      return (0, OWNER_OF_CHILD << 8);
    }
    return (parentTokenId, OWNER_OF_CHILD << 8 | 1);
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
  
  function balanceOfERC20(uint256 _tokenId, address _erc223Contract) external view returns(uint256) {
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
  
  
  function transferERC20(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value) external {
    address tokenOwner = tokenIdToTokenOwner[_tokenId];
    require(_to != address(0));
    address rootOwner = ownerOf(_tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
      rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] == msg.sender ||
      tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);
    removeERC223(_tokenId, _erc223Contract, _value);
    require(ERC20AndERC223(_erc223Contract).transfer(_to, _value), "ERC20 transfer failed.");
    emit TransferERC20(_tokenId, _to, _erc223Contract, _value);
  }
  
  // implementation of ERC 223
  function transferERC223(uint256 _tokenId, address _to, address _erc223Contract, uint256 _value, bytes _data) external {
    address tokenOwner = tokenIdToTokenOwner[_tokenId];
    require(_to != address(0));
    address rootOwner = ownerOf(_tokenId);
    require(rootOwner == msg.sender || tokenOwnerToOperators[rootOwner][msg.sender] ||
      rootOwnerAndTokenIdToApprovedAddress[rootOwner][_tokenId] == msg.sender ||
      tokenOwner == msg.sender || tokenOwnerToOperators[tokenOwner][msg.sender]);
    removeERC223(_tokenId, _erc223Contract, _value);
    require(ERC20AndERC223(_erc223Contract).transfer(_to, _value, _data), "ERC223 transfer failed.");
    emit TransferERC20(_tokenId, _to, _erc223Contract, _value);
  }

  // this contract has to be approved first by _erc223Contract
  function getERC20(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) public {
    bool allowed = _from == msg.sender;
    if(!allowed) {
      uint256 remaining;
      // 0xdd62ed3e == allowance(address,address)
      bytes memory calldata = abi.encodeWithSelector(0xdd62ed3e,_from,msg.sender);
      bool callSuccess;
      assembly {
        callSuccess := staticcall(gas, _erc223Contract, add(calldata, 0x20), mload(calldata), calldata, 0x20)
        if callSuccess {
          remaining := mload(calldata)
        }
      }
      require(callSuccess, "call to allowance failed");
      require(remaining >= _value, "Value greater than remaining");
      allowed = true;
    }
    require(allowed, "not allowed to getERC20");
    erc223Received(_from, _tokenId, _erc223Contract, _value);
    require(ERC20AndERC223(_erc223Contract).transferFrom(_from, this, _value), "ERC20 transfer failed.");
  }

  function erc223Received(address _from, uint256 _tokenId, address _erc223Contract, uint256 _value) private {
    require(tokenIdToTokenOwner[_tokenId] != address(0), "_tokenId does not exist.");
    if(_value == 0) {
      return;
    }
    uint256 erc223Balance = erc223Balances[_tokenId][_erc223Contract];
    if(erc223Balance == 0) {
      erc223ContractIndex[_tokenId][_erc223Contract] = erc223Contracts[_tokenId].length;
      erc223Contracts[_tokenId].push(_erc223Contract);
    }
    erc223Balances[_tokenId][_erc223Contract] += _value;
    emit ReceivedERC20(_from, _tokenId, _erc223Contract, _value);
  }
  
  // used by ERC 223
  function tokenFallback(address _from, uint256 _value, bytes _data) external {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the token to.");
    require(isContract(msg.sender), "msg.sender is not a contract");
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
  

  
  function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address) {
    require(_index < erc223Contracts[_tokenId].length, "Contract address does not exist for this token and index.");
    return erc223Contracts[_tokenId][_index];
  }
  
  function totalERC20Contracts(uint256 _tokenId) external view returns(uint256) {
    return erc223Contracts[_tokenId].length;
  }
  
}