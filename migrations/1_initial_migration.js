

const Migrations = artifacts.require("./Migrations.sol");
const Composable = artifacts.require("./ComposableTopDown.sol");
const SampleNFT = artifacts.require("./SampleNFT.sol");
const SampleERC20 = artifacts.require("./SampleERC20.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  //deployer.deploy(Composable, "ComposableTopDown", "COMPTD", {gas: 8000000});
  deployer.deploy(Composable, "ComposableTopDown", "COMPTD");
  deployer.deploy(SampleNFT, "SampleNFT", "SNFT");
  deployer.deploy(SampleERC20);
};
