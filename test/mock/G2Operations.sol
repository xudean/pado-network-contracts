// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

contract G2Operations is Test {
    using Strings for uint256;

    function mul(uint256 x) public pure returns (BN254.G2Point memory g2Point) {
        g2Point.X[1] = 1;
        g2Point.X[0] = 2;
        g2Point.Y[1] = 3;
        g2Point.Y[0] = 4;
    }

}
