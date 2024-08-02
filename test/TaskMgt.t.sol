// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {TestERC20} from "./mock/TestERC20.sol";
import {TaskMgt} from "../contracts/TaskMgt.sol";
import {ITaskMgt, TaskStatus, Task} from "../contracts/interface/ITaskMgt.sol";
import {IDataMgt, DataInfo} from "../contracts/interface/IDataMgt.sol";
import {IFeeMgt, Allowance, FeeTokenInfo} from "../contracts/interface/IFeeMgt.sol";
import {EncryptionSchema, PriceInfo, DataMgt} from "../contracts/DataMgt.sol";
import {ITaskMgtEvents} from "./events/ITaskMgtEvents.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MockDeployer} from "./mock/MockDeployer.sol";
import {TaskType, Worker} from "../contracts/types/Common.sol";

contract TaskMgtTest is MockDeployer, ITaskMgtEvents {
    bytes32 dataId;
    bytes32 taskId;
    TestERC20 erc20;
    string private constant TOKEN_SYMBOL = "bETH";
    address private constant worker_address_0 = address(uint160(uint256(keccak256("worker 0"))));
    address private constant worker_address_1 = address(uint160(uint256(keccak256("worker 1"))));
    address private constant worker_address_2 = address(uint160(uint256(keccak256("worker 2"))));
    address private constant data_provider_address = address(uint160(uint256(keccak256("data provider"))));

    function setUp() public {
        _deployAll();

        TestERC20 bETH = new TestERC20();
        bETH.initialize("TEST ETH", "bETH", 18);
        erc20 = bETH;
        feeMgt.addFeeToken("bETH", address(bETH), 1);

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
            dataContent
        );

        assertEq(registryId, dataid);
        return dataid;
    }

    function submitTask(string memory tokenSymbol) internal {
        bytes memory consumerPk = bytes("consumerPk");
        // vm.expectEmit(true, true, true, true);
        emit WorkerReceiveTask(keccak256(abi.encode(this)), taskId);

        Allowance memory oldAllowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free, 0, "oldAllowance.free not correct");
        assertEq(oldAllowance.locked, 0, "oldAllowance.locked not correct");
        erc20.mint(msg.sender, 100);

        DataInfo memory dataInfo = dataMgt.getDataById(dataId);
        FeeTokenInfo memory feeToken = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        uint256 feeAmount = dataInfo.priceInfo.price  + dataInfo.workerIds.length * feeToken.computingPrice;
        vm.prank(address(msg.sender));
        erc20.approve(address(feeMgt), feeAmount);
        vm.prank(address(msg.sender));
        taskId = taskMgt.submitTask{value: feeAmount}(
            TaskType.DATA_SHARING,
            consumerPk,
            dataId
        );
        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(allowance.free, 0, "allowance.free not correct");
        assertEq(allowance.locked, feeAmount, "allowance.locked not correct");
    }

    function test_submitTask() public {
        submitTask(TOKEN_SYMBOL);
    }

    function test_getPendingTasks() public {
        test_submitTask();
        assertEq(taskMgt.getPendingTasks().length, 1);

        (bytes32[] memory workerIds, ) = _getWorkerInfoByDataId(dataId);

        for (uint256 i = 0; i < workerIds.length; i++) {
            Task[] memory tasks = taskMgt.getPendingTasksByWorkerId(workerIds[i]);
            assertEq(tasks.length, 1);
            assertEq(tasks[0].status == TaskStatus.PENDING, true);
        }
    }

    function test_reportResult() public {
        test_submitTask();

        (bytes32[] memory workerIds, address[] memory workerOwners) = _getWorkerInfoByDataId(dataId);
        require(workerIds.length == workerOwners.length, "the length of worker id and worker owner not equal");

        for (uint256 i = 0; i < workerIds.length; i++) {
            vm.prank(workerOwners[i]);
            taskMgt.reportResult(taskId, workerIds[i], bytes("task result"));
        }
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
        assertEq(taskMgt.getPendingTasks().length, 0);
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
