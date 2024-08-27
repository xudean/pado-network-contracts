// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//This example only shows how to use it, please work out the dependencies yourself!
import {IDataPermission} from "../interface/IDataPermission.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";


contract WhiteListDataPermission is IDataPermission,Initializable,OwnableUpgradeable{
    address[] public whiteList;
    constructor(){
    }

    function initialize(address contractOwner) external initializer {
        _transferOwnership(contractOwner);
    }

    function addWhiteList(address _whiteList) external onlyOwner{
        whiteList.push(_whiteList);
    }

    function isPermitted(address dataUser) external view returns (bool){
        for (uint i = 0; i < whiteList.length; i++) {
            if (whiteList[i] == dataUser) {
                return true;
            }
        }
        revert("not permitted");
    }

}
