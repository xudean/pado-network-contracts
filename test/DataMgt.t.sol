// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DataMgt} from "../contracts/DataMgt.sol";
import {MockDeployer} from "./mock/MockDeployer.sol";
import {DataInfo, PriceInfo, DataStatus, EncryptionSchema} from "../contracts/types/Common.sol";
import {IDataMgtEvents} from "./events/IDataMgtEvents.sol";
import {DataPermissionAlwaysTrue, DataPermissionAlwaysFalse} from "./mock/DataPermissionMock.sol";

contract DataMgtTest is MockDeployer, IDataMgtEvents {
    bytes32 public registryId;

    function setUp() public {
        _deployAll();
    }

    function registerDataPermission(bool trueOrFalse) public {
        bytes[] memory publicKeys;
        vm.expectEmit(false, true, true, false);
        emit DataPrepareRegistry(registryId, publicKeys);
        (registryId, publicKeys) = dataMgt.prepareRegistry(EncryptionSchema({
            t: 2,
            n: 3
        }));

        PriceInfo memory priceInfo = PriceInfo({
            tokenSymbol: "ETH",
            price: 2
        });

        bytes memory dataContent = bytes("test");

        address[] memory permissionContracts = new address[](1);
        if (trueOrFalse) {
            DataPermissionAlwaysTrue truePermission = new DataPermissionAlwaysTrue();
            permissionContracts[0] = address(truePermission);
        }
        else {
            DataPermissionAlwaysFalse falsePermission = new DataPermissionAlwaysFalse();
            permissionContracts[0] = address(falsePermission);
        }
        dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent,
            permissionContracts    
        );
    }

    function test_Registry() public {
        bytes[] memory publicKeys;
        vm.expectEmit(false, true, true, false);
        emit DataPrepareRegistry(registryId, publicKeys);
        (registryId, publicKeys) = dataMgt.prepareRegistry(EncryptionSchema({
            t: 2,
            n: 3
        }));

        PriceInfo memory priceInfo = PriceInfo({
            tokenSymbol: "ETH",
            price: 2
        });

        bytes memory dataContent = bytes("test");
        address[] memory permissions = new address[](0);

        vm.expectRevert("DataMgt.register: data does not exist");
        dataMgt.register(
            keccak256("registryId"),
            "data tag",
            priceInfo,
            dataContent,
            permissions
        );

        vm.prank(msg.sender);
        vm.expectRevert("DataMgt.register: caller is not data owner");
        dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent,
            permissions
        );



        vm.expectEmit(true, true, true, true);
        emit DataRegistered(registryId);
        bytes32 dataId = dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent,
            permissions
        );

        vm.expectRevert("DataMgt.register: data status is not REGISTERING");
        dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent,
            permissions
        );

        assertEq(registryId, dataId);
    }

    function test_getDataById() public {
        test_Registry();

        vm.expectRevert("DataMgt.getDataById: data does not exist");
        dataMgt.getDataById(keccak256("test id"));

        DataInfo memory dataInfo = dataMgt.getDataById(registryId);
        assertEq(dataInfo.dataId, registryId);
    }

    function test_getPermittedDataById_false() public {
        registerDataPermission(false);
        vm.expectRevert("DataMgt.checkAndGetPermittedDataById: data is not permitted for data user");
        dataMgt.checkAndGetPermittedDataById(registryId, msg.sender);
        
        bool b = dataMgt.isDataPermitted(registryId, msg.sender);
        assertEq(b, false, "is data permitted error");
    }

    function test_getPermittedDataById_true() public {
        registerDataPermission(true);
        dataMgt.checkAndGetPermittedDataById(registryId, msg.sender);

        bool b = dataMgt.isDataPermitted(registryId, msg.sender);
        assertEq(b, true, "is data permitted error");
    }

    function test_getDataByOwner() public {
        test_Registry();

        DataInfo[] memory dataInfo = dataMgt.getDataByOwner(address(this));
        assertEq(dataInfo.length, 1);
    }

    function test_deleteDataById() public {
        test_Registry();
        
        vm.expectRevert("DataMgt.deleteDataById: data does not exist");
        dataMgt.deleteDataById(keccak256("test id"));

        vm.prank(msg.sender);
        vm.expectRevert("DataMgt.deleteDataById: caller is not data owner");
        dataMgt.deleteDataById(registryId);

        vm.expectEmit(true, true, true, true);
        emit DataDeleted(registryId);
        dataMgt.deleteDataById(registryId);
        DataInfo memory dataInfo = dataMgt.getDataById(registryId);

        assertEq(dataInfo.status == DataStatus.DELETED, true);

        vm.expectRevert("DataMgt.deleteDataById: data already deleted");
        dataMgt.deleteDataById(registryId); 
    }
}
