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

        vm.prank(contractOwner);
        vm.expectRevert("FeeMgt._addFeeToken: token symbol already exists");
        feeMgt.addFeeToken(tokenSymbol, address(erc20), computingPrice);
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

        vm.prank(contractOwner);
        vm.expectRevert("FeeMgt.updateFeeToken: fee token does not exist");
        feeMgt.updateFeeToken("TESTETH", address(erc20), computingPrice); 
    }

    function test_updateFeeToken() public returns (uint256) {
        test_addFeeToken();
        updateFeeToken("TEST", "Test Token", 1);
        updateFeeToken("bTEST", "Test Token 2", 1);
        return 2;
    }

    function deleteFeeToken(string memory tokenSymbol) public {
        vm.expectRevert("Ownable: caller is not the owner");
        feeMgt.deleteFeeToken(tokenSymbol);

        vm.prank(contractOwner);
        vm.expectRevert("FeeMgt.deleteFeeToken: token does not exist");
        feeMgt.deleteFeeToken("SomeETH");

        vm.prank(contractOwner);
        feeMgt.deleteFeeToken(tokenSymbol);

        vm.prank(contractOwner);
        vm.expectRevert("FeeMgt.deleteFeeToken: token does not exist");
        feeMgt.deleteFeeToken(tokenSymbol);
    }

    function test_deleteFeeToken() public {
        test_addFeeToken();
        deleteFeeToken("TEST");
        deleteFeeToken("bTEST");
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
        vm.expectRevert("FeeMgt.transferToken: amount is not correct");
        feeMgt.transferToken{value: 5}(msg.sender, "ETH", 6);

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
        (bool b, ) = payable(address(taskMgt)).call{value: 50}(new bytes(0));
        require(b, "transfer error");
        test_addFeeToken();

        TestERC20 erc20 = erc20PerSymbol["TEST"];
        erc20.mint(msg.sender, 100);
        uint256 ownerBalance = erc20.balanceOf(msg.sender);
        assertEq(ownerBalance, 100, "ownerBalance error");

        vm.prank(msg.sender);
        erc20.approve(address(feeMgt), 5);
        uint256 spenderAllowance = erc20.allowance(msg.sender, address(feeMgt));
        assertEq(spenderAllowance, 5, "spenderAllowance error");

        vm.expectRevert("FeeMgt.onlyTaskMgt: only task mgt allowed to call");
        feeMgt.transferToken(msg.sender, "TEST", 5);

        vm.prank(address(taskMgt));
        vm.expectRevert("FeeMgt.transferToken: msg.value should be zero");
        feeMgt.transferToken{value: 1}(msg.sender, "TEST", 5);

        vm.prank(address(taskMgt));
        vm.expectRevert("FeeMgt.transferToken: not supported token");
        feeMgt.transferToken(msg.sender, "TESTETH", 5);
                
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
        vm.expectRevert("FeeMgt.withdrawToken: not supported token"); 
        feeMgt.withdrawToken(msg.sender, "TESTETH", 5);

        vm.prank(address(taskMgt));
        vm.expectRevert("FeeMgt.withdrawToken: insufficient free allowance");
        feeMgt.withdrawToken(msg.sender, tokenSymbol, 6);


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

    function _getMockAddress(string memory tag) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(tag)))));
    }

    function getTaskSubmittionInfo(string memory tokenSymbol) internal view returns (SubmittionInfo memory) {
        bytes32 taskId = keccak256(bytes("task id"));
        
        address[] memory workerOwners = new address[](3);
        workerOwners[0] = _getMockAddress("worker 0");
        workerOwners[1] = _getMockAddress("worker 1");
        workerOwners[2] = _getMockAddress("worker 2");

        address[] memory dataProviders = new address[](1);
        dataProviders[0] = _getMockAddress("data provider");

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
        vm.expectRevert("FeeMgt.lock: Insufficient free allowance");
        feeMgt.lock(
            info.taskId,
            info.submitter,
            info.tokenSymbol,
            lockedAmount + 2 
        );

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

        for (uint256 i = 0; i < info.workerOwners.length; i++) {
            vm.prank(address(taskMgt));
            feeMgt.payWorker(
                info.taskId,
                info.submitter,
                info.workerOwners[i],
                info.tokenSymbol
            );
        }

        uint256 lockedAmount = feeTokenInfo.computingPrice * info.workerOwners.length + info.dataPrice * info.dataProviders.length;
        uint256 lockedAmount2 = info.dataPrice * info.dataProviders.length;
        vm.prank(address(taskMgt));
        vm.expectEmit(true, true, true, true);
        emit FeeSettled(info.taskId, info.tokenSymbol, lockedAmount2);
        feeMgt.settle(
            info.taskId,
            info.submitter,
            info.tokenSymbol,
            info.dataPrice,
            info.dataProviders
        );


        SubmittionInfo memory submittionInfo = getTaskSubmittionInfo(tokenSymbol);
        for (uint256 i = 0; i < submittionInfo.workerOwners.length; i++) {
            vm.prank(submittionInfo.workerOwners[i]);
            feeMgt.withdrawToken(submittionInfo.workerOwners[i], tokenSymbol, 1);
            uint256 bal = getBalance(submittionInfo.workerOwners[i], tokenSymbol);
            assertEq(bal, 1, "worker owner balance error");
        }

        for (uint256 i = 0; i < submittionInfo.dataProviders.length; i++) {
            vm.prank(submittionInfo.dataProviders[i]);
            feeMgt.withdrawToken(submittionInfo.dataProviders[i], tokenSymbol, 1);
            uint256 bal = getBalance(submittionInfo.dataProviders[i], tokenSymbol);
            assertEq(bal, 1, "data provider balance error");
        }

        Allowance memory allowance = feeMgt.getAllowance(msg.sender, tokenSymbol);
        assertEq(oldAllowance.free, allowance.free);
        assertEq(oldAllowance.locked - lockedAmount, allowance.locked);

        uint256 balance = getBalance(msg.sender, tokenSymbol);
        uint256 feeMgtBalance = getBalance(address(feeMgt), tokenSymbol);

        assertEq(oldBalance, balance);
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
