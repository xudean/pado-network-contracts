const {ethers, upgrades} = require("hardhat");
const {workerAbi} = require("./abi/workerAbi.js");
const {randomBytes} = require('crypto');

const privateKey = process.env.PRIVATE_KEY;
console.log(`privateKey:${privateKey}`)
const wallet = new ethers.Wallet(privateKey);

const provider = new ethers.JsonRpcProvider('https://eth-holesky.g.alchemy.com/v2/63xm51Uk6Vj9Z9HRNOBPXAmY_jN0fRlf'); //
// const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com'); // 
const signer = wallet.connect(provider);

//https://github.com/Eoracle/eoracle-middleware/tree/develop/src
const contractAddress = process.env.WORKER_MGT_ADDRESS;
const contract = new ethers.Contract(contractAddress, workerAbi, signer);

async function callContractFunction() {
    //
    if (!contractAddress) {
        throw new Error('contractAddress is null');
    }
    // let tx = await contract.addWhiteListItem('0x17b0f76da804f6aab3a4ca8448040a4d78e1a719');
    // await tx.wait();
    //
    // tx = await contract.addWhiteListItem('0x82da30e2ab471c8d2e6af2c7c6e25f19d80436b2');
    // await tx.wait();
    // //
    // tx = await contract.addWhiteListItem('0x48f760bd0678daaf51a9417ca68edb210eb50104');
    // await tx.wait();
    //
    // tx = await contract.addWhiteListItem('0x5dc2c8c703b0860731bba000af353890d3e36e6b');
    // await tx.wait();
    // const tx = await contract.workerWhiteList('0x82da30e2ab471c8d2e6af2c7c6e25f19d80436b2');
    // console.log(tx)

    const tx = await contract.getWorkers();
    console.log(tx.length)
    console.log(tx)
    for (let i = 0; i < tx.length; i++) {
        const detail = tx[i]
        const txStr = arseedingHexStrToBase64(detail[6])
        console.log(`${detail[5]}`)
        // console.log(`address:${detail[5]}, tx:${txStr}`)
        // console.log(`https://arseed.web3infra.dev/${txStr}`)
    }

    // console.log(tx)
    // await getAdmin()
    // for(var i=0;i<5;i++){
    //     await selectWorker();
    // // }
    // await getNonce()

    // const ramdom = generateRandomBytes32();
    // console.log(`ramdom:${ramdom}`)
    // const tx2 = await contract.checkWorkerRegistered(ramdom);
    // console.log(tx2)
    // const address = contract.implementation();
    // console.log(`implementation is :{}`,address)
}
const arseedingHexStrToBase64 = (hexStr) => {
    hexStr = hexStr.startsWith('0x') ? hexStr.slice(2) : hexStr;

    const byteArray = new Uint8Array(hexStr.length / 2);
    for (let i = 0; i < hexStr.length; i += 2) {
        byteArray[i / 2] = parseInt(hexStr.slice(i, i + 2), 16);
    }
    const decoder = new TextDecoder();
    return decoder.decode(byteArray);
};
function getWorkerIds() {
    return contract.getWorkerIds();
}

function generateRandomBytes32() {
    return '0x' + randomBytes(32).toString('hex');
}

async function getNonce() {
    const nonce = await contract.getNonce();
    console.log(nonce);
}

async function selectWorker() {
    const res = await contract.selectWorkers(3);
    const recipent = await res.wait();
    const event = recipent.events.find((event) => event.event === 'SelectWorkers');
    console.log(`random:${event.args.ramdom}, workerIds:${event.args.workerIds}`)
}

async function getAdmin() {
    const events = await contract.queryFilter('AdminChanged');
    events.forEach(event => {
        console.log(`Admin changed from ${event.args.oldAdmin} to ${event.args.newAdmin}`);
    });
}

callContractFunction();

