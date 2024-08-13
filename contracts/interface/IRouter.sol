// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDataMgt} from "./IDataMgt.sol";
import {IFeeMgt} from "./IFeeMgt.sol";
import {ITaskMgt} from "./ITaskMgt.sol";
import {IWorkerMgt} from "./IWorkerMgt.sol";

/**
 * @title IRouter
 * @notice Router - Router interface
 */
interface IRouter {
    /**
     * @notice setDataMgt
     * @param dataMgt, The DataMgt.
     */
    function setDataMgt(IDataMgt dataMgt) external;

    /**
     * @notice getDataMgt
     * @return dataMgt, returns DataMgt.
     */
    function getDataMgt() external view returns (IDataMgt);

    /**
     * @notice setFeeMgt
     * @param feeMgt, The FeeMgt.
     */
    function setFeeMgt(IFeeMgt feeMgt) external;

    /**
     * @notice getFeeMgt
     * @return feeMgt, returns FeeMgt.
     */
    function getFeeMgt() external view returns (IFeeMgt);

    /**
     * @notice setTaskMgt
     * @param taskMgt, The TaskMgt
     */
    function setTaskMgt(ITaskMgt taskMgt) external;

    /**
     * @notice getTaskMgt
     * @return taskMgt, returns TaskMgt
     */
    function getTaskMgt() external view returns (ITaskMgt);

    /**
     * @notice setWorkerMgt
     * @param workerMgt The WorkerMgt 
     */
    function setWorkerMgt(IWorkerMgt workerMgt) external;

    /**
     * @notice getWorkerMgt
     * @return workerMgt, returns WorkerMgt
     */
    function getWorkerMgt() external view returns (IWorkerMgt);
}

/**
 * @title IRouterUpdater
 * @notice RouterUpdater - Router Updater interface
 */
interface IRouterUpdater {
    // emit in updateRouter
    event RouterUpdated(IRouter oldRouter, IRouter newRouter);

    /**
     * @notice updateRouter
     * @param router The router
     */
    function updateRouter(IRouter router) external;
}
