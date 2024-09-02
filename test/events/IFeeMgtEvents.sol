// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
interface IFeeMgtEvents {
    // emit in addFeeToken
    event FeeTokenAdded(
        bytes32 indexed tokenId
    );

    // emit in updateFeeToken
    event FeeTokenUpdated(
        bytes32 indexed tokenId
    );

    // emit in deleteFeeToken
    event FeeTokenDeleted(
        bytes32 indexed tokenId
    );

    // emit in transfer token
    event TokenTransfered(
        address from,
        bytes32 tokenId,
        uint256 amount
    );

    // emit in withdraw
    event TokenWithdrawn(
        address to,
        bytes32 tokenId,
        uint256 amount
    );

    // emit in lock
    event FeeLocked(
        bytes32 indexed taskId,
        bytes32 tokenId,
        uint256 amount
    );

    // emit in unlock
    event FeeUnlocked(
        bytes32 indexed taskId,
        bytes32 tokenId,
        uint256 amount
    );

    // emit in settle
    event FeeSettled(
        bytes32 indexed taskId,
        bytes32 tokenId,
        uint256 amount
    );

    // emit in setTaskMgt
    event TaskMgtUpdated(
        address from,
        address to
    );
}

