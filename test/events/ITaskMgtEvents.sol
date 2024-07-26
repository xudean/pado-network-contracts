
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
interface ITaskMgtEvents {
    event WorkerReceiveTask(bytes32 indexed workerId, bytes32 indexed taskId);
    event TaskCompleted(bytes32 taskId);
}
