

//jshint ignore: start

pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/ERC721/ERC721Receiver.sol";
import "./ERC998Helpers.sol";

contract ERC998PossessERC721 is ERC721Receiver {

  /**************************************
  * ERC998PossessERC721 Begin
  **************************************/
  
  /**************************************
  * NFTP Mappings
  **************************************/
  
  // mapping from nft to all ftp and nftp contracts
  mapping(uint256 => address[]) nftpContracts;
  
  // mapping for the nftp contract index
  mapping(uint256 => mapping(address => uint256)) nftpContractIndex;
  
  // mapping from contract pseudo-address owner nftp to the tokenIds
  mapping(address => uint256[]) nftpTokens;
  
  // mapping from pseudo owner address to nftpTokenId to array index
  mapping(address => mapping(uint256 => uint256)) nftpTokenIndex;
  
  // mapping NFTP pseudo-address to bool
  mapping(address => bool) nftpOwned;
  
  /**************************************
  * Events
  **************************************/
  
  event Received(address _from, uint256 _nftpTokenId, bytes _data);
  
  event Added(uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId);
  
  event TransferNFTP(address _from, address _to, uint256 _nftpTokenId);
  
  /**************************************
  * Utility Methods
  **************************************/

  // generates a pseudo-address from the nft that owns, nftp contract
  function _nftpOwner(
    uint256 _tokenId, address _nftpContract
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _nftpContract));
  }
  
  // generates a pseudo-address for the nftp from the nft that owns, nftp contract, nftp tokenId
  function _nftpAddress(
    uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _nftpContract, _nftpTokenId));
  }
  
  // removes ftp/nftp contract from list of possession contracts
  function _removeContract(uint256 _tokenId, address _nftpContract) internal {
    uint256 contractIndex = nftpContractIndex[_tokenId][_nftpContract];
    uint256 lastContractIndex = nftpContracts[_tokenId].length - 1;
    address lastContract = nftpContracts[_tokenId][lastContractIndex];
    nftpContracts[_tokenId][contractIndex] = lastContract;
    nftpContracts[_tokenId][lastContractIndex] = 0;
    nftpContracts[_tokenId].length--;
    nftpContractIndex[_tokenId][_nftpContract] = 0;
    nftpContractIndex[_tokenId][lastContract] = contractIndex;
  }
  
  // removes nftp from list of possessions
  function _removeNFTP(address nftpOwner, uint256 _nftpTokenId) internal {
    uint256 tokenIndex = nftpTokenIndex[nftpOwner][_nftpTokenId];
    uint256 lastTokenIndex = nftpTokens[nftpOwner].length - 1;
    uint256 lastToken = nftpTokens[nftpOwner][lastTokenIndex];
    nftpTokens[nftpOwner][tokenIndex] = lastToken;
    nftpTokens[nftpOwner][lastTokenIndex] = 0;
    nftpTokens[nftpOwner].length--;
    nftpTokenIndex[nftpOwner][_nftpTokenId] = 0;
    nftpTokenIndex[nftpOwner][lastToken] = tokenIndex;
  }
  
  /**************************************
  * Internal Transfer and Receive Methods
  **************************************/
  
  function transferNFTP(
    address _to, uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId
  ) internal {
    // get the pseudo address of the nftp from the composable owner, nftp contract and nftp tokenId
    address nftp = _nftpAddress(_tokenId, _nftpContract, _nftpTokenId);
    //require that the nftp is owned
    require(nftpOwned[nftp] == true);
    //require that the nftp was transfered safely to it's destination
    require(
      _nftpContract.call(
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
        this, _to, _nftpTokenId
      )
    );
    // remove the parent token's ownership of the child token
    nftpOwned[nftp] = false;
    // remove the nftp contract and index
    _removeContract(_tokenId, _nftpContract);
    // _nftpOwner is _tokenId and _nftpContract pseudo address
    address nftpOwner = _nftpOwner(_tokenId, _nftpContract);
    _removeNFTP(nftpOwner, _nftpTokenId);
    
    emit TransferNFTP(this, _to, _nftpTokenId);
  }
  
  function nftpReceived(address _from, uint256 _nftpTokenId, bytes _data) internal {
    // convert _data bytes to uint256, owner nft tokenId passed as string in bytes
    // bytesToUint(_data) i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 _tokenId = ERC998Helpers.bytesToUint(_data);
    // log the nftp contract and index
    nftpContractIndex[_tokenId][_from] = nftpContracts[_tokenId].length;
    nftpContracts[_tokenId].push(_from);
    // log the tokenId and index
    address nftpOwner = _nftpOwner(_tokenId, _from);
    nftpTokenIndex[nftpOwner][_nftpTokenId] = nftpTokens[nftpOwner].length;
    nftpTokens[nftpOwner].push(_nftpTokenId);
    // set bool of owned to true
    nftpOwned[_nftpAddress(_tokenId, _from, _nftpTokenId)] = true;
    // emit event
    emit Added(_tokenId, _from, _nftpTokenId);
  }
  
  /**************************************
  * Public View Functions (wallet integration)
  **************************************/
  
  // returns the nftp contracts owned by a composable
  function nftpContractsOwnedBy(uint256 _tokenId) public view returns (address[]) {
    return nftpContracts[_tokenId];
  }
  
  // returns the nftps owned by the composable for a specific nftp contract
  function nftpsOwnedBy(uint256 _tokenId, address _nftpContract) public view returns (uint256[]) {
    return nftpTokens[_nftpOwner(_tokenId, _nftpContract)];
  }
  
  // check if nftp is owned by this composable
  function nftpIsOwned(
    uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId
  ) public view returns (bool) {
    return nftpOwned[_nftpAddress(_tokenId, _nftpContract, _nftpTokenId)];
  }
  
  /**************************************
  * Public Transfer and Receive Functions
  **************************************/
  
  // sending nftp to account
  // function safeTransferNFTP(
  //   address _to, uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId
  // ) public {
  //   transferNFTP(_to, _tokenId, _nftpContract, _nftpTokenId);
  // }
  
  // sending nftp directly to another composable
  function safeTransferNFTP(
    address _to, uint256 _tokenId, address _nftpContract, uint256 _nftpTokenId, bytes _data
  ) public {
    transferNFTP(_to, _tokenId, _nftpContract, _nftpTokenId);
    nftpReceived(_nftpContract, _nftpTokenId, _data);
  }
  
  // receiving NFT to composable, _data is bytes (string) tokenId
  function onERC721Received(address _from, uint256 _nftpTokenId, bytes _data) public returns(bytes4) {
    nftpReceived(msg.sender, _nftpTokenId, _data);
    return ERC721_RECEIVED;
  }
  
}