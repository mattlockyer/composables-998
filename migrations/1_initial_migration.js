

const Migrations = artifacts.require("./Migrations.sol");
const Composable = artifacts.require("./Composable.sol");
const SampleNFT = artifacts.require("./SampleNFT.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(Composable, "Composable", "COMP");
  deployer.deploy(SampleNFT, "SampleNFT", "SNFT");
};
