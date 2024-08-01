const {ethers, upgrades} = require("hardhat");
const {testContractReceiverAbi} = require("./abi/testContractReceiverAbi.js");

const privateKey = process.env.PRIVATE_KEY; //
const wallet = new ethers.Wallet(privateKey);

const provider = new ethers.JsonRpcProvider('https://rpc-holesky.rockx.com');

// const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com')


async function callContractFunction() {
    const signer = await wallet.connect(provider);
//https://github.com/Eoracle/eoracle-middleware/tree/develop/src
    const contractAddress = '0xC8f176596610c629315db47281eBEbDB0B02778B';
    const contract = new ethers.Contract(contractAddress, testContractReceiverAbi, signer);
    const tx = await contract.getBalance()
    console.log(tx)
}

callContractFunction();

