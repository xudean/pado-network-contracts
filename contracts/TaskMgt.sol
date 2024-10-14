
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {ITaskMgt} from "./interface/ITaskMgt.sol";
import {Task, TaskDataInfo, TaskDataInfoRequest, ComputingInfoRequest, TaskStatus, ComputingInfo, Worker, TaskType, PriceInfo, DataStatus, DataInfo, EncryptionSchema, TaskReportStatus} from "./types/Common.sol";
import {IDataMgt} from "./interface/IDataMgt.sol";
import {IFeeMgt} from "./interface/IFeeMgt.sol";
import {IWorkerMgt} from "./interface/IWorkerMgt.sol";
import {IRouter, IRouterUpdater} from "./interface/IRouter.sol";

/**
 * @title TaskMgt
 * @notice TaskMgt - Task Management Contract.
 */
contract TaskMgt is ITaskMgt, IRouterUpdater, OwnableUpgradeable{
    // The router
    IRouter public router;

    // TIMEOUT
    uint64 public taskTimeout;

    // The count of tasks
    uint256 public taskCount;

    // taskId => task
    mapping(bytes32 taskId => Task task) private _allTasks;

    // workerId => pendingTaskIds[]
    mapping(bytes32 workerId => bytes32[] taskIds) private _pendingTaskIdForWorker;

    // pending task id array
    bytes32[] private _pendingTaskIds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the task management
     * @param _router The router
     * @param contractOwner The owner of the contract
     */
    function initialize(IRouter _router, address contractOwner) public initializer {
        router = _router;
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
        Worker[] memory workers = router.getWorkerMgt().getWorkersByIds(workerIds);
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
        DataInfo memory dataInfo = router.getDataMgt().checkAndGetPermittedDataById(dataId, msg.sender);
        require(dataInfo.dataId == dataId, "TaskMgt.submitTask: data does not exist");
        require(taskType == TaskType.DATA_SHARING, "TaskMgt.submitTask: TaskType must be DATA_SHARING");
        require(consumerPk.length > 0, "TaskMgt.submitTask: consumerPk can not be empty");

        PriceInfo memory priceInfo = dataInfo.priceInfo;
        bytes32[] memory workerIds = dataInfo.workerIds;
        EncryptionSchema memory encryptionSchema = dataInfo.encryptionSchema;

        require(dataInfo.status == DataStatus.REGISTERED, "TaskMgt.submitTask: data status is not REGISTERED");
        
        uint256 computingPrice = router.getFeeMgt().getFeeTokenBySymbol(priceInfo.tokenSymbol).computingPrice;
        require(computingPrice > 0, "TaskMgt.submitTask: computingPrice is not set");
        uint256 fee = priceInfo.price + workerIds.length * computingPrice;
        router.getFeeMgt().transferToken{value: msg.value}(msg.sender, priceInfo.tokenSymbol, fee);

        bytes32 taskId = keccak256(abi.encode(taskType, consumerPk, dataId, taskCount));
        taskCount++;
        bool[] memory hasReported = new bool[](dataInfo.workerIds.length);
        for (uint32 i = 0; i < hasReported.length; i++) {
            hasReported[i] = false;
        }

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
                hasReported: hasReported,
                reportCount: 0
            }),
            time: uint64(block.timestamp),
            status: TaskStatus.PENDING,
            submitter: msg.sender,
            code: new bytes(0)
        });

        _allTasks[taskId] = task;
        _pendingTaskIds.push(taskId);
        
        for (uint256 i = 0; i < workerIds.length; i++) {
            _pendingTaskIdForWorker[workerIds[i]].push(taskId);
        }
        router.getFeeMgt().lock(
            taskId,
            msg.sender,
            priceInfo.tokenSymbol,
            fee
        );
        emit TaskDispatched(taskId, workerIds);

        // update timeouted task
        updateTasks();

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
     * @return isFound and index Whether the element is found in the array,  index of the target element.
     */
    function _find(bytes32 target, bytes32[] memory array) internal pure returns (bool isFound, uint256 index) {
        index = type(uint256).max;
        isFound = false;

        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) {
                index = i;
                isFound = true;
                break;
            }
        }
    }

    /**
     * @notice settle fee.
     * @param taskId The id of task.
     */
    function _onTaskCompleted(bytes32 taskId) internal {
        Task storage task = _allTasks[taskId];
        DataInfo memory dataInfo = router.getDataMgt().getDataById(task.dataId);

        task.status = TaskStatus.COMPLETED;

        address[] memory dataProviders = new address[](1);
        dataProviders[0] = dataInfo.owner;
        
        router.getFeeMgt().settle(
            task.taskId,
            task.submitter,
            task.tokenSymbol,
            dataInfo.priceInfo.price,
            dataProviders
        );
        _popPendingTaskId(taskId);
        emit TaskCompleted(taskId);
    }

    /**
     * @notice unlock fee
     * @param taskId The task id
     */
    function _onTaskFailed(bytes32 taskId) internal {
        Task storage task = _allTasks[taskId];

        task.status = TaskStatus.FAILED;

        router.getFeeMgt().unlock(
            task.taskId,
            task.submitter,
            task.tokenSymbol
        );
        _popPendingTaskId(taskId);
        emit TaskFailed(taskId);
    }

    /**
     * @notice Worker report the computing result.
     * @param taskId The task id to which the result is associated.
     * @param workerId The worker id.
     * @param result The computing result content including zk proof, if the result is empty, then the task failed.
     * @return True if reporting is successful.
     */
    function reportResult(bytes32 taskId, bytes32 workerId, bytes calldata result) external returns (bool) {
        require(taskId != bytes32(0), "TaskMgt.reportResult: taskId can not be empty");
        Task storage task = _allTasks[taskId];
        Worker memory worker = router.getWorkerMgt().getWorkerById(workerId);
        require(msg.sender == worker.owner, "TaskMgt.reportResult: caller is not worker owner");
        require(task.taskId == taskId, "TaskMgt.reportResult: task does not exist");

        require(task.status == TaskStatus.PENDING, "TaskMgt.reportResult: task status is not PENDING");
        ComputingInfo storage computingInfo = task.computingInfo;

        (bool bWorker, uint256 workerIndex) = _find(workerId, computingInfo.workerIds);
        require(bWorker, "TaskMgt.reportResult: worker id not in computingInfo.workerIds");
        require(!computingInfo.hasReported[workerIndex], "TaskMgt.reportResult: worker has reported");
        computingInfo.results[workerIndex] = result;
        computingInfo.hasReported[workerIndex] = true;
        computingInfo.reportCount = computingInfo.reportCount + 1;
        
        _popPendingTaskIdForWorker(taskId, workerId);
        if (result.length > 0) {
            router.getFeeMgt().payWorker(taskId, task.submitter, worker.owner, task.tokenSymbol);
        }

        if (result.length == 0) {
            _onTaskFailed(taskId);
        }
        else if (computingInfo.reportCount == computingInfo.n) {
            _onTaskCompleted(taskId);
        }

        emit ResultReported(taskId, msg.sender);

        return true;
    }

    /**
     * @notice pop pending task id for worker
     * @param taskId The task id
     * @param workerId The worker id
     */
    function _popPendingTaskIdForWorker(bytes32 taskId, bytes32 workerId) internal {
        bytes32[] storage taskIds = _pendingTaskIdForWorker[workerId];
        (bool bTaskIdForWorker, uint256 taskIndex) = _find(taskId, taskIds);
        require(bTaskIdForWorker, "TaskMgt.reportResult: task id not in pendingTaskIdForWorker");
        taskIds[taskIndex] = taskIds[taskIds.length - 1];
        taskIds.pop();

    }

   /**
    * @notice pop pending task id
    * @param taskId The task id
    */
   function _popPendingTaskId(bytes32 taskId) internal {
       Task storage task = _allTasks[taskId];
       if (task.computingInfo.reportCount < task.computingInfo.workerIds.length) {
           ComputingInfo storage computingInfo = task.computingInfo;
           for (uint256 i = 0; i < computingInfo.workerIds.length; i++) {
               if (!computingInfo.hasReported[i]) {
                   _popPendingTaskIdForWorker(taskId, computingInfo.workerIds[i]);
               }
           }
       }

       (bool b, uint256 taskIndex) = _find(taskId, _pendingTaskIds);
       require(b, "TaskMgt._popPendingTaskId: can not find pending task id");

       _pendingTaskIds[taskIndex] = _pendingTaskIds[_pendingTaskIds.length - 1];
       _pendingTaskIds.pop();
   }

    /**
     * @notice Update task
     * @param taskId The task id.
     * @return Return task status.
     */
    function updateTask(bytes32 taskId) public returns (TaskStatus) {
        Task storage task = _allTasks[taskId];
        require(task.status == TaskStatus.PENDING, "TaskMgt.updateTask: task status is not pending");

        uint64 currentTime = uint64(block.timestamp);
        require(currentTime >= task.time + taskTimeout, "TaskMgt.updateTask: task is not timeout");


        DataInfo memory dataInfo = router.getDataMgt().getDataById(task.dataId);
        EncryptionSchema memory encryptionSchema = dataInfo.encryptionSchema;
        if (task.computingInfo.reportCount >= encryptionSchema.t) {
            _onTaskCompleted(taskId);
        }
        else {
            _onTaskFailed(taskId);
        }
        return task.status;
    }

    function updateTasks() public {
        if (_pendingTaskIds.length == 0) {
            return;
        }

        uint64 currentTime = uint64(block.timestamp);

        for (uint256 i = 0; i < _pendingTaskIds.length; i++) {
            bytes32 taskId = _pendingTaskIds[i];
            Task storage task = _allTasks[taskId];
            
            if (currentTime >= task.time + taskTimeout) {
                updateTask(taskId);
            }
        }
    }

    /**
     * @notice Get the tasks that a Worker needs to run.
     * @param workerId The Worker id.
     * @return Returns an array of tasks that the worker will run.
     */
    function getPendingTasksByWorkerId(bytes32 workerId) external view returns (Task[] memory) {
        bytes32[] storage taskIds = _pendingTaskIdForWorker[workerId];
        uint256 taskIdLength = taskIds.length;

        Task[] memory tasks = new Task[](taskIdLength);
        for (uint256 i = 0; i < taskIdLength; i++) {
            tasks[i] = _allTasks[taskIds[i]];
        }

        return tasks;
    }

    
    /**
     * @notice Get pending tasks.
     * @return Returns an array of pending tasks
     */
    function getPendingTasks() external view returns (Task[] memory) {
        Task[] memory tasks = new Task[](_pendingTaskIds.length);

        for (uint256 i = 0; i < _pendingTaskIds.length; i++) {
            tasks[i] = _allTasks[_pendingTaskIds[i]];
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

        require(task.computingInfo.reportCount >= task.computingInfo.t, "TaskMgt.getCompletedTaskById: not enough node report result");
        return task;
    }

    /**
     * @notice Get a task
     * @param taskId The task id
     * @return Returns The task
     */
    function getTaskById(bytes32 taskId) external view returns (Task memory){
        Task storage task = _allTasks[taskId];
        require(task.taskId == taskId, "TaskMgt.getTaskById: task does not exist");
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
    * @notice Update task report timeout.
    * @param timeout The task report timeout.
    */
   function updateTaskReportTimeout(uint64 timeout) external onlyOwner {
       taskTimeout = timeout;
       emit TaskReportTimeoutUpdated(timeout);
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

    /**
     * @notice updateRouter
     * @param _router The router
     */
    function updateRouter(IRouter _router) external onlyOwner {
        IRouter oldRouter = router;
        router = _router;
        emit RouterUpdated(oldRouter, _router);
    }
}
