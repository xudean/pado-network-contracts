// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EIP712ExternalUpgradeable} from "@openzeppelin-upgrades/contracts/mocks/EIP712ExternalUpgradeable.sol";

//contract Counter is EIP712ExternalUpgradeable{
contract Counter{
    uint256 public number;
    uint256 public number2;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function getNumber() public view returns (uint256) {
        return number;
    }

    function setNumber2(uint256 newNumber) public {
        number2 = newNumber;
    }

    function getNumber2() public view returns (uint256) {
        return number2;
    }

    function increment() public {
        number++;
    }
}
