// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IWorkerMgt} from "./interface/IWorkerMgt.sol";
import {ComputingInfoRequest, WorkerType, Worker, WorkerStatus, TaskType} from "./types/Common.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
// import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "./PADORegistryCoordinator.sol";

contract WorkerMgt is IWorkerMgt, OwnableUpgradeable {
    event WorkerRegistry(
        bytes32 indexed workerId,
        WorkerType workerType,
        address owner
    );
    event WorkerDeregistry(bytes32 indexed workerId);
    event SelectDataWorkers(bytes32 indexed dataId, bytes32[] workerIds);

    PADORegistryCoordinator public registryCoordinator;
    mapping(bytes32 => Worker) public workers;
    mapping(bytes32 => bytes32[]) public workersToEncryptData;
    bytes32[] public workerIds;
    mapping(address => uint32) addressNonce;
    mapping(address => bool) public workerWhiteList;
    address public dataMgtAddr;

    modifier onlyWhiteListedWorker(address worker) {
        require(
            workerWhiteList[worker],
            "workerWhiteList: worker not in whitelist"
        );
        _;
    }

    modifier onlyDataMgt() {
        require(
            msg.sender == dataMgtAddr,
            "only dataMgt can call this function"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        PADORegistryCoordinator _registryCoordinator,
        address _dataMgtAddr,
        address networkOwner
    ) external initializer {
        registryCoordinator = _registryCoordinator;
        dataMgtAddr = _dataMgtAddr;
        _transferOwnership(networkOwner);
    }

    /**
     * @notice Set the address of the data management contract.
     * @param _dataMgtAddr The address of the data management contract.
     */
    function setDataMgtAddr(address _dataMgtAddr) external onlyOwner {
        dataMgtAddr = _dataMgtAddr;
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
    ) external payable returns (bytes32) {}

    /**
     * @notice Register EigenLayer's operator.
     * @param taskTypes The types of tasks that the worker can run.
     * @param publicKey The transaction id which worker public key  saved in arseeding.
     * @param quorumNumbers The quorum numbers.
     * @param socket The socket address.
     * @param params The parameters of the operator's signature.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     */
    function registerEigenOperator(
        TaskType[] calldata taskTypes,
        bytes[] calldata publicKey,
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external onlyWhiteListedWorker(msg.sender) returns (bytes32) {
        _checkWorkerParam(
            taskTypes,
            publicKey,
            quorumNumbers,
            socket,
            params,
            operatorSignature
        );
        if (address(registryCoordinator) == address(0)) {
            revert("registryCoordinator not set!");
        }
        //result is operatorId,check whether operator has registried to eigenlayer.operatorId is same as workerId
        IRegistryCoordinator.OperatorInfo
            memory operatorInfo = registryCoordinator.getOperator(msg.sender);
        bytes32 operatorId = operatorInfo.operatorId;
        if (
            operatorId == bytes32(0) ||
            operatorInfo.status !=
            IRegistryCoordinator.OperatorStatus.REGISTERED
        ) {
            operatorId = BN254.hashG1Point(params.pubkeyG1);
            //build worker
            Worker memory worker = Worker({
                workerId: operatorId,
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
            workers[operatorId] = worker;
            workerIds.push(operatorId);
        }
        // Handle the case where operatorId is not register
        registryCoordinator.registerOperator(
            msg.sender,
            quorumNumbers,
            socket,
            params,
            operatorSignature
        );
        emit WorkerRegistry(
            operatorId,
            workers[operatorId].workerType,
            workers[operatorId].owner
        );
        return operatorId;
    }

    /**
     * @notice Deregisters the caller from one or more quorums
     * @param quorumNumbers is an ordered byte array containing the quorum numbers being deregistered from
     */
    function deregisterOperator(
        bytes calldata quorumNumbers
    ) external returns (bool) {
        registryCoordinator.deregisterOperator(msg.sender, quorumNumbers);
        IRegistryCoordinator.OperatorInfo
            memory operatorInfo = registryCoordinator.getOperator(msg.sender);
        if (
            operatorInfo.status ==
            IRegistryCoordinator.OperatorStatus.DEREGISTERED
        ) {
            //update worker status
            workers[operatorInfo.operatorId].status = WorkerStatus.UNREGISTERED;
            //remove from workerIds
            _removeWorkerId(operatorInfo.operatorId);

            emit WorkerDeregistry(operatorInfo.operatorId);
        }
        return true;
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
    ) external onlyDataMgt returns (bool) {
        workersToEncryptData[dataId] = _selectWorkers(n);
        emit SelectDataWorkers(dataId, workersToEncryptData[dataId]);
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
        return workersToEncryptData[dataId];
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
        return workers[workerId];
    }

    /**
     * @notice Get workers by ids.
     * @param workerids The id of workers
     * @return Returns The workers
     */
    function getWorkersByIds(
        bytes32[] calldata workerids
    ) external view returns (Worker[] memory) {
        uint256 workerIdLength = workerids.length;
        Worker[] memory result = new Worker[](workerIdLength);

        for (uint256 i = 0; i < workerIdLength; i++) {
            require(
                workers[workerids[i]].workerId == workerids[i],
                "WorkerMgt.getWorkersByIds: invalid worker id"
            );
            result[i] = workers[workerids[i]];
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
    ) external view returns (Worker memory) {}

    /**
     * @notice Get all workers.
     * @return Returns all workers.
     */
    function getWorkers() external view returns (Worker[] memory) {
        Worker[] memory _workers = new Worker[](workerIds.length);
        for (uint256 i = 0; i < workerIds.length; i++) {
            _workers[i] = workers[workerIds[i]];
        }
        return _workers;
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
    function addWhiteListItem(address _address) external onlyOwner {
        workerWhiteList[_address] = true;
    }

    /**
     * @notice Remove white list item.
     * @param _address The address to remove.
     */
    function removeWhiteListItem(address _address) external onlyOwner {
        workerWhiteList[_address] = false;
    }

    /**
     * @notice Get version.
     */
    function version() external pure returns (uint256) {
        return 1;
    }

    //==============================helper function======================
    /**
     * @notice Check whether the worker is registered.
     * @param _workerId The worker id.
     * @return Returns true if the worker is registered.
     */
    function checkWorkerRegistered(
        bytes32 _workerId
    ) public view returns (bool) {
        return workers[_workerId].workerId == _workerId;
    }

    //==============================internal function====================
    /**
     * @notice Check whether the worker parameters are valid.
     * @param taskTypes The task types.
     * @param publicKey The public key.
     * @param quorumNumbers The quorum numbers.
     * @param socket The socket.
     * @param params The public key registration params.
     * @param operatorSignature The operator signature.
     */
    function _checkWorkerParam(
        TaskType[] calldata taskTypes,
        bytes[] calldata publicKey,
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) internal {
        require(taskTypes.length > 0, "Task types can't be empty");
        require(publicKey.length > 0, "publicKeys can't be empty");
    }

    /**
     * @notice Get a random number.
     * @return Returns a random number.
     */
    function _getRandomNumber() internal returns (uint256) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                addressNonce[msg.sender]
            )
        );
        //This operation consumes some gas but guarantees the quality of the random numbers generated.
        addressNonce[msg.sender] = addressNonce[msg.sender] + 1;
        return uint256(hash);
    }

    /**
     * @notice Select workers randomly.
     * @param n The number of workers to select.
     * @return Returns the selected workers.
     */
    function _selectWorkers(uint256 n) internal returns (bytes32[] memory) {
        require(
            workerIds.length >= n,
            "Not enough workers to provide computation"
        );

        //generate a random number
        uint256 randomness = _getRandomNumber();

        uint256[] memory indices = new uint256[](workerIds.length);
        for (uint256 i = 0; i < workerIds.length; i++) {
            indices[i] = i;
        }

        // Fisher-Yates shuffle algorithm
        for (uint256 i = 0; i < n; i++) {
            uint256 j = i + (randomness % (workerIds.length - i));
            (indices[i], indices[j]) = (indices[j], indices[i]);
            randomness = uint256(keccak256(abi.encodePacked(randomness, i)));
        }
        bytes32[] memory selectedWorkers = new bytes32[](n);
        // Select the first n indices
        for (uint256 i = 0; i < n; i++) {
            //save workerId
            selectedWorkers[i] = workerIds[indices[i]];
        }
        return selectedWorkers;
    }

    //-----------------remove element in workerIds-------------------
    function _removeWorkerId(bytes32 id) internal {
        uint256 index = _findIndex(id);
        if (index == workerIds.length) {
            return; // Not found
        }
        _removeAtIndex(index);
    }
    /**
     * get index of worker
     * @param id The worker id.
     */
    function _findIndex(bytes32 id) internal view returns (uint256) {
        for (uint256 i = 0; i < workerIds.length; i++) {
            if (workerIds[i] == id) {
                return i;
            }
        }
        return workerIds.length; // Not found
    }

    /**
     * @notice Remove a worker from the workerIds array.
     * @param index The index of the worker to remove.
     */
    function _removeAtIndex(uint256 index) internal {
        require(index < workerIds.length, "Index out of bounds");
        // replace value with the latest element
        if (index < workerIds.length - 1) {
            workerIds[index] = workerIds[workerIds.length - 1];
        }
        // reduce the array size
        workerIds.pop();
    }
    //-------------------------------------------------------------------
}
