// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WorkerMgt} from "../contracts/WorkerMgt.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {Test, console} from "forge-std/Test.sol";
import "./mock/WorkerSelectMock.t.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract WorkerMgtTest is Test {
    ProxyAdmin public padoNetworkProxyAdmin;
    WorkerMgt public workerMgt;
    WorkerMgt public workerMgtImplementation;
    WorkerSelectMock workerSelectMock;
    uint[] privKeys;
    IBLSApkRegistry.PubkeyRegistrationParams[] pubkeys;

    function setUp() public {
        RegistryCoordinator registryCoordinator = RegistryCoordinator(
            address(0)
        );
        padoNetworkProxyAdmin = new ProxyAdmin();
        workerMgtImplementation = new WorkerMgt();
        workerMgt = WorkerMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(workerMgtImplementation),
                    address(padoNetworkProxyAdmin),
                    abi.encodeWithSelector(
                        WorkerMgt.initialize.selector,
                        registryCoordinator,
                        address(this)
                    )
                )
            )
        );

        workerSelectMock = new WorkerSelectMock();
        for (uint32 i = 0; i < 100; i++) {
            workerSelectMock.addWorker(i);
        }
    }

    function testSelectWorker() public {
        for (uint32 i; i < 10; i++) {
            uint32[] memory workers = workerSelectMock
                .selectWorkers(
                    5
                );
            string memory workersStr = uint32ArrayToString(workers);
            console.log("select workers:", workersStr);
            assert(workers.length == 5);
            console.log("-------------------------------------------");
        }
    }

    function testRegistryWorker() public {
        uint32[] memory taskTypes = new uint32[](1);
        taskTypes[0] = 1;
        bytes[] memory publicKeys = new bytes[](1);
        publicKeys[0] = "0x024e45D7F868C41F3723B13fD7Ae03AA5A181362";
        bytes memory quorumNumbers = new bytes(1);
        string memory socket = "";
        IBLSApkRegistry.PubkeyRegistrationParams memory publicKeyParams;
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        console.logBytes32(keccak256(publicKeys[0]));
        bool result = workerMgt.checkWorkerRegistered(keccak256(publicKeys[0]));
        vm.assertEq(result, false);
        //        console.log("result is:%s", result);
        //        workerMgt.registerEigenOperator(taskTypes, publicKeys, quorumNumbers, socket, publicKeyParams, signature);
        //        bool resultAfter  = workerMgt.checkWorkerRegistered(keccak256(publicKeys[0]));
        //        console.log("resultAfter is:%s", resultAfter);
    }

    function testOwnerAddWhiteList() public {
        console.log("owner is:%s", workerMgt.owner());
        //not owner
        vm.prank(address(0));
        vm.expectRevert("Ownable: caller is not the owner");
        workerMgt.addWhiteListItem(address(this));
        vm.prank(address(this));
        workerMgt.addWhiteListItem(address(this));
        console.log(
            "whileList is:%s",
            workerMgt.workerWhiteList(address(this))
        );
        assertTrue(workerMgt.workerWhiteList(address(this)));
    }

//    function testWhiteList() public {
//        console.log("owner is:%s", workerMgt.owner());
//        console.log("address(this) is:%s", address(this));
//        uint32[] memory taskTypes = new uint32[](1);
//        taskTypes[0] = 1;
//        bytes[] memory publicKeys = new bytes[](1);
//        publicKeys[0] = "0x024e45D7F868C41F3723B13fD7Ae03AA5A181362";
//        bytes memory quorumNumbers = new bytes(1);
//        string memory socket = "";
//        IBLSApkRegistry.PubkeyRegistrationParams memory publicKeyParams;
//        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
//        vm.expectRevert("workerWhiteList: worker not in whitelist");
//
//        workerMgt.registerEigenOperator(
//            taskTypes,
//            publicKeys,
//            quorumNumbers,
//            socket,
//            publicKeyParams,
//            signature
//        );
//        workerMgt.addWhiteListItem(address(this));
//        console.log(
//            "whileList is:%s",
//            workerMgt.workerWhiteList(address(this))
//        );
//        vm.expectRevert("registryCoordinator not set!");
//        workerMgt.registerEigenOperator(
//            taskTypes,
//            publicKeys,
//            quorumNumbers,
//            socket,
//            publicKeyParams,
//            signature
//        );
//    }

    //======================helper========================
    function uintToString(uint32 _i) public pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint32 temp = _i;
        uint32 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint32 index = digits;
        temp = _i;
        while (temp != 0) {
            index -= 1;
            buffer[index] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }

    function uint32ArrayToString(
        uint32[] memory _uint32Array
    ) public pure returns (string memory) {
        bytes memory result;
        for (uint256 i = 0; i < _uint32Array.length; i++) {
            result = abi.encodePacked(result, uintToString(_uint32Array[i]));
            if (i < _uint32Array.length - 1) {
                result = abi.encodePacked(result, ",");
            }
        }
        return string(result);
    }
}
