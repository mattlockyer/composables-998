
//jshint ignore:start

/// tokenId of composable, mapped to child contract address
/// child contract address mapped to child tokenId or amount
mapping(uint256 => mapping(address => uint256)) children;

/**************************************
* Adding Children
**************************************/

/// add ERC-721 children by tokenId
/// @requires owner to approve transfer from this contract
/// call _childContract.approve(this, _childTokenId)
/// where this is the address of the parent token contract
addChild(
  uint256 _tokenId,
  address _childContract,
  uint256 _childTokenId
) {
  // call the transfer function of the child contract
  // if approve was called using the address of this contract
  // _childTokenId will be transferred to this contract
  require(
    _childContract.call(
      bytes4(sha3("transferFrom(address,address,uint256)")),
      msg.sender, this, _childTokenId
    )
  );
  // if successful, add children to the mapping
  children[_tokenId][_childContract] = _childTokenId;
}

/// add ERC-20 children by amount
/// @requires owner to approve transfer from this contract
/// call _childContract.approve(this, _amount)
addChildAmount(
  uint256 _tokenId,
  address _childContract,
  uint256 _amount
) {
  // call the transfer function of the child contract
  // if approve was called with the address of this contract
  // _amount of child tokens will be transferred to the contract
  require(
    _childContract.call(
      bytes4(sha3("transferFrom(address,address,uint256)")),
      msg.sender, this, _amount
    )
  );
  // if successful, add children to the mapping
  children[_tokenId][_childContract] += _amount;
}

/**************************************
* Transferring Children
**************************************/

/// transfer ERC-721 child by _childTokenId
transferChild(
  address _to,
  uint256 _tokenId,
  address _childContract,
  uint256 _childTokenId
) {
  // require ownership of parent token &&
  // check parent token owns the child token
  // use the 'pseudo address' for the specific child tokenId
  address childToken = address(keccak256(_childContract, _childTokenId));
  require(_owns(msg.sender, _tokenId));
  require(children[_tokenId][childToken] == 1);
  require(
    _childContract.call(
      // if true, transfer the child token
      // not a delegate call, the child token is owned by this contract
      bytes4(sha3("transfer(address,uint256)")), _to, _childTokenId
    )
  );
  // remove the parent token's ownership of the child token
  children[_tokenId][childToken] = 0;
}

/// transfer ERC-20 child by _amount
transferChildAmount(
  address _to,
  uint256 _tokenId,
  address _childContract,
  uint256 _amount
) {
  // require ownership of parent token &&
  // check parent token owns enough balance of the child tokens
  require(_owns(msg.sender, _tokenId));
  require(children[_tokenId][_childContract] == _amount);
  require(
    _childContract.call(
      // if true, transfer the child tokens
      // not a delegate call, the child tokens are owned by this contract
      bytes4(sha3("transfer(address,uint256)")),
      _to, _amount
    )
  );
  //decrement the parent token's balance of child tokens by _amount
  children[_tokenId][_childContract] -= _amount;
}