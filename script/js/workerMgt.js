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
    // const tx1 = await contract.addWhiteListItem('0xc511461589b3295f492fa594f55f7dc26ef4e113');
    // await tx1.wait();
    // const tx2 = await contract.workerWhiteList('0xc511461589b3295f492fa594f55f7dc26ef4e113');
    // console.log(tx2)

    const tx = await contract.getWorkers();
    console.log(tx.length)
    console.log(tx)
    for (let i = 0; i < tx.length; i++) {
        const detail = tx[i]
        // const txStr = arseedingHexStrToBase64(detail[6])
        // console.log(`${detail[5]}`)
        //0x3e31908E30B3051dFe056B1D0902B164D78Cd8b8
        //0x5ACCC90436492F24E6aF278569691e2c942A676d
        //0x17b0F76Da804F6aab3a4Ca8448040a4d78e1A719
        console.log(`address:${detail[5]}, workerId:${detail[0]}`)
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

    // const data = {
    //     "0x690eb1626395c9e32975a7a6ffd75acf7cfbbc0aceb09b78bda65574902173c9": 1,
    //     "0xeacd52ac5f8163b5f12d63406f8eb5fc6e79c24ecdc5470893f00f9007f07415": 8,
    //     "0x8b332753e1bbb68307f40f89e785a537e128b1c03d7faec0c46759f4dc2856da": 16,
    //     "0x475ca3b08b5861bb0f8e49ebc14775847cf531c6c16a1473d4610d6f609f179c": 27,
    //     "0xb1d05b3f6784145006ca2754584250de45ceba6c2d61eaa51977fb36fd01bbfa": 16,
    //     "0x0704d41781a752eb5e0efd59a4ead51fffc2586ac7f89bd12b2a5a8a7277b250": 12,
    //     "0x4a2e98e2323f0667679ef60029ada8a34501f4bada0954cdf146b924a3f50ca3": 17,
    //     "0xa948c921bde891048177e7f0c0a849cc8dd6d2bf03eb29a3e91011c8047cdda4": 23,
    //     "0x1b0b9f30d97b432a992d8c22f088eac9976fbc10641524ee61d461f0287fedfa": 4
    // }
    // for (let dataKey in data) {
    //     const worker = await contract.getWorkerById(dataKey)
    //     console.log(`${worker[5]}:${data[dataKey]}`)
    // }
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

