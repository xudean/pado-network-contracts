const { ethers, upgrades } = require("hardhat");
const {serviceManagerAbi} = require("./abi/serviceManager");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = '0x62169cb4D43df7F9c52b49ee07D70Ce007c6c291';

// Create a contract instance
const contract = new ethers.Contract(contractAddress, serviceManagerAbi, wallet);

async function call() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)
        const owner = await contract.owner()
        console.log(`owner is: ${owner}`);
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}

// call
call();