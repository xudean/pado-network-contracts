// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ComputingInfoRequest, TaskType, TaskStatus, Task, TaskDataInfo, ComputingInfo, TaskDataInfoRequest, TaskReportStatus } from "../types/Common.sol";

/**
 * @title ITaskMgt
 * @notice TaskMgt - Task Management interface.
 */
interface ITaskMgt {
    // emit in submit
    event TaskDispatched(bytes32 indexed taskId, bytes32[] workerIds);

    // emit in report result
    event ResultReported(bytes32 indexed taskId, address worker);

    // emit when task completed
    event TaskCompleted(bytes32 indexed taskId);

    // emit when task failed
    event TaskFailed(bytes32 indexed taskId);

    // emit when task report timeout updated
    event TaskReportTimeoutUpdated(uint64 timeout);

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
    ) external payable returns (bytes32);

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
     * @param workerId The worker id.
     * @param result The computing result content including zk proof.
     * @return True if reporting is successful.
     */
    function reportResult(bytes32 taskId, bytes32 workerId, bytes calldata result) external returns (bool);

    /**
     * @notice Update task
     * @param taskId The task id.
     * @return Return task status.
     */
    function updateTask(bytes32 taskId) external returns (TaskStatus);

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
    * @notice Get task report status.
    * @param taskId The task id.
    * @return Returns The task report status.
    */
   function getTaskReportStatus(bytes32 taskId) external view returns (TaskReportStatus);

   /**
    * @notice Update task report timeout.
    * @param timeout The task report timeout.
    */
   function updateTaskReportTimeout(uint64 timeout) external;

    /**
     * @notice Set a data verification contract of a task type.
     * @param taskType The type of task.
     * @param dataVerifier The data verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setDataVerifier(TaskType taskType, address dataVerifier) external returns (bool);

    /**
     * @notice Set a result verification contract of a task type.
     * @param taskType The type of task.
     * @param resultVerifier The result verification contract address.
     * @return Returns true if the setting is successful.
     */
    function setResultVerifier(TaskType taskType, address resultVerifier) external returns (bool);
}
