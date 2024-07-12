const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
  "Upgrade contracts with the account:",
  deployer.address
  );
  console.log("Upgrade Counter...");
  const counterContract = await ethers.getContractFactory("Counter");
  const proxyContractAddress = '0xbcce0701BF07A4d0462Ab82552Dd1A8608ca368d';
  const proxy = await upgrades.upgradeProxy(proxyContractAddress,counterContract);


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
