

//jshint ignore: start

pragma solidity ^0.4.21;

import "./ERC20Receiver.sol";

contract ERC998PossessERC20 is ERC20Receiver {

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
  * ERC998PossessERC20 Begin
  **************************************/
  
  // mapping from nft to all ftp contracts
  mapping(uint256 => address[]) ftpContracts;
  
  // mapping for the nftp contract index
  mapping(uint256 => mapping(address => uint256)) ftpContractIndex;
  
  // mapping from contract pseudo-address owner nftp to the tokenIds
  mapping(address => uint256) ftpBalance;
  
  /**************************************
  * Receiving ERC20s
  **************************************/
  function onERC20Received(address _from, uint256 _value, bytes _data) public returns(bytes4) {
    return ERC20_RECEIVED;
  }
  
  
  
}