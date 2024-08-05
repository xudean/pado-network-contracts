// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DataMgt} from "../contracts/DataMgt.sol";
import {MockDeployer} from "./mock/MockDeployer.sol";
import {DataInfo, PriceInfo, DataStatus, EncryptionSchema} from "../contracts/types/Common.sol";
import {IDataMgtEvents} from "./events/IDataMgtEvents.sol";

contract DataMgtTest is MockDeployer, IDataMgtEvents {
    bytes32 public registryId;

    function setUp() public {
        _deployAll();
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

        vm.expectEmit(true, true, true, true);
        emit DataRegistered(registryId);
        bytes32 dataId = dataMgt.register(
            registryId,
            "data tag",
            priceInfo,
            dataContent
        );

        assertEq(registryId, dataId);
    }

    function test_getDataById() public {
        test_Registry();

        DataInfo memory dataInfo = dataMgt.getDataById(registryId);
        assertEq(dataInfo.dataId, registryId);
    }

    function test_getDataByOwner() public {
        test_Registry();

        DataInfo[] memory dataInfo = dataMgt.getDataByOwner(address(this));
        assertEq(dataInfo.length, 1);
    }

    function test_deleteDataById() public {
        test_Registry();

        vm.expectEmit(true, true, true, true);
        emit DataDeleted(registryId);
        dataMgt.deleteDataById(registryId);
        DataInfo memory dataInfo = dataMgt.getDataById(registryId);

        assertEq(dataInfo.status == DataStatus.DELETED, true);
    }
}
