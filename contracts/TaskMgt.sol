
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ITaskMgt, Task, TaskDataInfo, TaskDataInfoRequest, ComputingInfoRequest, TaskStatus, ComputingInfo} from "./interface/ITaskMgt.sol";
import {IDataMgt, PriceInfo, DataStatus, DataInfo, EncryptionSchema} from "./interface/IDataMgt.sol";
import {IFeeMgt} from "./interface/IFeeMgt.sol";
/**
 * @title TaskMgt
 * @notice TaskMgt - Task Management Contract.
 */
contract TaskMgt is Initializable, ITaskMgt{
    IDataMgt public _dataMgt;
    IFeeMgt public _feeMgt;

    mapping(bytes32 taskId => Task task) private _allTasks;
    mapping(bytes32 workerId => bytes32[] taskIds) private _taskIdForWorker;

    bytes32[] _pendingTaskIds;
    bytes32[] _completedTaskIds;

    uint256 private _taskCount;
    function initialize(IDataMgt dataMgt, IFeeMgt feeMgt) public initializer {
        _dataMgt = dataMgt;
        _feeMgt = feeMgt;
        _taskCount = 0;
    }
    /**
     * @notice Network Consumer submit confidential computing task to PADO Network.
     * @param taskType The type of the task.
     * @param consumerPk The Public Key of the Network Consumer.
     * @param tokenSymbol The token symbol of data and computing fee.
     * @param dataInfoRequest The data parameters of the request.
     * @param computingInfoRequest The computing parameters of the request.
     * @param code The task code to run.
     * @return The UID of the new task
     */
    function submitTask(
        uint32 taskType,
        bytes calldata consumerPk,
        string calldata tokenSymbol,
        TaskDataInfoRequest calldata dataInfoRequest,
        ComputingInfoRequest calldata computingInfoRequest,
        bytes calldata code
    ) external payable returns (bytes32) {
        return bytes32(0);
    }

    /**
     * @notice Network Consumer submit confidential computing task to PADO Network.
     * @param taskType The type of the task.
     * @param consumerPk The Public Key of the Network Consumer.
     * @param dataId The id of the data. If provided, dataInfoRequest is ignored.
     * @return The UID of the new task
     */
    function submitTask(
        uint32 taskType,
        bytes calldata consumerPk,
        bytes32 dataId
    ) external payable returns (bytes32) {
        DataInfo memory dataInfo = _dataMgt.getDataById(dataId);
        PriceInfo memory priceInfo = dataInfo.priceInfo;
        bytes32[] memory workerIds = dataInfo.workerIds;
        EncryptionSchema memory encryptionSchema = dataInfo.encryptionSchema;

        require(dataInfo.status == DataStatus.REGISTERED, "data status is not REGISTERED");
        
        // TODO computing price
        uint256 fee = priceInfo.price + workerIds.length * 1;
        _feeMgt.transferToken{value: msg.value}(priceInfo.tokenSymbol, fee);

        bytes32 taskId = keccak256(abi.encode(taskType, consumerPk, dataId, _taskCount));
        _taskCount++;

        Task memory task = Task({
            taskId: taskId,
            taskType: taskType,
            consumerPk: consumerPk,
            tokenSymbol: priceInfo.tokenSymbol,
            dataId: dataId,
            dataInfo: TaskDataInfo({
                dataEncryptionPk: new bytes(0),
                price: 0,
                dataProviders: new address[](0),
                data: new bytes[](0)
            }),
            computingInfo: ComputingInfo({
                price: 0,
                t: encryptionSchema.t,
                n: encryptionSchema.n,
                workerIds: dataInfo.workerIds,
                results: new bytes[](dataInfo.workerIds.length),
                waitingList: dataInfo.workerIds
            }),
            time: uint64(block.timestamp),
            status: TaskStatus.PENDING,
            submitter: msg.sender,
            code: new bytes(0)
        });

        _allTasks[taskId] = task;
        _pendingTaskIds.push(taskId);
        
        for (uint256 i = 0; i < workerIds.length; i++) {
            _taskIdForWorker[workerIds[i]].push(taskId);
            emit WorkerReceiveTask(workerIds[i], taskId);
        }

        return taskId;
    }

    /**
     * @notice Data Provider submit data to task.
     * @param taskId The task id to which the data is associated.
     * @param data The content of the data can be the transaction ID of the storage chain.
     * @return True if submission is successful.
     */
    function submitTaskData(bytes32 taskId, bytes calldata data) external returns (bool) {
        return false;
    }

    /**
     * @notice find the index of an element in an array
     * @param target The target element.
     * @param array The array.
     * @return index The index of the target element. If not found, return max.
     */
    function find(bytes32 target, bytes32[] memory array) internal pure returns (uint256 index) {
        index = type(uint256).max;

        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                index = i;
                break;
            }
        }
    }

    /**
     * @notice Worker report the computing result.
     * @param taskId The task id to which the result is associated.
     * @param result The computing result content including zk proof.
     * @return True if reporting is successful.
     */
    function reportResult(bytes32 taskId, bytes calldata result) external returns (bool) {
        // TODO
        bytes32 workerId = keccak256(abi.encode(msg.sender));
        Task storage task = _allTasks[taskId];
        require(task.taskId == taskId, "the task does not exist");

        require(task.status == TaskStatus.PENDING, "the task status is not PENDING");
        ComputingInfo storage computingInfo = task.computingInfo;

        uint256 waitingIndex = find(workerId, computingInfo.waitingList);
        require(waitingIndex != type(uint256).max, "task id not in waiting list");

        uint256 workerIndex = find(workerId, computingInfo.workerIds);
        computingInfo.results[workerIndex] = result;

        uint256 waitingListLength = computingInfo.waitingList.length;
        computingInfo.waitingList[waitingIndex] = computingInfo.waitingList[waitingListLength - 1];
        computingInfo.waitingList.pop();
        waitingListLength--;

        bytes32[] storage taskIds = _taskIdForWorker[workerId];
        uint256 taskIndex = find(taskId, taskIds);
        taskIds[taskIndex] = taskIds[taskIds.length - 1];
        taskIds.pop();

        if (waitingListLength == 0) {
            uint256 pendingIndex = find(taskId, _pendingTaskIds);
            _pendingTaskIds[pendingIndex] = _pendingTaskIds[_pendingTaskIds.length - 1];
            _pendingTaskIds.pop();

            _completedTaskIds.push(taskId);

            task.status = TaskStatus.COMPLETED;
            emit TaskCompleted(task.taskId);
        }

        return true;
    }

    /**
     * @notice Get the tasks that need to be run by Workers.
     * @return Returns an array of tasks that the workers will run.
     */
    function getPendingTasks() external view returns (Task[] memory) {
        uint256 taskCount = _pendingTaskIds.length;

        Task[] memory tasks = new Task[](taskCount);
        for (uint256 i = 0; i < taskCount; i++) {
            tasks[i] = _allTasks[_pendingTaskIds[i]];
        }

        return tasks;
    }

    /**
     * @notice Get the tasks that a Worker needs to run.
     * @param workerId The Worker id.
     * @return Returns an array of tasks that the worker will run.
     */
    function getPendingTasksByWorkerId(bytes32 workerId) external view returns (Task[] memory) {
        bytes32[] storage taskIds = _taskIdForWorker[workerId];
        uint256 taskCount = taskIds.length;

        Task[] memory tasks = new Task[](taskCount);
        for (uint i = 0; i < taskCount; i++) {
            tasks[i] = _allTasks[taskIds[i]];
        }

        return tasks;
    }

    /**
     * @notice Get completed tasks.
     * @return Returns an array of completed tasks.
     */
    function getCompletedTasks() external view returns (Task[] memory) {
        uint256 completedTaskCount = _completedTaskIds.length;
        Task[] memory tasks = new Task[](completedTaskCount);

        for (uint256 i = 0; i < completedTaskCount; i++) {
            tasks[i] = _allTasks[_completedTaskIds[i]];
        }
        return tasks;
    }
    
    /**
     * @notice Get a completed task.
     * @param taskId The task id.
     * @return Returns The completed task.
     */
    function getCompletedTaskById(bytes32 taskId) external view returns (Task memory) {
        Task storage task = _allTasks[taskId];
        require(task.taskId == taskId, "task does not exist");

        require(task.status == TaskStatus.COMPLETED, "task is not completed");
        return task;
    }

    /**
     * @notice Set a data verification contract of a task type.
     * @param taskType The type of task.
     * @param dataVerifier The data verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setDataVerifier(uint32 taskType, address dataVerifier) external returns (bool) {
        return true;
    }

    /**
     * @notice Set a result verification contract of a task type.
     * @param taskType The type of task.
     * @param resultVerifier The result verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setResultVerifier(uint32 taskType, address resultVerifier) external returns (bool) {
        return true;
    }
}
