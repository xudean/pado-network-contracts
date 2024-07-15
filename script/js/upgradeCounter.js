const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
  "Upgrade contracts with the account:",
  deployer.address
  );
  console.log("Upgrade Counter...");
  const counterContract = await ethers.getContractFactory("Counter");
  const proxyContractAddress = '0x32839Da39Cb94B312e8e5fF9Ae1eCdDd7AE8Db23';
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
