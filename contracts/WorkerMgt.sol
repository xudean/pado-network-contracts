// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWorkerMgt} from "./interface/IWorkerMgt.sol";
import {ComputingInfoRequest, WorkerType, Worker, WorkerStatus} from "./types/Common.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

contract WorkerMgt is IWorkerMgt, OwnableUpgradeable {
    event WorkerRegistry(
        uint32[] taskTypes,
        bytes32 publicKey,
        bytes quorumNumbers,
        string socket
    );
    RegistryCoordinator public  registryCoordinator;
    mapping(bytes32 => Worker) public workers;
    mapping(bytes32 => bytes32[]) public dataEncryptedByWorkers;
    bytes32[] public workerIds;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        RegistryCoordinator _registryCoordinator
    ) external initializer {
        registryCoordinator = _registryCoordinator;
        __Ownable_init();
    }

    /**
     * @notice Worker register.
     * @param name The worker name.
     * @param desc The worker description.
     * @param taskTypes The types of tasks that the worker can run.
     * @param publicKey The worker public key.
     * @param stakeAmount The stake amount of the worker.
     * @return If the registration is successful, the worker id is returned.
     */
    function register(
        string calldata name,
        string calldata desc,
        uint32[] calldata taskTypes,
        bytes[] calldata publicKey,
        uint256 stakeAmount
    ) external payable returns (bytes32) {}

    /**
     * @notice Register EigenLayer's operator.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     */
    function registerEigenOperator(
        uint32[] calldata taskTypes,
        bytes[] calldata publicKey,
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        bytes32 workerUniqueId = keccak256(abi.encodePacked(publicKey[0]));
        require(
            !checkWorkerRegistered(workerUniqueId),
            "worker has already registered"
        );
        //registry to eigenlayer
        registryCoordinator.registerOperator(
            quorumNumbers,
            socket,
            params,
            operatorSignature
        );
        //build worker
        Worker memory worker = Worker({
            workerId: workerUniqueId,
            workerType: WorkerType.EIGENLAYER,
            name: "",
            desc: "",
            stakeAmount: 0,
            owner: msg.sender,
            publicKey: publicKey[0],
            time: uint64(block.timestamp),
            status: WorkerStatus.REGISTERED,
            sucTasksAmount: 0,
            failTasksAmount: 0,
            delegationAmount: 0
        });
        workers[workerUniqueId] = worker;
        workerIds.push(workerUniqueId);
        emit WorkerRegistry(taskTypes, workerUniqueId, quorumNumbers, socket);
    }

    /**
     * @notice TaskMgt contract request selecting workers which will run the task.
     * @param taskId The task id.
     * @param taskType The type of the task.
     * @param computingInfoRequest The computing info about the task.
     * @return Returns true if the request is successful.
     */
    function selectTaskWorkers(
        bytes32 taskId,
        uint32 taskType,
        ComputingInfoRequest calldata computingInfoRequest
    ) external returns (bool) {
        //select workers
    }

    /**
     * @notice DataMgt contract request selecting workers which will encrypt data and run the task.
     * @param dataId The data id.
     * @param t Threshold t.
     * @param n Threshold n.
     * @return Returns true if the request is successful.
     */
    function selectMultiplePublicKeyWorkers(
        bytes32 dataId,
        uint32 t,
        uint32 n
    ) external returns (bool) {}

    /**
     * @notice Get wokers whose public keys will be used to encrypt data.
     * @param dataId The data id.
     * @return Returns the array of worker id.
     */
    function getMultiplePublicKeyWorkers(
        bytes32 dataId
    ) external view returns (bytes32[] memory) {}

    /**
     * @notice Get workers which will run the task.
     * @param taskId The task id.
     * @return Returns the array of worker id.
     */
    function getTaskWorkers(
        bytes32 taskId
    ) external view returns (bytes32[] memory) {}

    /**
     * @notice Get data encryption public key of the task.
     * @param taskId The task id.
     * @return Returns data encryption public key.
     */
    function getTaskEncryptionPublicKey(
        bytes32 taskId
    ) external view returns (bytes memory) {}

    /**
     * @notice Update worker info.
     * @param name The worker name, name can't be updated.
     * @param desc The new value of description you want to modify, empty value means no modification is required.
     * @param taskTypes The new value of taskTypes, the array length 0 means no modification is required.
     * @return Returns true if the updating is successful.
     */
    function update(
        string calldata name,
        string calldata desc,
        uint32[] calldata taskTypes
    ) external returns (bool) {}

    /**
     * @notice Delete worker from network.
     * @param name The name of the worker to be deleted.
     * @return Returns true if the deleting is successful.
     */
    function deleteWorker(string calldata name) external returns (bool) {}

    /**
     * @notice Get worker by id.
     * @param workerId The worker id.
     * @return Returns the worker.
     */
    function getWorkerById(
        bytes32 workerId
    ) external view returns (Worker memory) {}

    /**
     * @notice Get worker by name.
     * @param workerName The worker name.
     * @return Returns the worker.
     */
    function getWorkerByName(
        string calldata workerName
    ) external view returns (Worker memory) {}

    /**
     * @notice Get all workers.
     * @return Returns all workers.
     */
    function getWorkers() external view returns (Worker[] memory) {}

    /**
     * @notice User delegate some token to a worker.
     * @param workerId The worker id to delegate.
     * @param delegateAmount The delegate amount.
     * @return Returns true if the delegating is successful.
     */
    function delegate(
        bytes32 workerId,
        uint256 delegateAmount
    ) external payable returns (bool) {}

    /**
     * @notice User cancel delegating to a worker.
     * @param workerId The worker id to cancel delegating.
     * @return Returns true if the canceling is successful.
     */
    function unDelegate(bytes32 workerId) external returns (bool) {}

    /**
     * @notice Get Workers by delegator address.
     * @param delegator The delegator address.
     * @return Returns all workers id of the user delegating.
     */
    function getWorkersByDelegator(
        address delegator
    ) external view returns (bytes32[] memory) {}

    /**
     * @notice Get delegators by worker id.
     * @param workerId The worker id.
     * @return Returns all delegators address of the worker having.
     */
    function getDelegatorsByWorker(
        bytes32 workerId
    ) external view returns (address[] memory) {}

    //==============================helper function======================
    function checkWorkerRegistered(
        bytes32 _workerId
    ) public view returns (bool) {
        return workers[_workerId].workerId == _workerId;
    }
}
