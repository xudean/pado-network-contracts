const { ethers, upgrades } = require("hardhat");
const {registryCoordinatorAbi} = require("./abi/registryCoordinatorAbi");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = process.env.REGISTRY_COORDINATOR_ADDRESS;
if(!contractAddress){
    throw new Error('REGISTRY_COORDINATOR_ADDRESS is empty!')
}

// Create a contract instance
const contract = new ethers.Contract(contractAddress, registryCoordinatorAbi, wallet);

async function call() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)
        const owner = await contract.owner()
        console.log(`owner is: ${owner}`);
        await updateOperators();
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}


async function updateOperators(){
    // Send a transaction to the createNewTask function
    const operators = ['0x48f760bd0678daaf51a9417ca68edb210eb50104']
    const tx = await contract.updateOperators(operators);
    await tx.wait();
    console.log(`tx: ${tx}`);
}


// call command
// npx hardhat run --network holesky script/js/registryCoordinator.js
call();