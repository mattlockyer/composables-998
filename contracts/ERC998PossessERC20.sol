

//jshint ignore: start

pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "zeppelin-solidity/contracts/AddressUtils.sol";

interface ERC998FT {
  event ReceivedToken(address indexed _from, uint256 indexed _tokenId, address indexed _tokenContract, uint256 _value);
  event TransferToken(uint256 indexed _tokenId, address indexed _to, address indexed _tokenContract, uint256 _value);

  function tokenFallback(address _from, uint256 _value, bytes _data) external;
  function balanceOfToken(uint256 _tokenId, address __tokenContract) external view returns(uint256);
  function transferToken(uint256 _tokenId, address _to, address _tokenContract, uint256 _value) external;
  function transferToken(uint256 _tokenId, address _to, address _tokenContract, uint256 _value, bytes _data) external;
  function getToken(address _from, uint256 _tokenId, address _tokenContract, uint256 _value) external;

}

interface ERC998FTEnumerable {
  function totalTokenContracts(uint256 _tokenId) external view returns(uint256);
  function tokenContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address);
}





contract ERC998PossessERC20 is ERC721Token, ERC998FT, ERC998FTEnumerable {
  using AddressUtils for address;

  /**************************************
  * ERC998PossessERC20 Begin
  **************************************/

  // tokenId => token contract
  mapping(uint256 => address[]) tokenContracts;
  
  // tokenId => (token contract => token contract index)
  mapping(uint256 => mapping(address => uint256)) tokenContractIndex;

  // tokenId => (token contract => balance)
  mapping(uint256 => mapping(address => uint256)) tokenBalances;

  function balanceOfToken(uint256 _tokenId, address _tokenContract) external view returns(uint256) {
    return tokenBalances[_tokenId][_tokenContract];
  }
  

  function removeToken(uint256 _tokenId, address _tokenContract, uint256 _value) private {
    if(_value == 0) {
      return;
    }
    uint256 tokenBalance = tokenBalances[_tokenId][_tokenContract];
    require(tokenBalance >= _value, "Not enough token available to transfer.");
    uint256 newTokenBalance = tokenBalance - _value;
    tokenBalances[_tokenId][_tokenContract] = newTokenBalance;
    if(newTokenBalance == 0) {
      uint256 contractIndex = tokenContractIndex[_tokenId][_tokenContract];
      uint256 lastContractIndex = tokenContracts[_tokenId].length - 1;
      address lastContract = tokenContracts[_tokenId][lastContractIndex];
      tokenContracts[_tokenId][contractIndex] = lastContract;
      tokenContractIndex[_tokenId][lastContract] = contractIndex;
      tokenContracts[_tokenId].length--;
      delete tokenContractIndex[_tokenId][_tokenContract];
    }
  }
  

  function transferToken(uint256 _tokenId, address _to, address _tokenContract, uint256 _value) external {
    require(isApprovedOrOwner(msg.sender, _tokenId));
    removeToken(_tokenId, _tokenContract, _value);
    require(
      _tokenContract.call(
        abi.encodeWithSignature("transfer(address,uint256)", _to, _value), "Token transfer failed."
      )
    );
    emit TransferToken(_tokenId, _to, _tokenContract, _value);
  }

  // implementation of ERC 223
  function transferToken(uint256 _tokenId, address _to, address _tokenContract, uint256 _value, bytes _data) external {
    require(isApprovedOrOwner(msg.sender, _tokenId));
    require(tokenBalances[_tokenId][_tokenContract] >= _value, "Not enough token available to transfer.");
    tokenReceived(this, _tokenId, _tokenContract, _value);
    require(
      _tokenContract.call(
        abi.encodeWithSignature("transfer(address,uint256,bytes)", _to, _value, _data), "Token transfer failed."
      )
    );
    emit TransferToken(_tokenId, _to, _tokenContract, _value);
  }

  function tokenReceived(address _from, uint256 _tokenId, address _tokenContract, uint256 _value) private {
    require(exists(_tokenId), "tokenId does not exist.");
    require(_tokenContract.isContract(), "Supplied token contract is not a contract");
    if(_value == 0) {
      return;
    }
    uint256 tokenBalance = tokenBalances[_tokenId][_tokenContract];
    if(tokenBalance == 0) {
      tokenContractIndex[_tokenId][_tokenContract] = tokenContracts[_tokenId].length;
      tokenContracts[_tokenId].push(_tokenContract);
    }
    tokenBalances[_tokenId][_tokenContract] += _value;
    emit ReceivedToken(_from, _tokenId, _tokenContract, _value);
  }

  // used by ERC 223: c
  function tokenFallback(address _from, uint256 _value, bytes _data) external {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the token to.");
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
    tokenReceived(_from, tokenId, msg.sender, _value);
  }

  // this contract has to be approved first by _tokenContract
  function getToken(address _from, uint256 _tokenId, address _tokenContract, uint256 _value) external {
    tokenReceived(_from, _tokenId, _tokenContract, _value);
    require(
      _tokenContract.call(
        abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, this, _value), "Token transfer failed."
      )
    );
  }

  function tokenContractByIndex(uint256 _tokenId, uint256 _index) external view returns(address) {
    require(_index < tokenContracts[_tokenId].length, "Contract address does not exist for this token and index.");
    return tokenContracts[_tokenId][_index];
  }

  function totalTokenContracts(uint256 _tokenId) external view returns(uint256) {
    return tokenContracts[_tokenId].length;
  }
  
}