// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {IDataPermission} from "contracts/interface/IDataPermission.sol";

contract DataPermissionAlwaysTrue {
    /**
     * @notice Check whether data user can buy the data
     * @param dataUser The data user to buy the data.
     * @return Return true if the data user can buy the data, else false.
     */
    function isPermitted(address dataUser) external returns (bool) {
        return true;
    }
}

contract DataPermissionAlwaysFalse {
    /**
     * @notice Check whether data user can buy the data
     * @param dataUser The data user to buy the data.
     * @return Return true if the data user can buy the data, else false.
     */
    function isPermitted(address dataUser) external returns (bool) {
        return false;
    }
}
