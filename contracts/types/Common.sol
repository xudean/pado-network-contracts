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

enum WorkerType {
    EIGENLAYER,
    NATIVE
}

enum WorkerStatus {
    REGISTERED,
    UNREGISTERED
}

/**
 * @notice A enum representing all task type
 */
enum TaskType {
    DATA_SHARING
}

/**
 * @notice A struct representing a concrete price of a piece of data
 */
struct PriceInfo {
    string tokenSymbol; // The token symbol of price
    uint256 price;  // The price of data 
}

/**
 * @notice A enum representing data staus
 */
enum DataStatus {
    REGISTERING,
    REGISTERED,
    DELETED
}

/**
 * @notice A struct representing a piece of data
 */
struct EncryptionSchema {
    uint32 t; // threshold
    uint32 n; // total amount of nodes
}

/**
 * @notice A struct representing a piece of data
 */
struct DataInfo {
    bytes32 dataId; // The identifier of the data
    string dataTag; // The tag of the data
    PriceInfo priceInfo; // The price of the data
    bytes dataContent; // The content of the data
    EncryptionSchema encryptionSchema; // The encryption schema
    bytes32[] workerIds; // The workerIds of workers participanting in  encrypting the data
    uint64 registeredTimestamp; // The timestamp at which the data was registered
    address owner; // The owner of the data
    DataStatus status; // The status of the data
}

/**
 * @notice A struct representing a fee token symbol and address.
 */
struct FeeTokenInfo {
    string symbol; // Fee token symbol.
    address tokenAddress; // Fee token address.
    uint256 computingPrice; // computing price.
}
/**
 * @notice A struct representing allowance for data user.
 */
struct Allowance {
    uint256 free;
    uint256 locked;
}

/**
 * @notice A enum representing all task status.
 */
enum TaskStatus {
    EMPTY_DATA,
    PENDING,
    COMPLETED,
    FAILED
}

/**
 * @notice A enum representing all task report status.
 */
enum TaskReportStatus {
    COMPLETED,
    WAITING,
    TIMEOUT
}

/**
 * @notice A struct representing a single task.
 */
struct Task {
    bytes32 taskId; // The UID of the task.
    TaskType taskType; // The type of the task.
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
