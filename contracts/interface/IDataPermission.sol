// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IDataPermission
 * @notice DataPermission - Data Permission interface.
 */
interface IDataPermission {
    /**
     * @notice Check whether data user can buy the data
     * @param dataUser The data user to buy the data.
     * @return Return true if the data user can buy the data, else false.
     */
    function isPermitted(address dataUser, bytes32 dataId) external returns (bool);
}

