// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract TestERC20 is MockERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
