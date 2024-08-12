// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {Worker, WorkerStatus, WorkerType, ComputingInfoRequest, Worker, TaskType} from "../../contracts/types/Common.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IWorkerMgt} from "../../contracts/interface/IWorkerMgt.sol";

/**
 * @title WorkerMgtMock
 * @notice WorkerMgt - Worker Management Mock.
 */
contract WorkerMgtMock is IWorkerMgt, OwnableUpgradeable {
    uint256 private _workerCount;

    mapping(bytes32 workerId => Worker worker) private _allWorkers;
    bytes32[] public _workerIds;

    mapping(bytes32 dataId => bytes32[] workerIds) private _workerIdForDataId;

    mapping(address workerAddr => bytes32 workerId) private _addressWorkerId;
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        _workerCount = 0;
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
        TaskType[] calldata taskTypes,
        bytes[] calldata publicKey,
        uint256 stakeAmount
    ) external payable returns (bytes32) {
        require(taskTypes.length == publicKey.length);
        bytes32 workerId = keccak256(abi.encode(name, desc, _workerCount));
        _workerCount++;

        Worker memory worker = Worker({
            workerId: workerId,
            workerType: WorkerType.NATIVE,
            name: name,
            desc: desc,
            stakeAmount: stakeAmount,
            owner: msg.sender,
            publicKey: publicKey[0],
            time: uint64(block.timestamp),
            status: WorkerStatus.REGISTERED,
            sucTasksAmount: 0,
            failTasksAmount: 0,
            delegationAmount: 0
        });
        _allWorkers[workerId] = worker;
        _workerIds.push(workerId);
        _addressWorkerId[msg.sender]=workerId;
        return workerId;
    }

    /**
     * @notice Register EigenLayer's operator.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     */
    function registerEigenOperator(
        TaskType[] calldata taskTypes,
        bytes[] calldata publicKey,
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external returns (bytes32) {}

    /**
     * @notice TaskMgt contract request selecting workers which will run the task.
     * @param taskId The task id.
     * @param taskType The type of the task.
     * @param computingInfoRequest The computing info about the task.
     * @return Returns true if the request is successful.
     */
    function selectTaskWorkers(
        bytes32 taskId,
        TaskType taskType,
        ComputingInfoRequest calldata computingInfoRequest
    ) external returns (bool) {}

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
    ) external returns (bool) {
        require(t > 0 && t < n);
        require(_workerIds.length >= n, "not enough workers");

        bytes32[] memory workerIds = new bytes32[](n);
        for (uint32 i = 0; i < n; i++) {
            workerIds[i] = _workerIds[i];
        }

        _workerIdForDataId[dataId] = workerIds;
        return true;
    }

    /**
     * @notice Get wokers whose public keys will be used to encrypt data.
     * @param dataId The data id.
     * @return Returns the array of worker id.
     */
    function getMultiplePublicKeyWorkers(
        bytes32 dataId
    ) external view returns (bytes32[] memory) {
        require(
            _workerIdForDataId[dataId].length > 0,
            "workerIdForDataId not found"
        );
        return _workerIdForDataId[dataId];
    }

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
        TaskType[] calldata taskTypes
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
    ) external view returns (Worker memory) {
        Worker memory worker = _allWorkers[workerId];
        require(worker.workerId == workerId, "worker does not exist");
        return worker;
    }

    /**
     * @notice Get workers by ids.
     * @param workerIds The id of workers
     * @return Returns The workers
     */
    function getWorkersByIds(
        bytes32[] calldata workerIds
    ) external view returns (Worker[] memory) {
        uint256 workerIdLength = workerIds.length;
        Worker[] memory result = new Worker[](workerIdLength);

        for (uint256 i = 0; i < workerIdLength; i++) {
            require(
                _allWorkers[workerIds[i]].workerId == workerIds[i],
                "WorkerMgtMock.getWorkersByIds: invalid worker id"
            );
            result[i] = _allWorkers[workerIds[i]];
        }
        return result;
    }

    /**
     * @notice Get worker by name.
     * @param workerName The worker name.
     * @return Returns the worker.
     */
    function getWorkerByName(
        string calldata workerName
    ) external view returns (Worker memory) {
        uint256 workerIdLength = _workerIds.length;
        for (uint256 i = 0; i < workerIdLength; i++) {
            if (_strEq(_allWorkers[_workerIds[i]].name, workerName)) {
                return _allWorkers[_workerIds[i]];
            }
        }
        revert("worker not found");
    }

    /**
     * @notice Get all workers.
     * @return Returns all workers.
     */
    function getWorkers() external view returns (Worker[] memory) {
        uint256 workerIdLength = _workerIds.length;
        Worker[] memory workers = new Worker[](workerIdLength);

        for (uint256 i = 0; i < workerIdLength; i++) {
            workers[i] = _allWorkers[_workerIds[i]];
        }
        return workers;
    }

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

    /**
     * @notice Add white list item.
     * @param _address The address to add.
     */
    function addWhiteListItem(address _address) external {}

    /**
     * @notice Remove white list item.
     * @param _address The address to remove.
     */
    function removeWhiteListItem(address _address) external {}

    function _strEq(
        string memory s1,
        string memory s2
    ) internal pure returns (bool) {
        return keccak256(bytes(s1)) == keccak256(bytes(s2));
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getAllIds() external view returns (bytes32[] memory) {
        return _workerIds;
    }

    function deregisterOperator(
        bytes calldata quorumNumbers
    ) external override returns (bool) {
        bytes32 workerId = _addressWorkerId[msg.sender];
        _allWorkers[workerId].status = WorkerStatus.UNREGISTERED;
        //remove from workerIds
        _removeWorkerId(workerId);
    }

    //-----------------remove element in _workerIds-------------------
    function _removeWorkerId(bytes32 id) internal {
        uint256 index = _findIndex(id);
        if (index == _workerIds.length) {
            return; // Not found
        }
        _removeAtIndex(index);
    }
    /**
     * get index of worker
     * @param id The worker id.
     */
    function _findIndex(bytes32 id) internal view returns (uint256) {
        for (uint256 i = 0; i < _workerIds.length; i++) {
            if (_workerIds[i] == id) {
                return i;
            }
        }
        return _workerIds.length; // Not found
    }

    /**
     * @notice Remove a worker from the workerIds array.
     * @param index The index of the worker to remove.
     */
    function _removeAtIndex(uint256 index) internal {
        require(index < _workerIds.length, "Index out of bounds");
        // replace value with the latest element
        if (index < _workerIds.length - 1) {
            _workerIds[index] = _workerIds[_workerIds.length - 1];
        }
        // reduce the array size
        _workerIds.pop();
    }
    //-------------------------------------------------------------------
}
