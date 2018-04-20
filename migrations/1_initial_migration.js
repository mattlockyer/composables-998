

const Migrations = artifacts.require("./Migrations.sol");
const Composable = artifacts.require("./Composable.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(Composable, "Composable", "COMP");
};
