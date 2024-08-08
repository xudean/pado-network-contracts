const {ethers} = require("hardhat");
const {dataMgtAbi} = require("./abi/dataMgtAbi");

// Connect to the Ethereum network
const provider = new ethers.JsonRpcProvider(`https://rpc-holesky.rockx.com`);

// Replace with your own private key (ensure this is kept secret in real applications)
const privateKey = process.env.PRIVATE_KEY;
const wallet = new ethers.Wallet(privateKey, provider);

// Replace with the address of your smart contract
const contractAddress = process.env.DataMgt_ADDRESS;
if (!contractAddress) {
    throw new Error('DataMgt_ADDRESS is empty!')
}

// Create a contract instance
const contract = new ethers.Contract(contractAddress, dataMgtAbi, wallet);

async function call() {
    try {
        const caller = await wallet.getAddress()
        console.log(`caller is:${caller}`)

        const dataId = "0x5ac5fe808a0ec7369edce6f69b6121b0dc1c3cd198e0ea80c90d992d178a2fd0";
        const dataInfo = await contract.getDataById(dataId);
        console.log("dataInfo=", dataInfo);
    } catch (error) {
        console.error('Error sending transaction:', error);
    }
}

// call command
// npx hardhat run --network holesky script/js/dataMgt.js
call();