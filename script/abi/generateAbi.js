const fs = require('fs');
const {join} = require("node:path");

// readfile
function readFileSync(filename) {
    try {
        return fs.readFileSync(filename, 'utf8');
    } catch (err) {
        throw new Error(err);
    }
}

function listFiles(dirPath, files = []) {
    fs.readdirSync(dirPath).forEach((file) => {
        const filePath = join(dirPath, file);
        const stat = fs.statSync(filePath);

        if (!stat.isDirectory()) {
            files.push(file);
        }
    });

    return files;
}

// call
function generateAbi() {
    //contracts
    const files = listFiles('./contracts');
    for (let i = 0; i < files.length; i++) {
        const contractOutputName = files[i].replace('.sol', '.json')
        const content = readFileSync('out/'+files[i]+'/'+contractOutputName);
        const abiJson = JSON.parse(content)
        fs.writeFileSync('abis/'+contractOutputName, JSON.stringify(abiJson.abi));
    }
    console.log('generate abis success!')

}

generateAbi();
