// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ComputingInfoRequest } from "../types/Common.sol";

/**
 * @notice A enum representing all task status.
 */
enum TaskStatus {
    NEVER_USED,
    EMPTY_DATA,
    PENDING,
    COMPLETED,
    FAILED
}

/**
 * @notice A struct representing a single task.
 */
struct Task {
    bytes32 taskId; // The UID of the task.
    uint32 taskType; // The type of the task.
    bytes consumerPk; // The Public Key of the Network Consumer.
    string tokenSymbol; // The token symbol of data and computing fee.
    bytes32 dataId; // The id of the data
    TaskDataInfo dataInfo; // Data information related to the task.
    ComputingInfo computingInfo; // Computing information related to the task.
    uint64 time; // The time of the task submission.
    TaskStatus status; // The status of the task.
    address submitter; // The submitter of the task.
    bytes code; // The task code to run, the field can empty.
}

/**
 * @notice A struct representing data information related to the task.
 */
struct TaskDataInfo {
    bytes dataEncryptionPk; // The data encryption Public Key.
    uint256 price; // The data pice.
    address[] dataProviders; // The address array of data providers related to the task.
    bytes[] data; // Data Providers provides data array. 
}

/**
 * @notice A struct representing computing information related to the task.
 */
struct ComputingInfo {
    uint256 price; // The computing price.
    uint32 t; // Threshold t.
    uint32 n; // Threshold n.
    bytes32[] workerIds; // An array of worker ids that compute the task.
    bytes[] results; // The workers' results of the task.
    bytes32[] waitingList; // The workers should report.
}

/**
 * @notice A struct representing data request information related to the task.
 */
struct TaskDataInfoRequest {
    uint256 price; // The data pice.
    string dataDescription; // Description of the data required.
    uint32 dataInputAmount; // The amount of data required.
}

/**
 * @title ITaskMgt
 * @notice TaskMgt - Task Management interface.
 */
interface ITaskMgt {
    // emit in submit
    event TaskDispatched(bytes32 indexed taskId, bytes32[] workerIds);

    // emit in report result
    event ResultReported(bytes32 indexed taskId, address indexed worker);

    // emit when task completed
    event TaskCompleted(bytes32 indexed taskId);
    function receiveETH() payable external;
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
    ) external payable returns (bytes32);

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
    ) external payable returns (bytes32);

    /**
     * @notice Data Provider submit data to task.
     * @param taskId The task id to which the data is associated.
     * @param data The content of the data can be the transaction ID of the storage chain.
     * @return True if submission is successful.
     */
    function submitTaskData(bytes32 taskId, bytes calldata data) external returns (bool);

    /**
     * @notice Worker report the computing result.
     * @param taskId The task id to which the result is associated.
     * @param result The computing result content including zk proof.
     * @return True if reporting is successful.
     */
    function reportResult(bytes32 taskId, bytes calldata result) external returns (bool);

    /**
     * @notice Get the tasks that need to be run by Workers.
     * @return Returns an array of tasks that the workers will run.
     */
    function getPendingTasks() external view returns (Task[] memory);

    /**
     * @notice Get the tasks that a Worker needs to run.
     * @param workerId The Worker id.
     * @return Returns an array of tasks that the worker will run.
     */
    function getPendingTasksByWorkerId(bytes32 workerId) external view returns (Task[] memory);

    /**
     * @notice Get a completed task.
     * @param taskId The task id.
     * @return Returns The completed task.
     */
    function getCompletedTaskById(bytes32 taskId) external view returns (Task memory);

    /**
     * @notice Set a data verification contract of a task type.
     * @param taskType The type of task.
     * @param dataVerifier The data verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setDataVerifier(uint32 taskType, address dataVerifier) external returns (bool);

    /**
     * @notice Set a result verification contract of a task type.
     * @param taskType The type of task.
     * @param resultVerifier The result verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setResultVerifier(uint32 taskType, address resultVerifier) external returns (bool);
}
