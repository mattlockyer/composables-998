

//jshint ignore: start

pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';

contract Composable is ERC721Token, ERC721Receiver {

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
  
  /**************************************
  * Helper Methods (move to library or add library)
  **************************************/
  
  function bytesToUint(bytes b) internal pure returns (uint256 result) {
    result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      uint256 c = uint256(b[i]);
      if (c >= 48 && c <= 57) {
        result = result * 10 + (c - 48);
      }
    }
  }

  /**************************************
   * ERC-998 Begin Composable Methods
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
  
  // generates a pseudo-address from the nft that owns, nftp contract
  function _nftpOwner(
    uint256 _tokenId,
    address _nftpContract
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _nftpContract));
  }
  
  // generates a pseudo-address for the nftp from the nft that owns, nftp contract, nftp tokenId
  function _nftpAddress(
    uint256 _tokenId,
    address _nftpContract,
    uint256 _nftpTokenId
  ) internal pure returns (address) {
    return address(keccak256(_tokenId, _nftpContract, _nftpTokenId));
  }
  
  function nftpContractsOwnedBy(uint256 _tokenId) public view returns (address[]) {
    return nftpContracts[_tokenId];
  }
  
  function nftpsOwnedBy(uint256 _tokenId, address _nftpContract) public view returns (uint256[]) {
    return nftpTokens[_nftpOwner(_tokenId, _nftpContract)];
  }
  
  /**************************************
  * ERC-721 Non-Fungible Possessions
  **************************************/
  
  // adding nonfungible possessions
  // receives _data which determines which NFT composable of this contract the possession will belong to
  function onERC721Received(address _from, uint256 _tokenId, bytes _data) public returns(bytes4) {
    // convert _data bytes to uint256, owner nft tokenId passed as string in bytes
    // bytesToUint(_data)
    // i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 ownerTokenId = bytesToUint(_data);
    // log the nftp contract and index
    nftpContractIndex[ownerTokenId][msg.sender] = nftpContracts[ownerTokenId].length;
    nftpContracts[ownerTokenId].push(msg.sender);
    // log the tokenId and index
    address nftpOwner = _nftpOwner(ownerTokenId, msg.sender);
    nftpTokenIndex[nftpOwner][_tokenId] = nftpTokens[nftpOwner].length;
    nftpTokens[nftpOwner].push(_tokenId);
    // set bool of owned to true
    nftpOwned[_nftpAddress(ownerTokenId, msg.sender, _tokenId)] = true;
    // return safely from callback of nft
    return ERC721_RECEIVED;
  }
  
  //transfer the ERC-721
  function transferNFTP(
    address _to,
    uint256 _tokenId,
    address _nftpContract,
    uint256 _nftpTokenId
  ) public {
    // require ownership of parent token &&
    // check parent token owns the child token
    // use the 'pseudo address' for the specific child tokenId
    address nftp = _nftpAddress(_tokenId, _nftpContract, _nftpTokenId);
    
    // require
    require(_owns(msg.sender, _tokenId));
    require(nftpOwned[nftp] == true);
    require(
      _nftpContract.call(
        // if true, transfer the child token
        // not a delegate call, the child token is owned by this contract
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
        this, _to, _nftpTokenId
      )
    );
    // remove the parent token's ownership of the child token
    nftpOwned[nftp] = false;
    
    // remove the nftp contract and index
    uint256 contractIndex = nftpContractIndex[_tokenId][_nftpContract];
    uint256 lastContractIndex = nftpContracts[_tokenId].length.sub(1);
    address lastContract = nftpContracts[_tokenId][lastContractIndex];
    nftpContracts[_tokenId][contractIndex] = lastContract;
    nftpContracts[_tokenId][lastContractIndex] = 0;
    nftpContracts[_tokenId].length--;
    nftpContractIndex[_tokenId][_nftpContract] = 0;
    nftpContractIndex[_tokenId][lastContract] = contractIndex;
    
    // _nftpOwner is _tokenId and _nftpContract pseudo address
    address nftpOwner = _nftpOwner(_tokenId, _nftpContract);
    // remove the nftp token and index
    uint256 tokenIndex = nftpTokenIndex[nftpOwner][_nftpTokenId];
    uint256 lastTokenIndex = nftpTokens[nftpOwner].length.sub(1);
    uint256 lastToken = nftpTokens[nftpOwner][lastTokenIndex];
    nftpTokens[nftpOwner][tokenIndex] = lastToken;
    nftpTokens[nftpOwner][lastTokenIndex] = 0;
    nftpTokens[nftpOwner].length--;
    nftpTokenIndex[nftpOwner][_nftpTokenId] = 0;
    nftpTokenIndex[nftpOwner][lastToken] = tokenIndex;
    
  }
  
  
}