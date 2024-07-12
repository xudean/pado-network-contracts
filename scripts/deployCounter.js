const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
  "Deploying contracts with the account:",
  deployer.address
  );
  console.log("Deploying Counter...");
  const counterContract = await ethers.getContractFactory("Counter");

  const proxy = await upgrades.deployProxy(counterContract);
  await proxy.waitForDeployment();
  const counterProxyAddress = await proxy.getAddress();
  const counterImplementationAddress = await upgrades.erc1967.getImplementationAddress(counterProxyAddress);
  const adminAddress = await upgrades.erc1967.getAdminAddress(counterProxyAddress);

  console.log(`Proxy is at ${counterProxyAddress}`);
  console.log(`Implementation is at ${counterImplementationAddress}`);
  console.log(`adminAddress is at ${adminAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
