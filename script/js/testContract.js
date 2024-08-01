const {ethers, upgrades} = require("hardhat");
const {testContractAbi} = require("./abi/testContractAbi.js");

const privateKey = process.env.PRIVATE_KEY; //
const wallet = new ethers.Wallet(privateKey);

const provider = new ethers.JsonRpcProvider('https://rpc-holesky.rockx.com'); //  URL
// const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com'); //  URL


async function callContractFunction() {
    const signer = await wallet.connect(provider);
//https://github.com/Eoracle/eoracle-middleware/tree/develop/src
    const contractAddress = '0x4197d6270534b95848566478479dF0E9AfD190CA';
    const contract = new ethers.Contract(contractAddress, testContractAbi, signer);
    const tx2 = await contract.transferToken({value: ethers.parseEther("0.0001")});
    await tx2.wait()
    console.log(tx2)
}
callContractFunction();

