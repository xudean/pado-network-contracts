const { ethers, upgrades } = require("hardhat");
const {counterAbi} = require("./abi/counterAbi");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = '0x32839Da39Cb94B312e8e5fF9Ae1eCdDd7AE8Db23';

// Create a contract instance
const contract = new ethers.Contract(contractAddress, counterAbi, wallet);

async function update() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)
        // Send a transaction to the createNewTask function
        const tx = await contract.setNumber2(1);

        // Wait for the transaction to be mined
        const receipt = await tx.wait();
        console.log('setNumber success!')
        const number = await contract.getNumber2()
        console.log(`number: ${number}`);
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}

// Function to create a new task with a random name every 15 seconds
async function startCreatingTasks() {
    await update()
}

// Start the process
startCreatingTasks();