// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {DataStatus, DataInfo, PriceInfo, EncryptionSchema} from "../types/Common.sol";

/**
 * @title IDataMgt
 * @notice DataMgt - Data Management interface.
 */
interface IDataMgt {
    // emit in prepareRegistry
    event DataPrepareRegistry(bytes32 indexed dataId, bytes[] publicKeys);

    // emit in register
    event DataRegistered(bytes32 indexed dataId);

    // emit in deleteDataById
    event DataDeleted(bytes32 indexed dataId);

    /**
     * @notice Data Provider prepare to register confidential data to PADO Network.
     * @param encryptionSchema EncryptionSchema
     * @return dataId and publicKeys Data id and public keys
     */
    function prepareRegistry(
        EncryptionSchema calldata encryptionSchema
    ) external returns (bytes32 dataId, bytes[] memory publicKeys);

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
    ) external returns (bytes32);
    

    /**
     * @notice Get data by dataId
     * @param dataId The identifier of the data
     * @return return the data 
     */
    function getDataById(
        bytes32 dataId
    ) external view returns (DataInfo memory);

    /**
     * @notice Delete data by dataId
     * @param dataId The identifier of the data
     */
    function deleteDataById(
        bytes32 dataId
    ) external;

   /**
    * @notice Whether the data is permitted for the data user
    * @param dataUser The data user
    * @param dataId   the identifier of the data
    * @return Return true if the data is permitted for the data user, else false
    */
   function isDataPermitted(bytes32 dataId, address dataUser) external returns (bool);

   /**
    * @notice Get the data if it is permitted for the data user, else revert
    * @param dataUser The data user
    * @param dataId   the identifier of the data
    * @return Return the data if it is permitted for the data user, else revert
    */
   function checkAndGetPermittedDataById(bytes32 dataId, address dataUser) external returns (DataInfo memory);
}
