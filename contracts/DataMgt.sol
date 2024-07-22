// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IDataMgt, DataInfo, PriceInfo, EncryptionSchema} from "./IDataMgt.sol"; 
/**
 * @title DataMgt
 * @notice DataMgt - Data Management.
 */
contract DataMgt is IDataMgt{
    uint256 private _registryCount = 0;
    mapping(bytes32 registryId => bytes32[] workerIds) private _registryIdToWorkerIds;
    mapping(bytes32 dataId => DataInfo dataInfo) private _dataInfos;
    bytes32[] private _dataIds;

    mapping(address owner => bytes32[] dataIdList) private _dataIdListPerOwner;

    /**
     * @notice Data Provider prepare to register confidential data to PADO Network.
     * @param encryptionSchema EncryptionSchema
     * @return registryId and publicKeys Registry id and public keys
     */
    function prepareRegistery(
        EncryptionSchema calldata encryptionSchema
    ) external returns (bytes32 registryId, bytes[] memory publicKeys) {
        registryId = keccak256(abi.encode(encryptionSchema, _registryCount));
        _registryCount++;

        // TODO
        publicKeys = new bytes[](0);
    }

    /**
     * @notice Data Provider register confidential data to PADO Network.
     * @param registryId Registry id for registry, returned by prepareRegistry.
     * @param dataTag The tag of data, providing basic information about data.
     * @param priceInfo The price infomation of data.
     * @param dataContent The content of data.
     * @return The UID of the data
     */
    function register(
        bytes32 registryId,
        string calldata dataTag,
        PriceInfo calldata priceInfo,
        bytes calldata dataContent
    ) external returns (bytes32) {
        require(_registryIdToWorkerIds[registryId].length > 0, "invalid registryId");

        DataInfo memory dataInfo = DataInfo({
                dataId: registryId,
                dataTag: dataTag,
                priceInfo: priceInfo,
                dataContent: dataContent,
                workerIds: _registryIdToWorkerIds[registryId],
                registeredTimestamp: uint64(block.timestamp),
                owner: msg.sender,
                deleted: false
            });
        _dataInfos[registryId] = dataInfo;
        _dataIds.push(registryId);
        _dataIdListPerOwner[msg.sender].push(registryId);

        delete _registryIdToWorkerIds[registryId];

        return registryId;
    }
    

    /**
     * @notice Get all data registered by Data Provider
     * @return return all data
     */
    function getAllData(
    ) external view returns (DataInfo[] memory) {
        uint256 dataIdLength = _dataIds.length;

        DataInfo[] memory dataInfoList = new DataInfo[](dataIdLength);
        for (uint256 i = 0; i < dataIdLength; i++) {
            dataInfoList[i] = _dataInfos[_dataIds[i]];
        }

        return dataInfoList;
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
        require(!dataInfo.deleted, "data already deleted");

        dataInfo.deleted = true;
    }
}
