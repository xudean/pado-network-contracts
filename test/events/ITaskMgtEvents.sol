
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
interface ITaskMgtEvents {
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
}
