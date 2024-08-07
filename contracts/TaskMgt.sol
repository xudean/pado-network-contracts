
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ITaskMgt} from "./interface/ITaskMgt.sol";
import {Task, TaskDataInfo, TaskDataInfoRequest, ComputingInfoRequest, TaskStatus, ComputingInfo, Worker, TaskType, PriceInfo, DataStatus, DataInfo, EncryptionSchema, TaskReportStatus} from "./types/Common.sol";
import {IDataMgt} from "./interface/IDataMgt.sol";
import {IFeeMgt} from "./interface/IFeeMgt.sol";
import {IWorkerMgt} from "./interface/IWorkerMgt.sol";

/**
 * @title TaskMgt
 * @notice TaskMgt - Task Management Contract.
 */
contract TaskMgt is ITaskMgt, OwnableUpgradeable{
    // The data management
    IDataMgt public dataMgt;

    // The fee management
    IFeeMgt public feeMgt;

    // The worker management
    IWorkerMgt public workerMgt;

    // TIMEOUT
    uint64 public taskTimeout;

    // The count of tasks
    uint256 public taskCount;

    // taskId => task
    mapping(bytes32 taskId => Task task) private _allTasks;

    // workerId => taskIds[]
    mapping(bytes32 workerId => bytes32[] taskIds) private _taskIdForWorker;

    // The id of pending tasks
    bytes32[] private _pendingTaskIds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the task management
     * @param _dataMgt The data management
     * @param _feeMgt The fee management
     * @param _workerMgt The worker management
     * @param contractOwner The owner of the contract
     */
    function initialize(IDataMgt _dataMgt, IFeeMgt _feeMgt, IWorkerMgt _workerMgt, address contractOwner) public initializer {
        dataMgt = _dataMgt;
        feeMgt = _feeMgt;
        workerMgt = _workerMgt;
        taskCount = 0;
        taskTimeout = 60;
        _transferOwnership(contractOwner);
    }

    receive() payable external {}

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
        TaskType taskType,
        bytes calldata consumerPk,
        string calldata tokenSymbol,
        TaskDataInfoRequest calldata dataInfoRequest,
        ComputingInfoRequest calldata computingInfoRequest,
        bytes calldata code
    ) external payable returns (bytes32) {}
    
    /**
     * @notice Get worker owners by worker ids.
     * @param workerIds The worker id array
     * @return The worker owner address array
     */
    function _getWorkerOwners(bytes32[] memory workerIds) internal view returns (address[] memory) {
        uint256 workerIdLength = workerIds.length;

        address[] memory workerOwners = new address[](workerIdLength);
        Worker[] memory workers = workerMgt.getWorkersByIds(workerIds);
        for (uint256 i = 0; i < workerIdLength; i++) {
            workerOwners[i] = workers[i].owner;
        }
        return workerOwners;
    }

    /**
     * @notice Network Consumer submit confidential computing task to PADO Network.
     * @param taskType The type of the task.
     * @param consumerPk The Public Key of the Network Consumer.
     * @param dataId The id of the data. If provided, dataInfoRequest is ignored.
     * @return The UID of the new task
     */
    function submitTask(
        TaskType taskType,
        bytes calldata consumerPk,
        bytes32 dataId
    ) external payable returns (bytes32) {
        DataInfo memory dataInfo = dataMgt.getDataById(dataId);
        PriceInfo memory priceInfo = dataInfo.priceInfo;
        bytes32[] memory workerIds = dataInfo.workerIds;
        EncryptionSchema memory encryptionSchema = dataInfo.encryptionSchema;

        require(dataInfo.status == DataStatus.REGISTERED, "TaskMgt.submitTask: data status is not REGISTERED");
        
        uint256 computingPrice = feeMgt.getFeeTokenBySymbol(priceInfo.tokenSymbol).computingPrice;
        uint256 fee = priceInfo.price + workerIds.length * computingPrice;
        feeMgt.transferToken{value: msg.value}(msg.sender, priceInfo.tokenSymbol, fee);

        bytes32 taskId = keccak256(abi.encode(taskType, consumerPk, dataId, taskCount));
        taskCount++;

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
                price: computingPrice,
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
        }
        feeMgt.lock(
            taskId,
            msg.sender,
            priceInfo.tokenSymbol,
            fee
        );
        emit TaskDispatched(taskId, workerIds);

        return taskId;
    }

    /**
     * @notice Data Provider submit data to task.
     * @param taskId The task id to which the data is associated.
     * @param data The content of the data can be the transaction ID of the storage chain.
     * @return True if submission is successful.
     */
    function submitTaskData(bytes32 taskId, bytes calldata data) external returns (bool) {}

    /**
     * @notice find the index of an element in an array
     * @param target The target element.
     * @param array The array.
     * @return index The index of the target element. If not found, return max.
     */
    function _find(bytes32 target, bytes32[] memory array) internal pure returns (uint256 index) {
        index = type(uint256).max;

        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                index = i;
                break;
            }
        }
    }

    /**
     * @notice Remove pendingTaskIds and settle fee.
     * @param taskId The id of task.
     */
    function _onTaskCompleted(bytes32 taskId) internal {
        Task storage task = _allTasks[taskId];
        DataInfo memory dataInfo = dataMgt.getDataById(task.dataId);

        uint256 pendingIndex = _find(taskId, _pendingTaskIds);
        _pendingTaskIds[pendingIndex] = _pendingTaskIds[_pendingTaskIds.length - 1];
        _pendingTaskIds.pop();

        task.status = TaskStatus.COMPLETED;

        address[] memory dataProviders = new address[](1);
        dataProviders[0] = dataInfo.owner;
        
        ComputingInfo storage computingInfo = task.computingInfo;
        bytes32[] memory workerIds;
        if (computingInfo.waitingList.length == 0) {
            workerIds = computingInfo.workerIds;
        }
        else {
            uint256 workerIdLength = computingInfo.workerIds.length - computingInfo.waitingList.length;
            workerIds = new bytes32[](workerIdLength);
            uint256 workerIndex = 0;
            for (uint256 i = 0; i < computingInfo.workerIds.length; i++) {
                if (_find(computingInfo.workerIds[i], computingInfo.waitingList) == type(uint256).max) {
                    workerIds[workerIndex] = computingInfo.workerIds[i];
                    workerIndex++;
                }
            }
        }


        feeMgt.settle(
            task.taskId,
            task.status,
            task.submitter,
            task.tokenSymbol,
            _getWorkerOwners(workerIds),
            dataInfo.priceInfo.price,
            dataProviders
        );
        emit TaskCompleted(task.taskId);
    }

    /**
     * @notice remove pendingTaskIds and unlock fee
     * @param taskId The task id
     */
    function _onTaskFailed(bytes32 taskId) internal {
        Task storage task = _allTasks[taskId];
        DataInfo memory dataInfo = dataMgt.getDataById(task.dataId);

        uint256 pendingIndex = _find(taskId, _pendingTaskIds);
        _pendingTaskIds[pendingIndex] = _pendingTaskIds[_pendingTaskIds.length - 1];
        _pendingTaskIds.pop();

        task.status = TaskStatus.FAILED;

        feeMgt.unlock(
            task.taskId,
            task.submitter,
            task.tokenSymbol
        );
        emit TaskFailed(task.taskId);
    }

    /**
     * @notice Worker report the computing result.
     * @param taskId The task id to which the result is associated.
     * @param workerId The worker id.
     * @param result The computing result content including zk proof.
     * @return True if reporting is successful.
     */
    function reportResult(bytes32 taskId, bytes32 workerId, bytes calldata result) external returns (bool) {
        Worker memory worker = workerMgt.getWorkerById(workerId);
        require(msg.sender == worker.owner, "TaskMgt.reportResult: worker id and worker owner error");
        Task storage task = _allTasks[taskId];
        require(task.taskId == taskId, "TaskMgt.reportResult: the task does not exist");

        require(task.status == TaskStatus.PENDING, "TaskMgt.reportResult: the task status is not PENDING");
        ComputingInfo storage computingInfo = task.computingInfo;

        uint256 waitingIndex = _find(workerId, computingInfo.waitingList);
        require(waitingIndex != type(uint256).max, "TaskMgt.reportResult: worker id not in waiting list");

        uint256 workerIndex = _find(workerId, computingInfo.workerIds);
        computingInfo.results[workerIndex] = result;

        uint256 waitingListLength = computingInfo.waitingList.length;
        computingInfo.waitingList[waitingIndex] = computingInfo.waitingList[waitingListLength - 1];
        computingInfo.waitingList.pop();
        waitingListLength--;

        bytes32[] storage taskIds = _taskIdForWorker[workerId];
        uint256 taskIndex = _find(taskId, taskIds);
        taskIds[taskIndex] = taskIds[taskIds.length - 1];
        taskIds.pop();

        if (waitingListLength == 0) {
            _onTaskCompleted(taskId);
        }

        emit ResultReported(taskId, msg.sender);

        return true;
    }

    /**
     * @notice Update task
     * @param taskId The task id.
     * @return Return task status.
     */
    function updateTask(bytes32 taskId) external returns (TaskStatus) {
        Task storage task = _allTasks[taskId];
        require(task.status == TaskStatus.PENDING, "TaskMgt.updateTask: task status is not pending");

        uint64 currentTime = uint64(block.timestamp);
        require(currentTime >= task.time + taskTimeout, "TaskMgt.updateTask: task is not timeout");


        DataInfo memory dataInfo = dataMgt.getDataById(task.dataId);
        EncryptionSchema memory encryptionSchema = dataInfo.encryptionSchema;
        if (encryptionSchema.n - task.computingInfo.waitingList.length >= encryptionSchema.t) {
            _onTaskCompleted(taskId);
        }
        else {
            _onTaskFailed(taskId);
        }
        return task.status;
    }

    /**
     * @notice Get the tasks that need to be run by Workers.
     * @return Returns an array of tasks that the workers will run.
     */
    function getPendingTasks() external view returns (Task[] memory) {
        uint256 pendingTaskCount = _pendingTaskIds.length;

        Task[] memory tasks = new Task[](pendingTaskCount);
        for (uint256 i = 0; i < pendingTaskCount; i++) {
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
        uint256 taskIdLength = taskIds.length;

        Task[] memory tasks = new Task[](taskIdLength);
        for (uint256 i = 0; i < taskIdLength; i++) {
            tasks[i] = _allTasks[taskIds[i]];
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
        require(task.taskId == taskId, "TaskMgt.getCompletedTaskById: task does not exist");

        require(task.status == TaskStatus.COMPLETED, "TaskMgt.getCompletedTaskById: task is not completed");
        return task;
    }

   /**
    * @notice Get task report status.
    * @param taskId The task id.
    * @return Returns The task report status.
    */
   function getTaskReportStatus(bytes32 taskId) external view returns (TaskReportStatus) {
       Task storage task = _allTasks[taskId];
       require(task.taskId == taskId, "TaskMgt.getTaskReportStatsu: task does not exist");

       if (task.status == TaskStatus.COMPLETED || task.status == TaskStatus.FAILED) {
           return TaskReportStatus.COMPLETED;
       }

       uint64 currentTime = uint64(block.timestamp);
       if (currentTime >= task.time + taskTimeout) {
           return TaskReportStatus.TIMEOUT;
       }
       return TaskReportStatus.WAITING;
   }

    /**
     * @notice Set a data verification contract of a task type.
     * @param taskType The type of task.
     * @param dataVerifier The data verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setDataVerifier(TaskType taskType, address dataVerifier) external onlyOwner returns (bool) {}

    /**
     * @notice Set a result verification contract of a task type.
     * @param taskType The type of task.
     * @param resultVerifier The result verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setResultVerifier(TaskType taskType, address resultVerifier) external onlyOwner returns (bool) {}
}
