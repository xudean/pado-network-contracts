// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;


import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {Utils} from "../utils/Utils.s.sol";
import "eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";

import {UpgradeContractParser} from "../utils/UpgradeContractParser.sol";
import {RegistryCoordinator, IPauserRegistry} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/src/BLSSignatureChecker.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {RewardsCoordinator} from "../../../lib/eigenlayer-middleware/lib/eigenlayer-contracts/src/contracts/core/RewardsCoordinator.sol";
import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";

import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";

import {ServiceManager} from "../../../contracts/ServiceManager.sol";

//forge script script/deploy/mainnet/Mainnet_UpgradePADONetworkContracts.s.sol:Mainnet_UpgradePADONetworkContracts --rpc-url [rpc_url]  --private-key [private_key] --broadcast
contract Mainnet_UpgradePADONetworkContracts is Utils, UpgradeContractParser {
    string public existingUpgradeInfoPath =
    string(
        bytes(
            "./script/deploy/mainnet/config/eigenlayer_upgrade_mainnet.json"
        )
    );


    function run() external {
        _parseDeployedContracts(existingUpgradeInfoPath);
        console.log("deployer is:%s", msg.sender);
        console.log("proxyAdmin is:%s", address(proxyAdmin));
        console.log("serviceManager is:%s", address(serviceManager));
        console.log("registryCoordinator is:%s", address(registryCoordinator));
        console.log("stakeRegistry is:%s", address(stakeRegistry));
        console.log("indexRegistry is:%s", address(indexRegistry));
        console.log("blsApkRegistry is:%s", address(blsApkRegistry));
        console.log("avsDirectory is:%s", address(avsDirectory));
        console.log("rewardsCoordinator is:%s", address(rewardsCoordinator));
        console.log("delegationManager is:%s", address(delegationManager));
        console.log("pauserRegistry is:%s", address(pauserRegistry));
        address owner = proxyAdmin.owner();
        console.log("proxyAdmin owner is:%s", owner);
        require(proxyAdmin.owner() == msg.sender, "Caller is not the owner of ProxyAdmin");
        vm.startBroadcast();
        _upgradeContracts();
        vm.stopBroadcast();

    }

    function _upgradeContracts() internal {
        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        stakeRegistryImplementation = new StakeRegistry(
            registryCoordinator,
            delegationManager
        );
        console.log("new stakeRegistryImplementation deploy success!");
        blsApkRegistryImplementation = new BLSApkRegistry(
            registryCoordinator
        );
        console.log("new blsApkRegistryImplementation deploy success!");

        indexRegistryImplementation = new IndexRegistry(registryCoordinator);
        console.log("new indexRegistryImplementation deploy success!");

        serviceManagerImplementation = new ServiceManager(
            avsDirectory,
            rewardsCoordinator,
            registryCoordinator,
            stakeRegistry
        );
        console.log("new serviceManagerImplementation deploy success!");

        // Third, upgrade the proxy contracts to point to the implementations
        console.log("proxy owner:%s and msg.sender is:%s", proxyAdmin.owner(), msg.sender);
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(stakeRegistry))),
            address(stakeRegistryImplementation)
        );

        console.log("upgrade stakeRegistryImplementation");

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsApkRegistry))),
            address(blsApkRegistryImplementation)
        );
        console.log("upgrade blsApkRegistryImplementation");

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))),
            address(indexRegistryImplementation)
        );

        console.log("upgrade indexRegistryImplementation");

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(serviceManager))),
            address(serviceManagerImplementation)
        );
        console.log("upgrade serviceManagerImplementation");
        registryCoordinatorImplementation = new RegistryCoordinator(
            serviceManager,
            stakeRegistry,
            blsApkRegistry,
            indexRegistry
        );
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(registryCoordinator))),
            address(registryCoordinatorImplementation)
        );
        console.log("upgrade registryCoordinatorImplementation");

        console.log("New Implementation contract is:");
        console.log("stakeRegistryImplementation:%s", address(stakeRegistryImplementation));
        console.log("blsApkRegistryImplementation:%s", address(blsApkRegistryImplementation));
        console.log("indexRegistryImplementation:%s", address(indexRegistryImplementation));
        console.log("serviceManagerImplementation:%s", address(serviceManagerImplementation));
        console.log("registryCoordinatorImplementation:%s", address(registryCoordinatorImplementation));
    }
}
