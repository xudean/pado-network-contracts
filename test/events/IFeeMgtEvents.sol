// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
interface IFeeMgtEvents {
    // emit in addFeeToken
    event FeeTokenAdded(
        string indexed tokenSymbol,
        address tokenAddress,
        uint256 computingPrice
    );

    // emit in updateFeeToken
    event FeeTokenUpdated(
        string indexed tokenSymbol,
        address tokenAddress,
        uint256 computingPrice
    );

    // emit in transfer token
    event TokenTransfered(
        address from,
        string tokenSymbol,
        uint256 amount
    );

    // emit in withdraw
    event TokenWithdrawn(
        address to,
        string tokenSymbol,
        uint256 amount
    );

    // emit in lock
    event FeeLocked(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    // emit in unlock
    event FeeUnlocked(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    // emit in settle
    event FeeSettled(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    // emit in setTaskMgt
    event TaskMgtUpdated(
        address from,
        address to
    );
}

