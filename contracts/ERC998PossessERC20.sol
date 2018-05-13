

//jshint ignore: start

pragma solidity ^0.4.21;

import "./ERC20Receiver.sol";

contract ERC998PossessERC20 is ERC20Receiver {

  /**************************************
   * Helper Methods (move to library or add library)
   **************************************/

  function bytesToUint(bytes b) internal pure returns(uint256 result) {
    result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      uint256 c = uint256(b[i]);
      if (c >= 48 && c <= 57) {
        result = result * 10 + (c - 48);
      }
    }
  }

  /**************************************
   * ERC998PossessERC20 Begin
   **************************************/

  // mapping from nft to all ftp contracts
  mapping(uint256 => address[]) ftpContracts;

  // mapping for the ftp contract index
  mapping(uint256 => mapping(address => uint256)) ftpContractIndex;

  // mapping from contract pseudo-address owner ftp to the tokenIds
  mapping(address => uint256) ftpBalances;

  /**************************************
   * Public View Functions (wallet integration)
   **************************************/

  // returns the ftp contracts owned by a composable
  function ftpContractsOwnedBy(uint256 _tokenId) public view returns(address[]) {
    return ftpContracts[_tokenId];
  }

  // returns the ftps owned by the composable for a specific ftp contract
  function ftpBalanceOf(uint256 _tokenId, address _ftpContract) public view returns(uint256) {
    return ftpBalances[_ftpAddress(_tokenId, _ftpContract)];
  }
  
  /**************************************
  * Utility Methods
  **************************************/
  
  // generates a pseudo-address from the nft that owns, ftp contract
  function _ftpAddress(uint256 _tokenId, address _ftpContract) internal pure returns(address) {
    return address(keccak256(_tokenId, _ftpContract));
  }
  
  function _ftpRemoveContract(uint256 _tokenId, address _ftpContract) internal {
    uint256 contractIndex = ftpContractIndex[_tokenId][_ftpContract];
    uint256 lastContractIndex = ftpContracts[_tokenId].length - 1;
    address lastContract = ftpContracts[_tokenId][lastContractIndex];
    ftpContracts[_tokenId][contractIndex] = lastContract;
    ftpContracts[_tokenId][lastContractIndex] = 0;
    ftpContracts[_tokenId].length--;
    ftpContractIndex[_tokenId][_ftpContract] = 0;
    ftpContractIndex[_tokenId][lastContract] = contractIndex;
  }
  
  /**************************************
  * Internal Transfer and Receive FTPs (ERC20s)
  **************************************/
  function transferFTP(
    address _to, uint256 _tokenId, address _ftpContract, uint256 _value
  ) internal {
    address ftp = _ftpAddress(_tokenId, _ftpContract);
    //require that the ftp balance is enough
    require(ftpBalances[ftp] >= _value);
    //require that the ftp value was transfered
    require(
      _ftpContract.call(bytes4(keccak256("transfer(address,uint256)")), _to, _value)
    );
    ftpBalances[ftp] -= _value;
    // remove the ftp contract and index
    _ftpRemoveContract(_tokenId, _ftpContract);
  }
  
  function ftpReceived(address _from, uint256 _value, bytes _data) internal {
    // convert _data bytes to uint256, owner nft tokenId passed as string in bytes
    // bytesToUint(_data) i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 _tokenId = bytesToUint(_data);
    // log the ftp contract and index
    ftpContractIndex[_tokenId][_from] = ftpContracts[_tokenId].length;
    ftpContracts[_tokenId].push(_from);
    // update balances
    ftpBalances[_ftpAddress(_tokenId, _from)] = _value;
  }
  
  /**************************************
  * Public Transfer and Receive Methods
  **************************************/
  
  function safeTransferFTP(
    address _to, uint256 _tokenId, address _ftpContract, uint256 _value, bytes _data
  ) public {
    transferFTP(_to, _tokenId, _ftpContract, _value);
    ftpReceived(_ftpContract, _value, _data);
  }
  
  
  function onERC20Received(address _from, uint256 _value, bytes _data) public returns(bytes4) {
    ftpReceived(msg.sender, _value, _data);
    return ERC20_RECEIVED;
  }
  
}