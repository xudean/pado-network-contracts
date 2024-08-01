// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DataMgt, DataInfo} from "../contracts/DataMgt.sol";
import {EncryptionSchema, PriceInfo, DataStatus} from "../contracts/interface/IDataMgt.sol";
import {MockDeployer} from "./mock/MockDeployer.sol";

contract DataMgtTest is MockDeployer {
    bytes32 public registryId;

    function setUp() public {
        _deployAll();
    }

    function test_Registry() public {
        bytes[] memory publicKeys;
        (registryId, publicKeys) = dataMgt.prepareRegistry(EncryptionSchema({
            t: 2,
            n: 3
        }));

        PriceInfo memory priceInfo = PriceInfo({
            tokenSymbol: "ETH",
            price: 2
        });

        bytes memory dataContent = new bytes(4);
        dataContent[0] = bytes1(uint8(0x74));
        dataContent[1] = bytes1(uint8(0x65));
        dataContent[2] = bytes1(uint8(0x73));
        dataContent[3] = bytes1(uint8(0x74));

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

        dataMgt.deleteDataById(registryId);
        DataInfo memory dataInfo = dataMgt.getDataById(registryId);

        assertEq(dataInfo.status == DataStatus.DELETED, true);
    }
}
