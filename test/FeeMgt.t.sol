// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestERC20} from "./mock/TestERC20.sol";
import {IFeeMgt} from "../contracts/interface/IFeeMgt.sol";
import {FeeMgt} from "../contracts/FeeMgt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockDeployer} from "./mock/MockDeployer.sol";
import {FeeTokenInfo, Allowance, TaskStatus} from "../contracts/types/Common.sol";
import {IFeeMgtEvents} from "./events/IFeeMgtEvents.sol";

contract FeeMgtTest is MockDeployer, IFeeMgtEvents {
    bytes32 private ETH_HASH;
    receive() external payable {
    }

    function setUp() public {
        _deployAll();
        ETH_HASH = getTokenSymbolHash("ETH");
    }

    function getTokenSymbolHash(string memory tokenSymbol) internal pure returns (bytes32) {
        return keccak256(bytes(tokenSymbol));
    }

    function addFeeToken(string memory tokenSymbol, string memory desc, uint256 computingPrice) internal {
        TestERC20 erc20 = new TestERC20();
        erc20.initialize(desc, tokenSymbol, 18);

        vm.prank(contractOwner);
        vm.expectEmit(true, true, true, true);
        emit FeeTokenAdded(tokenSymbol, address(erc20), computingPrice);
        feeMgt.addFeeToken(tokenSymbol, address(erc20), computingPrice);
        erc20PerSymbol[tokenSymbol] = erc20;
        tokenSymbolList.push(tokenSymbol);
    }

    function test_addFeeToken() public returns (uint256){
        addFeeToken("TEST", "Test Token", 1);
        addFeeToken("bTEST", "The Second Test Token", 1);
        return 2;
    }

    function updateFeeToken(string memory tokenSymbol, string memory desc, uint256 computingPrice) internal {
        TestERC20 erc20 = new TestERC20();
        erc20.initialize(desc, tokenSymbol, 18);

        vm.prank(contractOwner);
        vm.expectEmit(true, true, true, true);
        emit FeeTokenUpdated(tokenSymbol, address(erc20), computingPrice);
        feeMgt.updateFeeToken(tokenSymbol, address(erc20), computingPrice);
        erc20PerSymbol[tokenSymbol] = erc20;
    }

    function test_updateFeeToken() public returns (uint256) {
        test_addFeeToken();
        updateFeeToken("TEST", "Test Token", 1);
        updateFeeToken("bTEST", "Test Token 2", 1);
        return 2;
    }

    function test_getFeeTokens() public {
        FeeTokenInfo[] memory oldTokenList = feeMgt.getFeeTokens();
        uint256 addedNum = test_addFeeToken();
        FeeTokenInfo[] memory tokenList = feeMgt.getFeeTokens();

        assertEq(tokenList.length - oldTokenList.length, addedNum);

    }

    function test_isSupportToken() public {
        test_addFeeToken();
        assertEq(feeMgt.isSupportToken("TEST"), true);
        assertEq(feeMgt.isSupportToken("TEST2"), false);
        assertEq(feeMgt.isSupportToken("ETH"), true);
    }

    function getBalance(address target, string memory tokenSymbol) internal view returns (uint256) {
        bytes32 hash = getTokenSymbolHash(tokenSymbol);
        if (hash == ETH_HASH) {
            return address(target).balance;
        }
        return erc20PerSymbol[tokenSymbol].balanceOf(target);
    }

    function test_transferToken_ETH() public {
        (bool b, ) = payable(address(taskMgt)).call{value: 50}(new bytes(0));
        require(b, "transfer error");

        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit TokenTransfered(msg.sender, "ETH", 5);
        feeMgt.transferToken{value: 5}(msg.sender, "ETH", 5);
        uint256 balance = address(feeMgt).balance;
        assertEq(balance, 5, "balance error");

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, "ETH");
        assertEq(allowance.free, 5, "allowance.free error");
        assertEq(allowance.locked, 0, "allowance.locked error");
    }

    function test_transferToken_TEST() public {
        test_addFeeToken();

        TestERC20 erc20 = erc20PerSymbol["TEST"];
        erc20.mint(msg.sender, 100);
        uint256 ownerBalance = erc20.balanceOf(msg.sender);
        assertEq(ownerBalance, 100, "ownerBalance error");

        vm.prank(msg.sender);
        erc20.approve(address(feeMgt), 5);
        uint256 spenderAllowance = erc20.allowance(msg.sender, address(feeMgt));
        assertEq(spenderAllowance, 5, "spenderAllowance error");
        
        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit TokenTransfered(msg.sender, "TEST", 5);
        feeMgt.transferToken(msg.sender, "TEST", 5);
        uint256 balance = erc20.balanceOf(address(feeMgt));
        assertEq(balance, 5, "balance error");

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, "TEST");
        assertEq(allowance.free, 5, "allowance.free error");
        assertEq(allowance.locked, 0, "allowance.locked error");
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

    function test_withdrawToken(string memory tokenSymbol) internal {
        test_transferToken(tokenSymbol);
        
        uint256 oldSenderBalance = getBalance(msg.sender, tokenSymbol);
        uint256 oldFeeMgtBalance = getBalance(address(feeMgt), tokenSymbol);

        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit TokenWithdrawn(msg.sender, tokenSymbol, 5);
        feeMgt.withdrawToken(msg.sender, tokenSymbol, 5);

        uint256 senderBalance = getBalance(msg.sender, tokenSymbol);
        uint256 feeMgtBalance = getBalance(address(feeMgt), tokenSymbol);

        assertEq(oldSenderBalance + 5, senderBalance, "sender balance error");
        assertEq(oldFeeMgtBalance - 5, feeMgtBalance, "feemgt balance error");
    }

    function test_withdrawToken_ETH() public {
        test_withdrawToken("ETH");
    }

    function test_withdrawToken_TEST() public {
        test_withdrawToken("TEST");
    }

    struct SubmittionInfo {
        bytes32 taskId;
        address submitter;
        string tokenSymbol;
        address[] workerOwners;
        uint256 dataPrice;
        address[] dataProviders;
    }

    function getTaskSubmittionInfo(string memory tokenSymbol) internal view returns (SubmittionInfo memory) {
        bytes32 taskId = keccak256(bytes("task id"));
        
        address[] memory workerOwners = new address[](3);
        workerOwners[0] = msg.sender;
        workerOwners[1] = msg.sender;
        workerOwners[2] = msg.sender;

        address[] memory dataProviders = new address[](1);
        dataProviders[0] = msg.sender;

        SubmittionInfo memory info = SubmittionInfo({
            taskId: taskId,
            submitter: msg.sender,
            tokenSymbol: tokenSymbol,
            workerOwners: workerOwners,
            dataPrice: 1,
            dataProviders: dataProviders
        });
        return info;
    }

    function test_lock(string memory tokenSymbol) internal {
        test_transferToken(tokenSymbol);
        FeeTokenInfo memory feeTokenInfo = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        Allowance memory oldAllowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        SubmittionInfo memory info = getTaskSubmittionInfo(tokenSymbol);
        uint256 lockedAmount = feeTokenInfo.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit FeeLocked(info.taskId, info.tokenSymbol, lockedAmount);
        feeMgt.lock(
            info.taskId,
            info.submitter,
            info.tokenSymbol,
            lockedAmount
        );

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free - lockedAmount, allowance.free, "allowance.free change error");
        assertEq(oldAllowance.locked + lockedAmount, allowance.locked, "allowance.locked change error");
    }

    function test_lock_ETH() public {
        test_lock("ETH");
    }
    function test_lock_TEST() public {
        test_lock("TEST");
    }

    function test_unlock(string memory tokenSymbol) internal {
        test_lock(tokenSymbol);
        FeeTokenInfo memory feeTokenInfo = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        Allowance memory oldAllowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        SubmittionInfo memory info = getTaskSubmittionInfo(tokenSymbol);
        uint256 lockedAmount = feeTokenInfo.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit FeeUnlocked(info.taskId, info.tokenSymbol, lockedAmount);
        feeMgt.unlock(
            info.taskId,
            info.submitter,
            info.tokenSymbol
        );

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free + lockedAmount, allowance.free, "allowance.free change error");
        assertEq(oldAllowance.locked - lockedAmount, allowance.locked, "allowance.locked change error");
    }

    function test_unlock_ETH() public {
        test_unlock("ETH");
    }
    function test_unlock_TEST() public {
        test_unlock("TEST");
    }

    function test_settle(string memory tokenSymbol) internal {
        test_lock(tokenSymbol);
        FeeTokenInfo memory feeTokenInfo = feeMgt.getFeeTokenBySymbol(tokenSymbol);
        Allowance memory oldAllowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        uint256 oldBalance = getBalance(msg.sender, tokenSymbol);
        uint256 oldFeeMgtBalance = getBalance(address(feeMgt), tokenSymbol);
        SubmittionInfo memory info = getTaskSubmittionInfo(tokenSymbol);

        uint256 lockedAmount = feeTokenInfo.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit FeeSettled(info.taskId, info.tokenSymbol, lockedAmount);
        feeMgt.settle(
            info.taskId,
            TaskStatus.COMPLETED,
            info.submitter,
            info.tokenSymbol,
            info.workerOwners,
            info.dataPrice,
            info.dataProviders
        );

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free, allowance.free);
        assertEq(oldAllowance.locked - lockedAmount, allowance.locked);

        uint256 balance = getBalance(msg.sender, tokenSymbol);
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
