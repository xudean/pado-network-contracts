// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @notice A struct representing computing request information related to the task.
 */
struct ComputingInfoRequest {
    uint256 price; // The computing price.
    uint32 t; // Threshold t.
    uint32 n; // Threshold n.
}

/**
 * @notice A struct representing a worker.
 */
struct Worker {
    bytes32 workerId; // The UID of the worker.
    WorkerType workerType; // The type of the worker.
    string name; // The worker name.
    string desc; // The worker description.
    uint256 stakeAmount; // The stake amount of the worker.
    address owner; // The worker owner.
    bytes publicKey; // The worker public key.
    uint64 time; // The worker registration time.
    WorkerStatus status; // The current status of the worker.
    uint64 sucTasksAmount; // The number of successfully executed tasks.
    uint64 failTasksAmount; // The number of failed tasks.
    uint256 delegationAmount; // The delegation amount of the worker.
}

enum WorkerType{
    EIGENLAYER, NATIVE
}

enum WorkerStatus{
    REGISTERED,UNREGISTERED
}
