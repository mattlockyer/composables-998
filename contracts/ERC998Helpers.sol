

//jshint ignore: start

pragma solidity ^0.4.21;

library ERC998Helpers {
  
  function bytesToUint(bytes b) internal pure returns (uint256 result) {
    result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      uint256 c = uint256(b[i]);
      if (c >= 48 && c <= 57) {
        result = result * 10 + (c - 48);
      }
    }
  }

}