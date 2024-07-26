// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @notice A struct representing computing request information related to the task.
 */
struct ComputingInfoRequest {
    uint256 price; // The computing price.
    uint32 t; // Threshold t.
    uint32 n; // Threshold n.
}
