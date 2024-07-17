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
#### Using forge
```shell
forge script script/deploy/holesky/Holesky_DeployPADONetworkContracts.s.sol:Holesky_DeployPADONetworkContracts --rpc-url [rpc-url] --private-key [private-key] --broadcast
```

### Upgrading
#### Using forge
Filling right addresses in [eigenlayer_upgrade_holesky.json](./script/deploy/holesky/config/eigenlayer_upgrade_holesky.json)
```shell
forge script script/deploy/holesky/Holesky_UpgradePADONetworkContracts.s.sol:Holesky_UpgradePADONetworkContracts --rpc-url [rpc-url]  --private-key [private-key] --broadcast
```