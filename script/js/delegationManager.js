const {ethers} = require("hardhat");
const {delegationManagerAbi} = require("./abi/delegationManagerAbi");
const {holeskyFullStrategies} = require("./config/strategies");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = process.env.DELEGATION_MANAGER_ADDRESS;
if (!contractAddress) {
    throw new Error('DELEGATION_MANAGER_ADDRESS is empty!')
}

// Create a contract instance
const contract = new ethers.Contract(contractAddress, delegationManagerAbi, wallet);

async function call() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)
        
        const operator1 = "0x48f760bd0678daaf51a9417ca68edb210eb50104";
        const operator2 = "0x024e45d7f868c41f3723b13fd7ae03aa5a181362";
        const stEth = "0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3";
        const share = await getOperatorShares(operator1, [stEth]);
        console.log("share = ", share);
        const share2 = await getOperatorShares(operator2, [stEth]);
        console.log("share2 = ", share2);
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}

async function getOperatorShares(operator, strategies) {
    const res = await contract.getOperatorShares(operator, strategies);
    return res;
}

// call command
// npx hardhat run --network holesky script/js/delegationManager.js
call();