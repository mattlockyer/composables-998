

//jshint ignore: start

pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Receiver.sol";
import "./ERC998Helpers.sol";

contract ERC998PossessERC721 is ERC721Receiver {

  /**************************************
  * ERC998PossessERC721 Begin
  **************************************/
  
  /**************************************
  * Child Mappings
  **************************************/
  
  // mapping from nft to all child contracts
  mapping(uint256 => address[]) childContracts;
  
  // mapping for the child contract address index in the childContracts array
  mapping(uint256 => mapping(address => uint256)) childContractIndex;
  
  // mapping from contract pseudo-address owner nftp to the tokenIds
  mapping(address => uint256[]) childTokens;
  
  // mapping from pseudo owner address to childTokenId to array index
  mapping(address => mapping(uint256 => uint256)) childTokenIndex;
  
  // mapping child pseudo-address to bool
  mapping(address => bool) childOwned;
  
  /**************************************
  * Events
  **************************************/
  
  event Received(address _from, uint256 _childTokenId, bytes _data);
  
  event Added(uint256 _tokenId, address _childContract, uint256 _childTokenId);
  
  event TransferChild(address _from, address _to, uint256 _childTokenId);
  
  /**************************************
  * Utility Methods
  **************************************/

  // generates a pseudo-address from the nft that owns, child contract
  function _childOwner(
    uint256 _tokenId, address _childContract
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _childContract));
  }
  
  // generates a pseudo-address for the child from the nft that owns, child contract, child tokenId
  function _childAddress(
    uint256 _tokenId, address _childContract, uint256 _childTokenId
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _childContract, _childTokenId));
  }
  
  // removes child contract from list of possession contracts
  function _removeContract(uint256 _tokenId, address _childContract) internal {
    uint256 contractIndex = childContractIndex[_tokenId][_childContract];
    uint256 lastContractIndex = childContracts[_tokenId].length - 1;
    address lastContract = childContracts[_tokenId][lastContractIndex];
    childContracts[_tokenId][contractIndex] = lastContract;
    childContracts[_tokenId][lastContractIndex] = 0;
    childContracts[_tokenId].length--;
    childContractIndex[_tokenId][_childContract] = 0;
    childContractIndex[_tokenId][lastContract] = contractIndex;
  }
  
  // removes child from list of possessions
  function _removeChild(address childOwner, uint256 _childTokenId) internal {
    uint256 tokenIndex = childTokenIndex[childOwner][_childTokenId];
    uint256 lastTokenIndex = childTokens[childOwner].length - 1;
    uint256 lastToken = childTokens[childOwner][lastTokenIndex];
    childTokens[childOwner][tokenIndex] = lastToken;
    childTokens[childOwner][lastTokenIndex] = 0;
    childTokens[childOwner].length--;
    childTokenIndex[childOwner][_childTokenId] = 0;
    childTokenIndex[childOwner][lastToken] = tokenIndex;
  }
  
  /**************************************
  * Internal Transfer and Receive Methods
  **************************************/
  
  function transferChild(
    address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId
  ) internal {
    // get the pseudo address of the child from the composable owner, child contract and child tokenId
    address child = _childAddress(_tokenId, _childContract, _childTokenId);
    //require that the child is owned
    require(childOwned[child] == true);
    //require that the child was transfered safely to it's destination
    require(
      _childContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
        this, _to, _childTokenId
      )
    );
    // remove the parent token's ownership of the child token
    childOwned[child] = false;
    // remove the child contract and index
    _removeContract(_tokenId, _childContract);
    // _childOwner is _tokenId and _childContract pseudo address
    address childOwner = _childOwner(_tokenId, _childContract);
    _removeChild(childOwner, _childTokenId);
    
    emit TransferChild(this, _to, _childTokenId);
  }
  
  function childReceived(address _from, uint256 _childTokenId, bytes _data) internal {
    // convert _data bytes to uint256, owner nft tokenId passed as string in bytes
    // bytesToUint(_data) i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 _tokenId = ERC998Helpers.bytesToUint(_data);
    // log the child contract and index
    childContractIndex[_tokenId][_from] = childContracts[_tokenId].length;
    childContracts[_tokenId].push(_from);
    // log the tokenId and index
    address childOwner = _childOwner(_tokenId, _from);
    childTokenIndex[childOwner][_childTokenId] = childTokens[childOwner].length;
    childTokens[childOwner].push(_childTokenId);
    // set bool of owned to true
    childOwned[_childAddress(_tokenId, _from, _childTokenId)] = true;
    // emit event
    emit Added(_tokenId, _from, _childTokenId);
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
    return childTokens[_childOwner(_tokenId, _childContract)];
  }
  
  // check if child is owned by this composable
  function childIsOwned(
    uint256 _tokenId, address _childContract, uint256 _childTokenId
  ) public view returns (bool) {
    return childOwned[_childAddress(_tokenId, _childContract, _childTokenId)];
  }
  
  /**************************************
  * Public Transfer and Receive Functions
  **************************************/
  
  // sending child to account
  // function safeTransferChild(
  //   address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId
  // ) public {
  //   transferChild(_to, _tokenId, _childContract, _childTokenId);
  // }
  
  // sending child directly to another composable
  function safeTransferChild(
    address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data
  ) public {
    transferChild(_to, _tokenId, _childContract, _childTokenId);
    childReceived(_childContract, _childTokenId, _data);
  }
  
  // receiving NFT to composable, _data is bytes (string) tokenId
  function onERC721Received(address _from, uint256 _childTokenId, bytes _data) public returns(bytes4) {
    childReceived(msg.sender, _childTokenId, _data);
    return ERC721_RECEIVED;
  }
  
}