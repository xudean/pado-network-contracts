require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require("@openzeppelin/hardhat-upgrades");
require('dotenv').config();
/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
    solidity:
        {
            compilers: [
                {
                    version: "0.8.19"
                },
                {
                    version: "0.8.20",
                }
            ]
        },
    networks: {
        holesky: {
            url: `${process.env.RPC_URL}`,
            accounts: [`${process.env.PRIVATE_KEY}`]
        }
    }
};
