

//jshint ignore: start

pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract that will work with ERC223 tokens.
*/

contract ERC223Receiver {
  /**
   * @dev Standard ERC223 function that will handle incoming token transfers.
   *
   * @param _from  Token sender address.
   * @param _value Amount of tokens.
   * @param _data  Transaction metadata.
   */
  function tokenFallback(address _from, uint _value, bytes _data) public;
}


contract SampleERC20 is MintableToken {
  function transfer(address _to, uint _value, bytes _data) external {
    uint codeLength;
    assembly {
      codeLength := extcodesize(_to)
    }
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    if(codeLength>0) {
      // Require proper transaction handling.
      ERC223Receiver receiver = ERC223Receiver(_to);
      receiver.tokenFallback(msg.sender, _value, _data);
    }
  }
/*
  function tokenFallback(address _from, uint _value, bytes _data) external {
    require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the token to.");
    // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
    uint256 tokenId;
    assembly {
      tokenId := calldataload(132)
    }
    if(_data.length < 32) {
      tokenId = tokenId >> 256 - _data.length * 8;
    }

    receiveChild(_from, tokenId, msg.sender, _childTokenId);
  }
*/
}