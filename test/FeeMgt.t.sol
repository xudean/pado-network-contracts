// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IFeeMgt, FeeTokenInfo, Allowance} from "../contracts/interface/IFeeMgt.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeMgtTest is Test {
    FeeMgt private feeMgt;
    MockERC20 private erc20;

    function setUp() public {
        feeMgt = new FeeMgt();
        feeMgt.initialize();

    }

    function test_addFeeToken() public {
        erc20 = new MockERC20();
        erc20.initialize("TEST token", "TEST", 18);
        feeMgt.addFeeToken("TEST", address(erc20));
    }

    function test_getFeeTokens() public {
        test_addFeeToken();
        FeeTokenInfo[] memory tokenList = feeMgt.getFeeTokens();

        assertEq(tokenList.length, 2);

        FeeTokenInfo memory token = tokenList[1];

        assertEq(token.symbol, erc20.symbol());
        assertEq(token.tokenAddress, address(erc20));
    }

    function test_isSupportToken() public {
        test_addFeeToken();
        assertEq(feeMgt.isSupportToken("TEST"), true);
        assertEq(feeMgt.isSupportToken("TEST2"), false);
        assertEq(feeMgt.isSupportToken("ETH"), true);
    }
}
