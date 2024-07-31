// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import "./interface/IWorkerMgt.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";

import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IPauserRegistry} from "eigenlayer-contracts/src/contracts/interfaces/IPauserRegistry.sol";

contract PADORegistryCoordinator is RegistryCoordinator {
    IWorkerMgt public workerMgt;

    modifier onlyWorkerMgt() {
        require(
            msg.sender == address(workerMgt),
            "Only workerMgt"
        );
        _;
    }

    /**
     * @notice Constructor for the PADORegistryCoordinator contract.
     * @param _serviceManager The address of the ServiceManager contract.
     * @param _stakeRegistry The address of the StakeRegistry contract.
     * @param _blsApkRegistry The address of the BLSAPKRegistry contract.
     * @param _indexRegistry The address of the IndexRegistry contract.
     */
    constructor(
        IServiceManager _serviceManager,
        IStakeRegistry _stakeRegistry,
        IBLSApkRegistry _blsApkRegistry,
        IIndexRegistry _indexRegistry
    )
        RegistryCoordinator(
            _serviceManager,
            _stakeRegistry,
            _blsApkRegistry,
            _indexRegistry
        )
    {}

    /**
     * @param _initialOwner will hold the owner role
     * @param _churnApprover will hold the churnApprover role, which authorizes registering with churn
     * @param _ejector will hold the ejector role, which can force-eject operators from quorums
     * @param _pauserRegistry a registry of addresses that can pause the contract
     * @param _initialPausedStatus pause status after calling initialize
     * Config for initial quorums (see `createQuorum`):
     * @param _operatorSetParams max operator count and operator churn parameters
     * @param _minimumStakes minimum stake weight to allow an operator to register
     * @param _strategyParams which Strategies/multipliers a quorum considers when calculating stake weight
     * @param _workerMgt WorkerMgt contract
     */
    function initialize(
        address _initialOwner,
        address _churnApprover,
        address _ejector,
        IPauserRegistry _pauserRegistry,
        uint256 _initialPausedStatus,
        OperatorSetParam[] memory _operatorSetParams,
        uint96[] memory _minimumStakes,
        IStakeRegistry.StrategyParams[][] memory _strategyParams,
        IWorkerMgt _workerMgt
    ) external initializer {
        __RegistryCoordinator_init(
            _initialOwner,
            _churnApprover,
            _ejector,
            _pauserRegistry,
            _initialPausedStatus,
            _operatorSetParams,
            _minimumStakes,
            _strategyParams
        );
        workerMgt = _workerMgt;
    }

    /**
     * @notice Sets the workerMgt contract address.
     * @param _workerMgt The address of the workerMgt contract.
     */
    function setWorkerMgt(IWorkerMgt _workerMgt) external onlyOwner {
        workerMgt = _workerMgt;
    }

    /**
     * @notice Registers a worker with the registry coordinator.
     * @param quorumNumbers The quorum numbers associated with the worker.
     * @param socket The socket address of the worker.
     * @param params The parameters for registering the worker's BLS public key.
     * @param operatorSignature The signature of the operator.
     */
    function registerOperator(
        bytes calldata quorumNumbers,
        string calldata socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    )
        public
        override
        onlyWorkerMgt
        onlyWhenNotPaused(PAUSED_REGISTER_OPERATOR)
    {
        super.registerOperator(
            quorumNumbers,
            socket,
            params,
            operatorSignature
        );
    }

}
