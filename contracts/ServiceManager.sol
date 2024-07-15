// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

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



contract ServiceManager is ServiceManagerBase{

    constructor(
        IAVSDirectory __avsDirectory,
        IRewardsCoordinator __rewardsCoordinator,
        IRegistryCoordinator __registryCoordinator,
        IStakeRegistry __stakeRegistry
    ) ServiceManagerBase(__avsDirectory,__rewardsCoordinator,__registryCoordinator,__stakeRegistry){
        
    }

    function initialize(address initialOwner) public virtual initializer {
        _transferOwnership(initialOwner);
    }

    function updateAVSMetadataURI(string memory _metadataURI)  public override onlyOwner {
        _avsDirectory.updateAVSMetadataURI(_metadataURI);
    }
    
    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    )  public override onlyRegistryCoordinator {
        _avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }

    function deregisterOperatorFromAVS(address operator)  public override  onlyRegistryCoordinator {
        _avsDirectory.deregisterOperatorFromAVS(operator);
    }
}
