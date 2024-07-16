const { ethers, upgrades } = require("hardhat");
const {serviceManagerAbi} = require("./abi/serviceManager");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = process.env.CONTRACT_ADDRESS;
if(!contractAddress){
    throw new Error('CONTRACT_ADDRESS is empty!')
}

// Create a contract instance
const contract = new ethers.Contract(contractAddress, serviceManagerAbi, wallet);

async function owner() {
    try {
        const owner = await contract.owner()
        console.log(`owner is: ${owner}`);
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}


async function callGetRestakeableStrategies() {
    try {
        const strategy = await contract.getRestakeableStrategies()
        console.log(`strategies size is: ${strategy.length}`);
        console.log(`strategies is: ${strategy}`);
        return strategy;
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}

async function callUpdateMetaUri() {
    const metaUri = process.env.AVS_META_URI;
    if(!metaUri){
        throw new Error('AVS_META_URI is empty!')
    }
    // Send a transaction to the createNewTask function
    const tx = await contract.updateAVSMetadataURI(metaUri);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();

    console.log(`updateMetaUri successfully ,tx hash: ${receipt.transactionHash}`);
}



async  function call(){
    const caller = await wallet.getAddress()
    console.log(`caller is:${caller}`);
    await owner();
    await callGetRestakeableStrategies();
    // await callUpdateMetaUri();
}

// call
call();