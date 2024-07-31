// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IDataMgt, DataInfo, PriceInfo, EncryptionSchema, DataStatus} from "./interface/IDataMgt.sol"; 
/**
 * @title DataMgt
 * @notice DataMgt - Data Management Contract.
 */
contract DataMgt is IDataMgt, OwnableUpgradeable {
    uint256 private _registryCount;
    mapping(bytes32 dataId => DataInfo dataInfo) private _dataInfos;

    mapping(address owner => bytes32[] dataIdList) private _dataIdListPerOwner;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        _registryCount = 0;
    }

    /**
     * @notice Data Provider prepare to register confidential data to PADO Network.
     * @param encryptionSchema EncryptionSchema
     * @return dataId and publicKeys data id and public keys
     */
    function prepareRegistry(
        EncryptionSchema calldata encryptionSchema
    ) external returns (bytes32 dataId, bytes[] memory publicKeys) {
        dataId = keccak256(abi.encode(encryptionSchema, _registryCount));
        _registryCount++;

        // TODO
        publicKeys = new bytes[](3);
        publicKeys[0] = bytes("test 0");
        publicKeys[1] = bytes("test 1");
        publicKeys[2] = bytes("test 2");

        address worker_address_0 = address(uint160(uint256(keccak256("worker 0"))));
        address worker_address_1 = address(uint160(uint256(keccak256("worker 1"))));
        address worker_address_2 = address(uint160(uint256(keccak256("worker 2"))));
        bytes32[] memory workerIds = new bytes32[](3);
        workerIds[0] = keccak256(abi.encode(worker_address_0));
        workerIds[1] = keccak256(abi.encode(worker_address_1));
        workerIds[2] = keccak256(abi.encode(worker_address_2));

        DataInfo memory dataInfo = DataInfo({
                dataId: dataId,
                dataTag: "",
                priceInfo: PriceInfo({tokenSymbol:"", price:0}),
                dataContent: new bytes(0),
                encryptionSchema: encryptionSchema,
                workerIds: workerIds,
                registeredTimestamp: uint64(block.timestamp),
                owner: msg.sender,
                status: DataStatus.REGISTERING
            });
        _dataInfos[dataId] = dataInfo;
        _dataIdListPerOwner[msg.sender].push(dataId);

        emit DataPrepareRegistry(dataId, publicKeys);
    }

    /**
     * @notice Data Provider register confidential data to PADO Network.
     * @param dataId Data id for registry, returned by prepareRegistry.
     * @param dataTag The tag of data, providing basic information about data.
     * @param priceInfo The price infomation of data.
     * @param dataContent The content of data.
     * @return The UID of the data
     */
    function register(
        bytes32 dataId,
        string calldata dataTag,
        PriceInfo calldata priceInfo,
        bytes calldata dataContent
    ) external returns (bytes32) {
        require(_dataInfos[dataId].status == DataStatus.REGISTERING, "invalid dataId");

        DataInfo storage dataInfo = _dataInfos[dataId];

        dataInfo.dataTag = dataTag;
        dataInfo.priceInfo = priceInfo;
        dataInfo.dataContent = dataContent;

        dataInfo.status = DataStatus.REGISTERED;

        emit DataRegistered(dataId);

        return dataId;
    }
    

    /**
     * @notice Get data by owner
     * @param owner The owner of data
     * @return return data owned by the owner
     */
    function getDataByOwner(
        address owner
    ) external view returns (DataInfo[] memory) {
        bytes32[] storage dataIdList = _dataIdListPerOwner[owner];

        DataInfo[] memory allDataInfo = new DataInfo[](dataIdList.length);
        for (uint256 i = 0; i < dataIdList.length; i++) {
            allDataInfo[i] = _dataInfos[dataIdList[i]];
        }
        return allDataInfo;
    }

    /**
     * @notice Get data by dataId
     * @param dataId The identifier of the data
     * @return return the data 
     */
    function getDataById(
        bytes32 dataId
    ) external view returns (DataInfo memory) {
        require(_dataInfos[dataId].dataId != 0, "data not exist");

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
        require(dataInfo.dataId != 0, "data not exist");
        require(dataInfo.status != DataStatus.DELETED, "data already deleted");

        dataInfo.status = DataStatus.DELETED;

        emit DataDeleted(dataId);
    }
}
