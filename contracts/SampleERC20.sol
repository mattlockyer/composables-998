

//jshint ignore: start

pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "zeppelin-solidity/contracts/AddressUtils.sol";
import "./ERC20Receiver.sol";

contract SampleERC20 is MintableToken {
  bytes4 constant ERC20_RECEIVED = 0x65d83056;
  
  function safeTransferFromERC20(address _from, address _to, uint256 _value, bytes _data) public returns (bool success) {
    transferFrom(_from, _to, _value);
    require(checkAndCallSafeTransferERC20(_from, _to, _value, _data));
    return true;
  }
  
  function checkAndCallSafeTransferERC20(address _from, address _to, uint256 _value, bytes _data) internal returns (bool) {
    // if (!_to.isContract()) {
    //   return true;
    // }
    bytes4 retval = ERC20Receiver(_to).onERC20Received(_from, _value, _data);
    return (retval == ERC20_RECEIVED);
  }

}