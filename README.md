# pado-network-contracts
## Quick Start

### Dependencies

1. [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
2. [Foundry](https://getfoundry.sh/)

### Install
```shell
npm install
```

### Building and Running Tests
```shell
foundryup

forge build
forge test
```

### Deploying
```shell
npx hardhat run --network [network] scripts/deployXXX.js
```

### Upgrading
```shell
npx hardhat run --network [network] scripts/upgradeXXX.js
```