
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {TaskMgt} from "../contracts/TaskMgt.sol";
import {ITaskMgt, TaskStatus, Task} from "../contracts/interface/ITaskMgt.sol";
import {IDataMgt} from "../contracts/interface/IDataMgt.sol";
import {EncryptionSchema, PriceInfo, DataMgt} from "../contracts/DataMgt.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";

contract TaskMgtTest is Test {
    ITaskMgt taskMgt;
    IDataMgt dataMgt;
    bytes32 dataId;
    bytes32 taskId;

    function setUp() public {
        TaskMgt mgt = new TaskMgt();

        DataMgt datamgt = new DataMgt();
        datamgt.initialize();
        dataMgt = datamgt;

        FeeMgt feeMgt = new FeeMgt();
        feeMgt.initialize();
        
        mgt.initialize(dataMgt, feeMgt);
        taskMgt = mgt;

        dataId = registerData();
    }

    function registerData() public returns (bytes32) {
        bytes[] memory publicKeys;
        bytes32 registryId;
        (registryId, publicKeys) = dataMgt.prepareRegistry(EncryptionSchema({
            t: 2,
            n: 3
        }));

        PriceInfo memory priceInfo = PriceInfo({
            tokenSymbol: "ETH",
            price: 2
        });

        bytes memory dataContent = new bytes(4);
        dataContent[0] = bytes1(uint8(0x74));
        dataContent[1] = bytes1(uint8(0x65));
        dataContent[2] = bytes1(uint8(0x73));
        dataContent[3] = bytes1(uint8(0x74));

        bytes32 dataid = dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent
        );

        assertEq(registryId, dataid);
        return dataid;
    }

    function test_submitTask() public {
        bytes memory consumerPk = bytes("consumerPk");
        vm.expectEmit(true, true, false, false);

        taskId = taskMgt.submitTask{value: 3}(
            0,
            consumerPk,
            dataId
        );
        emit ITaskMgt.WorkerReceiveTask(keccak256(abi.encode(this)), taskId);
    }

    function test_getPendingTasks() public {
        test_submitTask();
        assertEq(taskMgt.getPendingTasks().length, 1);

        Task[] memory tasks = taskMgt.getPendingTasksByWorkerId(keccak256(abi.encode(this)));
        assertEq(tasks.length, 1);
        assertEq(tasks[0].status == TaskStatus.PENDING, true);
    }

    function test_reportResult() public {
        test_submitTask();
        taskMgt.reportResult(taskId, bytes("task result"));
    }

    function test_getCompletedTasks() public {
        test_reportResult();
        assertEq(taskMgt.getPendingTasks().length, 0);
        Task[] memory tasks = taskMgt.getPendingTasksByWorkerId(keccak256(abi.encode(this)));
        assertEq(tasks.length, 0);

        assertEq(taskMgt.getCompletedTasks().length, 1);
        Task memory task = taskMgt.getCompletedTaskById(taskId);
        assertEq(task.status == TaskStatus.COMPLETED, true);
    }
}
