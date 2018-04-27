

//jshint ignore: start

pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';

contract Composable is ERC721Token, ERC721Receiver {
  
  /**************************************
  * ERC-721 Setup Methods for Testing
  **************************************/
  
  //pass through constructor, remove?
  constructor(string _name, string _symbol) public ERC721Token(_name, _symbol) {}
  
  /// wrapper on minting new 721
  function mint721(address _to) public returns (uint256) {
    _mint(_to, allTokens.length + 1);
    return allTokens.length;
  }
  
  function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return(tokenOwner[_tokenId] == _claimant);
  }
  
  function bytesToUint(bytes b) internal pure returns (uint256 result) {
    uint256 i;
    result = 0;
    for (i = 0; i < b.length; i++) {
      uint256 c = uint256(b[i]);
      if (c >= 48 && c <= 57) {
        result = result * 10 + (c - 48);
      }
    }
  }
  
  /**************************************
  * ERC-998 Begin Composable Methods
  **************************************/
  
  /// tokenId of composable, mapped to child contract address
  /// child contract address mapped to child tokenId or amount
  mapping(uint256 => mapping(address => bool)) nonfungiblePossessions;
  mapping(uint256 => mapping(address => uint256)) fungiblePossessions;
  
  function _nonfungibleAddress(
    address _childContract, uint256 _childTokenId
  ) internal pure returns (address) {
    return address(keccak256(_childContract, _childTokenId));
  }
  
  /**************************************
  * ERC-721 Non-Fungible Possessions
  **************************************/
  
  //adding nonfungible possessions
  //receives _data which determines which NFT composable of this contract the possession will belong to
  function onERC721Received(address _from, uint256 _tokenId, bytes _data) public returns(bytes4) {
    //convert _data bytes to uint256, assuming tokens were passed in as string data
    // i.e. tokenId = 5 would be "5" coming from web3 or another contract
    uint256 id = bytesToUint(_data);
    nonfungiblePossessions[id][_nonfungibleAddress(msg.sender, _tokenId)] = true;
    return ERC721_RECEIVED;
  }
  
  //transfer the ERC-721
  function transferChild(
    address _to,
    uint256 _tokenId,
    address _childContract,
    uint256 _childTokenId
  ) public {
    // require ownership of parent token &&
    // check parent token owns the child token
    // use the 'pseudo address' for the specific child tokenId
    address childToken = _nonfungibleAddress(_childContract, _childTokenId);
    require(_owns(msg.sender, _tokenId));
    require(nonfungiblePossessions[_tokenId][childToken] == true);
    require(
      _childContract.call(
        // if true, transfer the child token
        // not a delegate call, the child token is owned by this contract
        bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
        this, _to, _childTokenId
      )
    );
    // remove the parent token's ownership of the child token
    nonfungiblePossessions[_tokenId][childToken] = false;
  }
  
  
  
  // /// add ERC-20 children by amount
  // /// requires owner to approve transfer from this contract
  // /// call _childContract.approve(this, _amount)
  // function addChildAmount(
  //   uint256 _tokenId,
  //   address _childContract,
  //   uint256 _amount
  // ) public {
  //   // call the transfer function of the child contract
  //   // if approve was called with the address of this contract
  //   // _amount of child tokens will be transferred to the contract
  //   require(
  //     _childContract.call(
  //       bytes4(keccak256("transferFrom(address,address,uint256)")),
  //       msg.sender, this, _amount
  //     )
  //   );
  //   // if successful, add children to the mapping
  //   children[_tokenId][_childContract] += _amount;
  // }
  
  
  // /// transfer ERC-20 child by _amount
  // function transferChildAmount(
  //   address _to,
  //   uint256 _tokenId,
  //   address _childContract,
  //   uint256 _amount
  // ) public {
  //   // require ownership of parent token &&
  //   // check parent token owns enough balance of the child tokens
  //   require(_owns(msg.sender, _tokenId));
  //   require(children[_tokenId][_childContract] == _amount);
  //   require(
  //     _childContract.call(
  //       // if true, transfer the child tokens
  //       // not a delegate call, the child tokens are owned by this contract
  //       bytes4(keccak256("transfer(address,uint256)")),
  //       _to, _amount
  //     )
  //   );
  //   //decrement the parent token's balance of child tokens by _amount
  //   children[_tokenId][_childContract] -= _amount;
  // }
  
}