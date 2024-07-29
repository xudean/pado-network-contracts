// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WorkerMgt} from "../contracts/WorkerMgt.sol";
import {PADORegistryCoordinator} from "../contracts/PADORegistryCoordinator.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {Test, console} from "forge-std/Test.sol";
import "./mock/WorkerSelectMock.t.sol";

contract WorkerMgtTest is Test {
    bytes internal constant DIGITS = "0123456789";
    WorkerMgt public workerMgt;
    WorkerSelectMock workerSelectMock;
    uint[] privKeys;
    IBLSApkRegistry.PubkeyRegistrationParams[] pubkeys;

    function setUp() public {
        PADORegistryCoordinator registryCoordinator = PADORegistryCoordinator(address(0));
        workerMgt = new WorkerMgt();
        workerMgt.initialize(registryCoordinator);
        workerSelectMock = new WorkerSelectMock();
        for (uint32 i = 0; i < 100; i++) {
            workerSelectMock.addWorker(i);
        }

    }

    function testSelectWorker() public {
        for (uint32 i; i < 10; i++) {
            uint32[] memory workers = workerSelectMock.selectMultiplePublicKeyWorkers(keccak256(abi.encode(msg.sender)), 5);
            string memory workersStr = uint32ArrayToString(workers);
            console.log("select workers:", workersStr);
            assert(workers.length == 5);
            console.log("-------------------------------------------");

        }
    }

    //-----helper-----
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
            buffer[index] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }

    function uint32ArrayToString(uint32[] memory _uint32Array) public pure returns (string memory) {
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

