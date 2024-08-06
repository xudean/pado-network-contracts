// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
interface IDataMgtEvents {
    // emit in prepareRegistry
    event DataPrepareRegistry(bytes32 indexed dataId, bytes[] publicKeys);

    // emit in register
    event DataRegistered(bytes32 indexed dataId);

    // emit in deleteDataById
    event DataDeleted(bytes32 indexed dataId);
}

