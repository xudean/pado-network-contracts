const {ethers, upgrades} = require("hardhat");
const {stakeRegistryAbi} = require("./abi/stakeRegistryAbi");
const {holeskyFullStrategies} = require("./config/strategies");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = process.env.STAKE_REGISTRY_ADDRESS;
if (!contractAddress) {
    throw new Error('STAKE_REGISTRY_ADDRESS is empty!')
}

// Create a contract instance
const contract = new ethers.Contract(contractAddress, stakeRegistryAbi, wallet);

async function call() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)
        // const strategy = await getStrategy(0,0)
        // console.log(strategy)
        await addStrategies()
        console.log("addStrategies success!")
        // await removeStrategies(0, [0]);
        // console.log("removeStrategies success!")


        // for(let i = 0; i < 9; i++){
        // // the removal of lower index entries will cause a shift in the indices of the other strategies to remove
        //     const indexes = [3]
        //     const strategy = await getStrategy(0,3)
        //     console.log(`strategy is${strategy},will remove`)
        //     await removeStrategies(0, indexes)
        //     console.log("removeStrategies success!")
        // }
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}


//get strategy by quorumNumber and index
async function getStrategy(quorumNumber, index) {
    const strategy = await contract.strategyParamsByIndex(quorumNumber, index)
    console.log(`strategy[${quorumNumber},${index}] is: ${strategy}`);
    return strategy;
}

//remove strategies
async function removeStrategies(quorumNumber, indexes) {
    const tx = await contract.removeStrategies(quorumNumber, indexes)
    await tx.wait();
}

//add strategies
async function addStrategies() {
    // const tx = await contract.addStrategies(0, [{
    //     strategy:"0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0",
    //     multiplier: 1000
    // }])
    const tx = await contract.addStrategies(0, holeskyFullStrategies)
    await tx.wait();
}

// call
call();