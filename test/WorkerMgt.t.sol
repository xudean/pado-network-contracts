// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WorkerMgt} from "../contracts/WorkerMgt.sol";
import {PADORegistryCoordinator} from "../contracts/PADORegistryCoordinator.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {Test, console} from "forge-std/Test.sol";

contract WorkerMgtTest is Test{
    WorkerMgt public workerMgt;

    uint[] privKeys;
    IBLSApkRegistry.PubkeyRegistrationParams[] pubkeys;

    function setUp() public {
        PADORegistryCoordinator registryCoordinator =  PADORegistryCoordinator(address(0));
        workerMgt = new WorkerMgt();
        workerMgt.initialize(registryCoordinator);
    }

    function testRegistryWorker() public {
        uint32[] memory taskTypes = new uint32[](1);
        taskTypes[0] = 1;
        bytes[] memory publicKeys = new bytes[](1);
        publicKeys[0] = "0x024e45D7F868C41F3723B13fD7Ae03AA5A181362";
        bytes memory quorumNumbers  = new bytes(1);
        string memory socket = "";
        IBLSApkRegistry.PubkeyRegistrationParams memory publicKeyParams;
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        console.logBytes32(keccak256(publicKeys[0]));
        bool result  = workerMgt.checkWorkerRegistered(keccak256(publicKeys[0]));
        vm.assertEq(result,false);
//        console.log("result is:%s", result);
//        workerMgt.registerEigenOperator(taskTypes, publicKeys, quorumNumbers, socket, publicKeyParams, signature);
//        bool resultAfter  = workerMgt.checkWorkerRegistered(keccak256(publicKeys[0]));
//        console.log("resultAfter is:%s", resultAfter);

    }
}

