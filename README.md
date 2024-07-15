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
#check out
git submodule update --init --recursive
#update foundry to latest
foundryup
#build
forge build
#run test
npx hardhat test
```

### Deploying
```shell
npx hardhat run --network [network] script/deployXXX.js
```

### Upgrading
```shell
npx hardhat run --network [network] script/upgradeXXX.js
```