// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
// import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TestERC20} from "./TestERC20.sol";
import {IFeeMgt, FeeTokenInfo, Allowance} from "../contracts/interface/IFeeMgt.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeMgtTest is Test {
    FeeMgt private feeMgt;
    mapping(string tokenSymbol => TestERC20 erc20) erc20Map;
    string[] tokenSymbolList;

    bytes32 private ETH_HASH;
    receive() external payable {
    }

    function setUp() public {
        feeMgt = new FeeMgt();
        feeMgt.initialize();
        ETH_HASH = getTokenSymbolHash("ETH");
    }

    function getTokenSymbolHash(string memory tokenSymbol) internal pure returns (bytes32) {
        return keccak256(bytes(tokenSymbol));
    }

    function addFeeToken(string memory tokenSymbol, string memory desc) internal {
        TestERC20 erc20 = new TestERC20();
        erc20.initialize(desc, tokenSymbol, 18);
        feeMgt.addFeeToken(tokenSymbol, address(erc20));
        erc20Map[tokenSymbol] = erc20;
        tokenSymbolList.push(tokenSymbol);
    }

    function test_addFeeToken() public {
        addFeeToken("TEST", "Test Token");
        addFeeToken("bTEST", "The Second Test Token");
    }

    function test_getFeeTokens() public {
        test_addFeeToken();
        FeeTokenInfo[] memory tokenList = feeMgt.getFeeTokens();

        assertEq(tokenList.length, tokenSymbolList.length + 1);

    }

    function test_isSupportToken() public {
        test_addFeeToken();
        assertEq(feeMgt.isSupportToken("TEST"), true);
        assertEq(feeMgt.isSupportToken("TEST2"), false);
        assertEq(feeMgt.isSupportToken("ETH"), true);
    }

    function getBalance(address target, string memory tokenSymbol) internal returns (uint256) {
        bytes32 hash = getTokenSymbolHash(tokenSymbol);
        if (hash == ETH_HASH) {
            return address(target).balance;
        }
        return erc20Map[tokenSymbol].balanceOf(target);
    }

    function test_transferToken_ETH() public {
        feeMgt.transferToken{value: 5}("ETH", 5);
        uint256 balance = address(feeMgt).balance;
        assertEq(balance, 5);

        Allowance memory allowance = feeMgt.getAllowance(address(this), "ETH");
        assertEq(allowance.free, 5);
        assertEq(allowance.locked, 0);
    }

    function test_transferToken_TEST() public {
        test_addFeeToken();

        TestERC20 erc20 = erc20Map["TEST"];
        erc20.mint(address(this), 100);
        uint256 ownerBalance = erc20.balanceOf(address(this));
        assertEq(ownerBalance, 100);

        erc20.approve(address(feeMgt), 5);
        uint256 spenderAllowance = erc20.allowance(address(this), address(feeMgt));
        assertEq(spenderAllowance, 5);
        

        feeMgt.transferToken("TEST", 5);
        uint256 balance = erc20.balanceOf(address(feeMgt));
        assertEq(balance, 5);

        Allowance memory allowance = feeMgt.getAllowance(address(this), "TEST");
        assertEq(allowance.free, 5);
        assertEq(allowance.locked, 0);
    }

    function test_transferToken(string memory tokenSymbol) internal {
        bytes32 hash = getTokenSymbolHash(tokenSymbol);
        if (hash == ETH_HASH) {
            test_transferToken_ETH();
        }
        else {
            test_transferToken_TEST();
        }
    }

    struct SubmittionInfo {
        bytes32 taskId;
        address submitter;
        string tokenSymbol;
        uint256 computingPrice;
        address[] workerOwners;
        uint256 dataPrice;
        address[] dataProviders;
    }

    function getTaskSubmittionInfo(string memory tokenSymbol) internal view returns (SubmittionInfo memory) {
        bytes32 taskId = keccak256(bytes("task id"));
        
        address[] memory workerOwners = new address[](3);
        workerOwners[0] = address(this);
        workerOwners[1] = address(this);
        workerOwners[2] = address(this);

        address[] memory dataProviders = new address[](1);
        dataProviders[0] = address(this);

        SubmittionInfo memory info = SubmittionInfo({
            taskId: taskId,
            submitter: address(this),
            tokenSymbol: tokenSymbol,
            computingPrice: 1,
            workerOwners: workerOwners,
            dataPrice: 1,
            dataProviders: dataProviders
        });
        return info;
    }

    function test_lock(string memory tokenSymbol) internal {
        test_transferToken(tokenSymbol);
        Allowance memory oldAllowance = feeMgt.getAllowance(address(this), tokenSymbol);
        SubmittionInfo memory info = getTaskSubmittionInfo(tokenSymbol);
        feeMgt.lock(
            info.taskId,
            info.submitter,
            info.tokenSymbol,
            info.computingPrice,
            info.workerOwners,
            info.dataPrice,
            info.dataProviders
        );

        uint256 lockedAmount = info.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        Allowance memory allowance = feeMgt.getAllowance(address(this), tokenSymbol);
        assertEq(oldAllowance.free - lockedAmount, allowance.free);
        assertEq(oldAllowance.locked + lockedAmount, allowance.locked);
    }

    function test_lock_ETH() public {
        test_lock("ETH");
    }
    function test_lock_TEST() public {
        test_lock("TEST");
    }

    function test_settle(string memory tokenSymbol) internal {
        test_lock(tokenSymbol);
        Allowance memory oldAllowance = feeMgt.getAllowance(address(this), tokenSymbol);
        uint256 oldBalance = getBalance(address(this), tokenSymbol);
        uint256 oldFeeMgtBalance = getBalance(address(feeMgt), tokenSymbol);
        SubmittionInfo memory info = getTaskSubmittionInfo(tokenSymbol);
        feeMgt.settle(
            info.taskId,
            0,
            info.submitter,
            info.tokenSymbol,
            info.computingPrice,
            info.workerOwners,
            info.dataPrice,
            info.dataProviders
        );

        uint256 lockedAmount = info.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        Allowance memory allowance = feeMgt.getAllowance(address(this), tokenSymbol);
        assertEq(oldAllowance.free, allowance.free);
        assertEq(oldAllowance.locked - lockedAmount, allowance.locked);

        uint256 balance = getBalance(address(this), tokenSymbol);
        uint256 feeMgtBalance = getBalance(address(feeMgt), tokenSymbol);

        assertEq(oldBalance + lockedAmount, balance);
        assertEq(oldFeeMgtBalance - lockedAmount, feeMgtBalance);

        assertEq(allowance.free, 1);
        assertEq(allowance.locked, 0);
        assertEq(feeMgtBalance, 1);
    }

    function test_settle_ETH() public {
        test_settle("ETH");
    }

    function test_settle_TEST() public {
        test_settle("TEST");
    }

}
