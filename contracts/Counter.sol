// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EIP712ExternalUpgradeable} from "@openzeppelin-upgrades/contracts/mocks/EIP712ExternalUpgradeable.sol";

contract Counter is EIP712ExternalUpgradeable{
    uint256 public number;
    uint256 public number2;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function getNumber() public view returns (uint256) {
        return number;
    }

    function increment() public {
        number++;
    }
}
