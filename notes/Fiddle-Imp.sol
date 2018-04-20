

//jshint ignore:start

//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.18;

contract ERC721 {
  function ownerOf(uint256) public returns (address);
}

contract ComposableAssetFactory {
  
  // which asset owns which other assets at which address
  mapping(uint256 => mapping(address => uint256)) children;

  // which address owns which tokens
  mapping(uint256 => address) owners;
  
  modifier onlyOwner(uint256 _tokenID) {
    require(msg.sender == owners[_tokenID]);
    _;
  }
  function registerOwner(uint256 _tokenID, address _contract) public returns (bool) {
    require(owners[_tokenID] == address(0));

    ERC721 erc721 = ERC721(_contract);

    address owner = erc721.ownerOf(_tokenID);
    assert(owner == msg.sender);

    owners[_tokenID] = msg.sender;
    return true;
  }
  // change owner of a token
  function changeOwner(address _newOwner, uint256 _tokenID) onlyOwner(_tokenID) public returns (bool) {
    owners[_tokenID] = _newOwner;
    return true;
  }
  
  // add erc20 child to a composable asset
  function addFungibleChild(uint256 _tokenID, address _childContract, uint256 _amount) onlyOwner(_tokenID) public returns (bool) {
    require(
      _childContract.call(
        bytes4(keccak256("transferFrom(address,address,uint256")),
        msg.sender,
        this,
        _amount
      )
    );

    // set as child
    children[_tokenID][_childContract] += _amount;
    return true;
  }

  // add erc721 child to a composable asset
  function addNonFungibleChild(uint256 _tokenID, address _childContract, uint256 _index) onlyOwner(_tokenID) public returns (bool) {
    require(
      _childContract.call(
        bytes4(keccak256("transferFrom(address,address,uint256")),
        msg.sender,
        this,
        _index
      )
    );

    // set as child
    children[_tokenID][_childContract] = _index;
    return true;
  }

  function transferNonFungibleChild(
    address _to,
    uint256 _tokenID,
    address _childContract,
    uint256 _childTokenID
  ) public onlyOwner(_tokenID) returns (bool) {
    require(children[_tokenID][_childContract] == _childTokenID);
    require(
      _childContract.call(
        bytes4(keccak256("transfer(address,uint256)")),
        _to, _childTokenID
      )
    );

    children[_tokenID][_childContract] = 0;
    return true;
  }

  function transferFungibleChild(
    address _to,
    uint256 _tokenID,
    address _childContract,
    uint256 _amount
  ) onlyOwner(_tokenID) public {
    require(children[_tokenID][_childContract] >= _amount);
    require(
      _childContract.call(
        bytes4(keccak256("transfer(address,uint256)")),
        _to, _amount
      )
    );

    children[_tokenID][_childContract] -= _amount;
  }

}