// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IDataMgt} from "./interface/IDataMgt.sol"; 
import {IWorkerMgt} from "./interface/IWorkerMgt.sol";
import {IRouter, IRouterUpdater} from "./interface/IRouter.sol";
import {IDataPermission} from "./interface/IDataPermission.sol";
import {Worker, DataStatus, DataInfo, PriceInfo, EncryptionSchema} from "./types/Common.sol";

/**
 * @title DataMgt
 * @notice DataMgt - Data Management Contract.
 */
contract DataMgt is IDataMgt, IRouterUpdater, OwnableUpgradeable {
    // registry count
    uint256 public registryCount;

    // The router 
    IRouter public router;

    // dataId => dataInfo
    mapping(bytes32 dataId => DataInfo dataInfo) private _dataInfos;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the data management
     * @param _router The router
     * @param contractOwner The owner of the contract
     */
    function initialize(IRouter _router, address contractOwner) external initializer {
        router = _router;
        registryCount = 0;
        _transferOwnership(contractOwner);
    }

    /**
     * @notice Data Provider prepare to register confidential data to PADO Network.
     * @param encryptionSchema EncryptionSchema
     * @return dataId and publicKeys data id and public keys
     */
    function prepareRegistry(
        EncryptionSchema calldata encryptionSchema
    ) external returns (bytes32 dataId, bytes[] memory publicKeys) {
        require(encryptionSchema.t > 1, "DataMgt.prepareRegistry: t must be greater then one");
        require(encryptionSchema.t <= encryptionSchema.n, "DataMgt.prepareRegistry: t must be less then or equal to n");
        dataId = keccak256(abi.encode(encryptionSchema, registryCount));
        registryCount++;

        IWorkerMgt workerMgt = router.getWorkerMgt();

        bool res = workerMgt.selectMultiplePublicKeyWorkers(
            dataId,
            encryptionSchema.t,
            encryptionSchema.n
        );
        require(res, "DataMgt.prepareRegistry: select multiple public key workers error");
        bytes32[] memory workerIds = workerMgt.getMultiplePublicKeyWorkers(dataId);
        require(workerIds.length == encryptionSchema.n, "DataMgt.prepareRegistry: get multiple public key workers error");
        
        Worker[] memory workers = workerMgt.getWorkersByIds(workerIds);
        publicKeys = new bytes[](workerIds.length);
        for (uint256 i = 0; i < workerIds.length; i++) {
            publicKeys[i] = workers[i].publicKey;
        }

        DataInfo memory dataInfo = DataInfo({
            dataId: dataId,
            dataTag: "",
            priceInfo: PriceInfo({tokenSymbol:"", price:0}),
            dataContent: new bytes(0),
            encryptionSchema: encryptionSchema,
            workerIds: workerIds,
            registeredTimestamp: uint64(block.timestamp),
            owner: msg.sender,
            status: DataStatus.REGISTERING,
            permissions: new address[](0)
        });
        _dataInfos[dataId] = dataInfo;

        emit DataPrepareRegistry(dataId, publicKeys);
    }

    /**
     * @notice Data Provider register confidential data to PADO Network.
     * @param dataId Data id for registry, returned by prepareRegistry.
     * @param dataTag The tag of data, providing basic information about data.
     * @param priceInfo The price infomation of data.
     * @param dataContent The content of data.
     * @param permissions The contract addresses for data permission control, can be empty
     * @return The UID of the data
     */
    function register(
        bytes32 dataId,
        string calldata dataTag,
        PriceInfo calldata priceInfo,
        bytes calldata dataContent,
        address[] calldata permissions
    ) external returns (bytes32) {
        DataInfo storage dataInfo = _dataInfos[dataId];

        require(dataInfo.dataId == dataId, "DataMgt.register: data does not exist");
        require(dataInfo.status == DataStatus.REGISTERING, "DataMgt.register: data status is not REGISTERING");
        require(dataInfo.owner == msg.sender, "DataMgt.register: caller is not data owner");
        require(dataContent.length > 0, "DataMgt.register: dataContent can not be empty");
        require(router.getFeeMgt().isSupportToken(priceInfo.tokenSymbol), "DataMgt.register: tokenSymbol is not supported");

        dataInfo.dataTag = dataTag;
        dataInfo.priceInfo = priceInfo;
        dataInfo.dataContent = dataContent;
        dataInfo.permissions = permissions;

        dataInfo.status = DataStatus.REGISTERED;

        emit DataRegistered(dataId);

        return dataId;
    }
    

    /**
     * @notice Get data by dataId
     * @param dataId The identifier of the data
     * @return return the data 
     */
    function getDataById(
        bytes32 dataId
    ) external view returns (DataInfo memory) {
        require(_dataInfos[dataId].dataId == dataId, "DataMgt.getDataById: data does not exist");

        return _dataInfos[dataId];
    }

    /**
     * @notice Delete data by dataId
     * @param dataId The identifier of the data
     */
    function deleteDataById(
        bytes32 dataId
    ) external {
        DataInfo storage dataInfo = _dataInfos[dataId];
        require(dataInfo.dataId == dataId, "DataMgt.deleteDataById: data does not exist");
        require(dataInfo.status != DataStatus.DELETED, "DataMgt.deleteDataById: data already deleted");
        require(dataInfo.owner == msg.sender, "DataMgt.deleteDataById: caller is not data owner");

        dataInfo.status = DataStatus.DELETED;

        emit DataDeleted(dataId);
    }

    /**
     * @notice updateRouter
     * @param _router The router
     */
    function updateRouter(IRouter _router) external onlyOwner {
        IRouter oldRouter = router;
        router = _router;
        emit RouterUpdated(oldRouter, _router);
    }

   /**
    * @notice Whether the data is permitted for the data user
    * @param dataUser The data user
    * @param dataId   the identifier of the data
    * @return Return true if the data is permitted for the data user, else false
    */
   function isDataPermitted(bytes32 dataId, address dataUser) public returns (bool) {
       DataInfo storage dataInfo = _dataInfos[dataId];
       require(dataInfo.dataId == dataId, "DataMgt.isPermitted: data does not exist");

       if (dataInfo.permissions.length == 0) {
           return true;
       }

       for (uint256 i = 0; i < dataInfo.permissions.length; i++) {
           bool b = IDataPermission(dataInfo.permissions[i]).isPermitted(dataUser,dataId);
           if (!b) {
               return false;
           }
       }
       return true;
   }

   /**
    * @notice Get the data if it is permitted for the data user, else revert
    * @param dataUser The data user
    * @param dataId   the identifier of the data
    * @return Return the data if it is permitted for the data user, else revert
    */
   function checkAndGetPermittedDataById(bytes32 dataId, address dataUser) external returns (DataInfo memory) {
       bool b = isDataPermitted(dataId, dataUser);
       require(b, "DataMgt.checkAndGetPermittedDataById: data is not permitted for data user");
       return _dataInfos[dataId];
   }
}
