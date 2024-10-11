// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {TestERC20} from "./mock/TestERC20.sol";
import {TaskMgt} from "../contracts/TaskMgt.sol";
import {ITaskMgt} from "../contracts/interface/ITaskMgt.sol";
import {IDataMgt} from "../contracts/interface/IDataMgt.sol";
import {IFeeMgt} from "../contracts/interface/IFeeMgt.sol";
import {DataMgt} from "../contracts/DataMgt.sol";
import {ITaskMgtEvents} from "./events/ITaskMgtEvents.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MockDeployer} from "./mock/MockDeployer.sol";
import {TaskType, Worker, DataInfo, PriceInfo, EncryptionSchema, Balance, FeeTokenInfo, TaskStatus, Task, TaskReportStatus} from "../contracts/types/Common.sol";

contract TaskMgtTest is MockDeployer, ITaskMgtEvents {
    bytes32 dataId;
    bytes32 taskId;
    TestERC20 erc20;
    string private constant TOKEN_SYMBOL = "tETH";
    address private constant worker_address_0 = address(uint160(uint256(keccak256("worker 0"))));
    address private constant worker_address_1 = address(uint160(uint256(keccak256("worker 1"))));
    address private constant worker_address_2 = address(uint160(uint256(keccak256("worker 2"))));
    address private constant data_provider_address = address(uint160(uint256(keccak256("data provider"))));

    function setUp() public {
        _deployAll();

        TestERC20 tETH = new TestERC20();
        tETH.initialize("TEST ETH", "tETH", 18);
        erc20 = tETH;

        vm.prank(contractOwner);
        feeMgt.addFeeToken("tETH", address(tETH), 1);

        dataId = registerData(TOKEN_SYMBOL);
    }

    function registerData(string memory tokenSymbol) internal returns (bytes32) {
        bytes[] memory publicKeys;
        bytes32 registryId;
        vm.prank(data_provider_address);
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

        vm.prank(data_provider_address);
        bytes32 dataid = dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent,
            new address[](0)
        );

        assertEq(registryId, dataid);
        return dataid;
    }

    function submitTask(string memory tokenSymbol) internal {
        bytes memory consumerPk = bytes("consumerPk");
        Balance memory oldBalance = feeMgt.getBalance(msg.sender, tokenSymbol);
        assertEq(oldBalance.free, 0, "oldBalance.free not correct");
        assertEq(oldBalance.locked, 0, "oldBalance.locked not correct");
        erc20.mint(msg.sender, 100);

        DataInfo memory dataInfo = dataMgt.getDataById(dataId);
        FeeTokenInfo memory feeToken = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        uint256 feeAmount = dataInfo.priceInfo.price  + dataInfo.workerIds.length * feeToken.computingPrice;
        vm.prank(address(msg.sender));
        erc20.approve(address(feeMgt), feeAmount);
        vm.prank(address(msg.sender));
        vm.expectEmit(false, false, false, false);
        emit TaskDispatched(taskId, new bytes32[](0)); 

        if (_isETH(dataInfo.priceInfo.tokenSymbol)) {
            taskId = taskMgt.submitTask{value: feeAmount}(
                TaskType.DATA_SHARING,
                consumerPk,
                dataId
            );
        }
        else {
            taskId = taskMgt.submitTask(
                TaskType.DATA_SHARING,
                consumerPk,
                dataId
            );
        }
        Balance memory balance = feeMgt.getBalance(msg.sender, tokenSymbol);
        assertEq(balance.free, 0, "balance.free not correct");
        assertEq(balance.locked, feeAmount, "balance.locked not correct");
    }

    function test_submitTask() public {
        submitTask(TOKEN_SYMBOL);
        Task[] memory tasks = taskMgt.getPendingTasks();
        assertEq(tasks.length, 1);
    }

    function test_reportResult() public {
        test_submitTask();

        (bytes32[] memory workerIds, address[] memory workerOwners) = _getWorkerInfoByDataId(dataId);
        require(workerIds.length == workerOwners.length, "the length of worker id and worker owner not equal");

        for (uint256 i = 0; i < workerIds.length; i++) {
            vm.prank(workerOwners[i]);
            if (i == workerIds.length - 1) {
                vm.expectEmit(true, true, true, true);
                emit TaskCompleted(taskId);
            }
            vm.expectEmit(true, true, true, true);
            emit ResultReported(taskId, workerOwners[i]);
            taskMgt.reportResult(taskId, workerIds[i], bytes("task result"));
        }
        Task memory task = taskMgt.getCompletedTaskById(taskId);
        require(task.status == TaskStatus.COMPLETED, "task status is not completed");

        DataInfo memory dataInfo = dataMgt.getDataById(task.dataId);
        FeeTokenInfo memory feeInfo = feeMgt.getFeeTokenBySymbol(TOKEN_SYMBOL);
        for (uint256 i = 0; i < workerIds.length; i++) {
            vm.prank(workerOwners[i]);
            feeMgt.withdrawToken(workerOwners[i], TOKEN_SYMBOL, feeInfo.computingPrice); 
        }
        vm.prank(dataInfo.owner);
        feeMgt.withdrawToken(dataInfo.owner, TOKEN_SYMBOL, dataInfo.priceInfo.price);
    }

    function test_reportResult_LessT() public {
        test_submitTask();

        (bytes32[] memory workerIds, address[] memory workerOwners) = _getWorkerInfoByDataId(dataId);
        require(workerIds.length == workerOwners.length, "the length of worker id and worker owner not equal");

        for (uint256 i = 0; i < workerIds.length - 2; i++) {
            vm.prank(workerOwners[i]);
            vm.expectEmit(true, true, true, true);
            emit ResultReported(taskId, workerOwners[i]);
            taskMgt.reportResult(taskId, workerIds[i], bytes("task result"));
        }
        vm.prank(address(msg.sender));
        vm.warp(block.timestamp + 70);
        vm.expectEmit(true, true, true, true);
        emit TaskFailed(taskId);
        taskMgt.updateTask(taskId);
    }

    function test_reportResult_GreaterT() public {
        test_submitTask();

        (bytes32[] memory workerIds, address[] memory workerOwners) = _getWorkerInfoByDataId(dataId);
        require(workerIds.length == workerOwners.length, "the length of worker id and worker owner not equal");

        for (uint256 i = 0; i < workerIds.length - 1; i++) {
            vm.prank(workerOwners[i]);
            vm.expectEmit(true, true, true, true);
            emit ResultReported(taskId, workerOwners[i]);
            taskMgt.reportResult(taskId, workerIds[i], bytes("task result"));
        }
        vm.prank(address(msg.sender));
        vm.warp(block.timestamp + 70);
        vm.expectEmit(true, true, true, true);
        emit TaskCompleted(taskId);
        taskMgt.updateTask(taskId);

        vm.prank(msg.sender);
        Task memory task = taskMgt.getCompletedTaskById(taskId);
        require(task.status == TaskStatus.COMPLETED, "task is not completed");
    }

    function test_updateTaskReportTimeout() public {
        vm.prank(contractOwner);
        vm.expectEmit(true, true, true, true);
        emit TaskReportTimeoutUpdated(20);
        taskMgt.updateTaskReportTimeout(20);
        (bool b, bytes memory res) = address(taskMgt).call(abi.encode(keccak256("taskTimeout()")));
        require(b, "call taskTimeout error");
        uint256 taskTimeout = abi.decode(res, (uint256));
        assertEq(taskTimeout, 20);
    }

    function _getWorkerInfoByDataId(bytes32 dataId_) internal view returns (bytes32[] memory workerIds, address[] memory workerOwners) {
        workerIds = dataMgt.getDataById(dataId_).workerIds;
        workerOwners = new address[](workerIds.length);

        Worker[] memory workers = workerMgt.getWorkersByIds(workerIds);
        for (uint256 i = 0; i < workerIds.length; i++) {
            workerOwners[i] = workers[i].owner;
        }
    }

    function test_getCompletedTasks() public {
        test_reportResult();
        Task[] memory tasks = taskMgt.getPendingTasksByWorkerId(keccak256(abi.encode(this)));
        assertEq(tasks.length, 0);

        Task memory task = taskMgt.getCompletedTaskById(taskId);
        assertEq(task.status == TaskStatus.COMPLETED, true);

        DataInfo memory dataInfo = dataMgt.getDataById(task.dataId);
        FeeTokenInfo memory feeInfo = feeMgt.getFeeTokenBySymbol(TOKEN_SYMBOL);

        uint256 sumBalance = 0;

        assertEq(dataInfo.owner, data_provider_address);
        uint256 dataProviderBalance = _getBalance(TOKEN_SYMBOL, data_provider_address);
        assertEq(dataProviderBalance, dataInfo.priceInfo.price, "data provider balance error");
        sumBalance += dataProviderBalance;

        (bytes32[] memory workerIds, address[] memory workerOwners) = _getWorkerInfoByDataId(dataId);
        for (uint256 i = 0; i < workerIds.length; i++) {
            uint256 workerBalance = _getBalance(TOKEN_SYMBOL, workerOwners[i]);
            assertEq(workerBalance, feeInfo.computingPrice, "workerBalance not equal computingPrice");
            sumBalance += workerBalance;
        }
        uint256 lockedAmount = dataInfo.priceInfo.price + workerIds.length * feeInfo.computingPrice;
        assertEq(sumBalance, lockedAmount, "sumBalance error");
        
    }
    function _isETH(string memory tokenSymbol) internal pure returns (bool) {
        return keccak256(bytes(tokenSymbol)) == keccak256(bytes("ETH"));
    }
    function _getBalance(string memory tokenSymbol, address target) internal view returns(uint256) {
        if (_isETH(tokenSymbol)) {
            return target.balance;
        }
        FeeTokenInfo memory feeToken = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        return IERC20(feeToken.tokenAddress).balanceOf(target);
    }
    
}
