// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IDataMgt, DataInfo, PriceInfo, EncryptionSchema} from "./IDataMgt.sol"; 
/**
 * @title DataMgt
 * @notice DataMgt - Data Management.
 */
contract DataMgt is IDataMgt{
    uint256 private _registry_count = 0;
    mapping(bytes32 registryId => bytes[] publicKeys) private _registryIdToPublicKeys;
    mapping(bytes32 dataId => DataInfo dataInfo) private _dataInfos;
    bytes32[] private _dataIds;
    bytes32[] private _deletedDataIds;

    mapping(bytes32 dataId => uint256 dataIndex) private _dataIdToIndex;
    mapping(address owner => bytes32[] dataIdList) private _dataIdListPerOwner;

    /**
     * @notice Data Provider prepare to register confidential data to PADO Network.
     * @param encryptionSchema EncryptionSchema
     * @return registryId and publicKeys Registry id and public keys
     */
    function prepareRegistery(
        EncryptionSchema calldata encryptionSchema
    ) external returns (bytes32 registryId, bytes[] memory publicKeys) {
        registryId = keccak256(abi.encode(encryptionSchema, _registry_count));
        _registry_count++;

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
        require(_registryIdToPublicKeys[registryId].length > 0, "invalid registryId");

        DataInfo memory dataInfo = DataInfo({
                dataId: registryId,
                dataTag: dataTag,
                priceInfo: priceInfo,
                dataContent: dataContent,
                publicKeys: _registryIdToPublicKeys[registryId],
                registeredTimestamp: uint64(block.timestamp),
                owner: msg.sender,
                deleted: false
            });
        _dataInfos[registryId] = dataInfo;
        _dataIds.push(registryId);
        _dataIdToIndex[registryId] = _dataIds.length - 1;
        _dataIdListPerOwner[msg.sender].push(registryId);

        delete _registryIdToPublicKeys[registryId];

        return registryId;
    }
    

    /**
     * @notice Get all data registered by Data Provider
     * @param includingDeleted Whether return the deleted data
     * @return return all data
     */
    function getAllData(
        bool includingDeleted
    ) external view returns (DataInfo[] memory) {
        uint256 dataIdLength = _dataIds.length;
        if (includingDeleted) {
            dataIdLength += _deletedDataIds.length;
        }

        DataInfo[] memory dataInfoList = new DataInfo[](dataIdLength);
        uint256 listIndex = 0;
        for (uint256 i = 0; i < _dataIds.length; i++) {
            dataInfoList[listIndex] = _dataInfos[_dataIds[i]];
            listIndex++;
        }

        for (uint256 i = 0; i < _deletedDataIds.length; i++) {
            dataInfoList[listIndex] = _dataInfos[_deletedDataIds[i]];
            listIndex++;
        }
        return dataInfoList;
    }

    /**
     * @notice Get data by owner
     * @param includingDeleted Whether return the deleted data
     * @param owner The owner of data
     * @return return data owned by the owner
     */
    function getDataByOwner(
        bool includingDeleted,
        address owner
    ) external view returns (DataInfo[] memory) {
        bytes32[] storage dataIdList = _dataIdListPerOwner[owner];

        if (includingDeleted) {
            DataInfo[] memory allDataInfo = new DataInfo[](dataIdList.length);
            for (uint256 i = 0; i < dataIdList.length; i++) {
                allDataInfo[i] = _dataInfos[dataIdList[i]];
            }
            return allDataInfo;
        }

        uint256 length = 0;
        for (uint256 i = 0; i < dataIdList.length; i++) {
            DataInfo storage d = _dataInfos[dataIdList[i]];
            if (!d.deleted) {
                length++;
            }
        }

        DataInfo[] memory dataInfo = new DataInfo[](length);
        uint256 infoIndex = 0;
        for (uint256 i = 0; i < dataIdList.length; i++) {
            DataInfo storage d = _dataInfos[dataIdList[i]];
            if (!d.deleted) {
                dataInfo[infoIndex] = d;
                infoIndex++;
            }
        }
        return dataInfo;
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
        uint256 toDeleteIndex = _dataIdToIndex[dataId];
        _dataIds[toDeleteIndex] = _dataIds[_dataIds.length - 1];
        _dataIds.pop();
        
        _deletedDataIds.push(dataId);

        delete _dataIdToIndex[dataId];
    }
}
