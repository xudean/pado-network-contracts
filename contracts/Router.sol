// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IDataMgt} from "./interface/IDataMgt.sol";
import {IFeeMgt} from "./interface/IFeeMgt.sol";
import {ITaskMgt} from "./interface/ITaskMgt.sol";
import {IWorkerMgt} from "./interface/IWorkerMgt.sol";
import {IRouter} from "./interface/IRouter.sol";

/**
 * @title Router
 * @notice Router - Router contract
 */
contract Router is IRouter, OwnableUpgradeable {
    // DataMgt
    IDataMgt private _dataMgt;

    // FeeMgt
    IFeeMgt private _feeMgt;

    // TaskMgt
    ITaskMgt private _taskMgt;

    // WorkerMgt
    IWorkerMgt private _workerMgt;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the router contract
     * @param dataMgt The DataMgt
     * @param feeMgt The FeeMgt
     * @param taskMgt The TaskMgt
     * @param workerMgt The WorkerMgt
     * @param contractOwner The owner of the contract
     */
    function initialize(
        IDataMgt dataMgt,
        IFeeMgt feeMgt,
        ITaskMgt taskMgt,
        IWorkerMgt workerMgt,
        address contractOwner
    ) external initializer {
        _dataMgt = dataMgt;
        _feeMgt = feeMgt;
        _taskMgt = taskMgt;
        _workerMgt = workerMgt;
        _transferOwnership(contractOwner);
    }

    /**
     * @notice setDataMgt
     * @param dataMgt, The DataMgt.
     */
    function setDataMgt(IDataMgt dataMgt) external onlyOwner {
        _dataMgt = dataMgt;
    }

    /**
     * @notice getDataMgt
     * @return dataMgt, returns DataMgt.
     */
    function getDataMgt() external view returns (IDataMgt) {
        return _dataMgt;
    }

    /**
     * @notice setFeeMgt
     * @param feeMgt, The FeeMgt.
     */
    function setFeeMgt(IFeeMgt feeMgt) external onlyOwner {
        _feeMgt = feeMgt;
    }

    /**
     * @notice getFeeMgt
     * @return feeMgt, returns FeeMgt.
     */
    function getFeeMgt() external view returns (IFeeMgt) {
        return _feeMgt;
    }

    /**
     * @notice setTaskMgt
     * @param taskMgt, The TaskMgt
     */
    function setTaskMgt(ITaskMgt taskMgt) external onlyOwner {
        _taskMgt = taskMgt;
    }

    /**
     * @notice getTaskMgt
     * @return taskMgt, returns TaskMgt
     */
    function getTaskMgt() external view returns (ITaskMgt) {
        return _taskMgt;
    }

    /**
     * @notice setWorkerMgt
     * @param workerMgt The WorkerMgt. 
     */
    function setWorkerMgt(IWorkerMgt workerMgt) external onlyOwner {
        _workerMgt = workerMgt;
    }

    /**
     * @notice getWorkerMgt
     * @return workerMgt, returns WorkerMgt
     */
    function getWorkerMgt() external view returns (IWorkerMgt) {
        return _workerMgt;
    }
}
