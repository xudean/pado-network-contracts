
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {TestERC20} from "./TestERC20.sol";
import {TaskMgt} from "../contracts/TaskMgt.sol";
import {ITaskMgt, TaskStatus, Task} from "../contracts/interface/ITaskMgt.sol";
import {IDataMgt} from "../contracts/interface/IDataMgt.sol";
import {IFeeMgt, Allowance} from "../contracts/interface/IFeeMgt.sol";
import {EncryptionSchema, PriceInfo, DataMgt} from "../contracts/DataMgt.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";

contract TaskMgtTest is Test {
    ITaskMgt taskMgt;
    IDataMgt dataMgt;
    IFeeMgt feeMgt;
    bytes32 dataId;
    bytes32 taskId;
    TestERC20 erc20;
    string private constant TOKEN_SYMBOL = "bETH";

    function setUp() public {
        TaskMgt mgt = new TaskMgt();

        DataMgt datamgt = new DataMgt();
        datamgt.initialize();
        dataMgt = datamgt;

        FeeMgt feemgt = new FeeMgt();
        feemgt.initialize();
        TestERC20 bETH = new TestERC20();
        bETH.initialize("TEST ETH", "bETH", 18);
        erc20 = bETH;
        feemgt.addFeeToken("bETH", address(bETH));
        feeMgt = feemgt;
        
        mgt.initialize(dataMgt, feeMgt);
        taskMgt = mgt;

        dataId = registerData(TOKEN_SYMBOL);
    }

    function registerData(string memory tokenSymbol) internal returns (bytes32) {
        bytes[] memory publicKeys;
        bytes32 registryId;
        (registryId, publicKeys) = dataMgt.prepareRegistry(EncryptionSchema({
            t: 2,
            n: 3
        }));

        PriceInfo memory priceInfo = PriceInfo({
            tokenSymbol: tokenSymbol,
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

    function submitTask(string memory tokenSymbol) internal {
        bytes memory consumerPk = bytes("consumerPk");
        // vm.expectEmit(true, true, true, true);
        emit ITaskMgt.WorkerReceiveTask(keccak256(abi.encode(this)), taskId);

        Allowance memory oldAllowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free, 0, "oldAllowance.free not correct");
        assertEq(oldAllowance.locked, 0, "oldAllowance.locked not correct");
        erc20.mint(msg.sender, 100);
        vm.prank(address(msg.sender));
        erc20.approve(address(feeMgt), 3);
        vm.prank(address(msg.sender));
        taskId = taskMgt.submitTask{value: 3}(
            0,
            consumerPk,
            dataId
        );
        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(allowance.free, 0, "allowance.free not correct");
        assertEq(allowance.locked, 3, "allowance.locked not correct");
    }

    function test_submitTask() public {
        submitTask(TOKEN_SYMBOL);
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

        Task memory task = taskMgt.getCompletedTaskById(taskId);
        assertEq(task.status == TaskStatus.COMPLETED, true);
    }
}
