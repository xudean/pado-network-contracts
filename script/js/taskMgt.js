const {ethers, upgrades} = require("hardhat");
const feeMgtAbi= require("../../abis/TaskMgt.json");
const {randomBytes} = require('crypto');
const privateKey = process.env.PRIVATE_KEY;
console.log(`privateKey:${privateKey}`)
const wallet = new ethers.Wallet(privateKey);

const provider = new ethers.JsonRpcProvider('https://eth-holesky.g.alchemy.com/v2/63xm51Uk6Vj9Z9HRNOBPXAmY_jN0fRlf'); //
// const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com'); // 
const signer = wallet.connect(provider);

//https://github.com/Eoracle/eoracle-middleware/tree/develop/src
const contractAddress = process.env.TASK_MGT_ADDRESS;
const contract = new ethers.Contract(contractAddress, feeMgtAbi, signer);

async function callContractFunction() {
    //
    if (!contractAddress) {
        throw new Error('contractAddress is null');
    }
    const task = await contract.getCompletedTaskById('0x986c754145a7621b7fabb66cdef12c96e83bec2121f2fa34e16f78e106ab9863')
    console.log(`result is: ${task[6][3]}`)
}

callContractFunction();

