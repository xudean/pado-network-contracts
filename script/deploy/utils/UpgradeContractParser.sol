// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "eigenlayer-contracts/src/contracts/core/DelegationManager.sol";


import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {RegistryCoordinator, IPauserRegistry} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import "eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";

import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";

import {ServiceManager} from "../../../contracts/ServiceManager.sol";

import "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract UpgradeContractParser is Script, Test {

    // EigenLayer Contracts
    IAVSDirectory public avsDirectory;
    IRewardsCoordinator public rewardsCoordinator;

    // PADO network Contracts
    ProxyAdmin public proxyAdmin;
    ServiceManager public serviceManager;
    ServiceManager public serviceManagerImplementation;
    IRegistryCoordinator public registryCoordinator;
    RegistryCoordinator public registryCoordinatorImplementation;
    IStakeRegistry public stakeRegistry;
    IStakeRegistry public stakeRegistryImplementation;
    IIndexRegistry public indexRegistry;
    IIndexRegistry public indexRegistryImplementation;
    IBLSApkRegistry public blsApkRegistry;
    IBLSApkRegistry public blsApkRegistryImplementation;
    DelegationManager public delegationManager;
    DelegationManager public delegationManagerImplementation;
    PauserRegistry public pauserRegistry;


    function _parseDeployedContracts(string memory existingDeploymentInfoPath) internal {
        string memory existingDeploymentData = vm.readFile(existingDeploymentInfoPath);
        proxyAdmin = ProxyAdmin(stdJson.readAddress(existingDeploymentData, ".addresses.proxyAdminAddress"));
        serviceManager = ServiceManager(stdJson.readAddress(existingDeploymentData, ".addresses.serviceManagerAddress"));
        registryCoordinator = IRegistryCoordinator(stdJson.readAddress(existingDeploymentData, ".addresses.registryCoordinatorAddress"));
        stakeRegistry = IStakeRegistry(stdJson.readAddress(existingDeploymentData, ".addresses.stakeRegistryAddress"));
        indexRegistry = IIndexRegistry(stdJson.readAddress(existingDeploymentData, ".addresses.indexRegistryAddress"));
        blsApkRegistry = IBLSApkRegistry(stdJson.readAddress(existingDeploymentData, ".addresses.blsApkRegistryAddress"));
        avsDirectory = IAVSDirectory(stdJson.readAddress(existingDeploymentData, ".addresses.avsDirectoryAddress"));
        rewardsCoordinator = IRewardsCoordinator(stdJson.readAddress(existingDeploymentData, ".addresses.rewardsCoordinatorAddress"));
        delegationManager = DelegationManager(stdJson.readAddress(existingDeploymentData, ".addresses.delegationManagerAddress"));
        pauserRegistry = PauserRegistry(stdJson.readAddress(existingDeploymentData, ".addresses.eigenLayerPauserReg"));
    }
}