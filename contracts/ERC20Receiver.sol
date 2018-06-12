

//jshint ignore: start

pragma solidity ^0.4.21;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 *  from ERC721 asset contracts.
 */
contract ERC20Receiver {
  /**
   * @dev Magic value to be returned upon successful reception of an NFT
   *  Equals to `bytes4(keccak256("onERC20Received(address,uint256,bytes)"))`,
   *  which can be also obtained as `ERC20Receiver(0).onERC20Received.selector`
   */
  bytes4 constant ERC20_RECEIVED = 0x65d83056;

  function onERC20Received(address _from, uint256 _value, bytes _data) public returns(bytes4);
}
