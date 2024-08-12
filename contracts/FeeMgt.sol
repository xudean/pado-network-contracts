// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFeeMgt} from "./interface/IFeeMgt.sol";
import {ITaskMgt} from "./interface/ITaskMgt.sol";
import {IRouter, IRouterUpdater} from "./interface/IRouter.sol";
import {FeeTokenInfo, Allowance, TaskStatus} from "./types/Common.sol";

/**
 * @title FeeMgt
 * @notice FeeMgt - Fee Management Contract.
 */
contract FeeMgt is IFeeMgt, IRouterUpdater, OwnableUpgradeable {
    // router
    IRouter public router;

    // tokenSymbol => FeeTokenInfo 
    mapping(string symbol => FeeTokenInfo feeTokenInfo) private _feeTokenInfoForSymbol;

    // tokenSymbol[]
    string[] private _symbolList;

    // eoa => tokenSymbol => allowance
    mapping(address eoa => mapping(string tokenSymbol => Allowance allowance)) private _allowanceForEOA;

    // taskId => amount
    mapping(bytes32 taskId => uint256 amount) private _lockedAmountForTaskId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initial FeeMgt.
     * @param _router The Router
     * @param computingPriceForETH The computing price for ETH.
     * @param contractOwner The owner of the contract
     */
    function initialize(IRouter _router, uint256 computingPriceForETH, address contractOwner) public initializer {
        router = _router;
        _addFeeToken("ETH", address(0), computingPriceForETH);
        _transferOwnership(contractOwner);
    }

    /**
     * @notice TaskMgt contract request transfer tokens.
     * @param tokenSymbol The token symbol
     * @param amount The amount of tokens to be transfered
     */
    function transferToken(
        address from,
        string calldata tokenSymbol,
        uint256 amount
    ) payable external onlyTaskMgt {
        require(isSupportToken(tokenSymbol), "FeeMgt.transferToken: not supported token");
        if (_isETH(tokenSymbol)) {
            require(amount == msg.value, "FeeMgt.transferToken: amount is not correct");
        }
        else {
            require(msg.value == 0, "FeeMgt.transferToken: msg.value should be zero");
            FeeTokenInfo storage feeTokenInfo = _feeTokenInfoForSymbol[tokenSymbol];
            
            address tokenAddress = feeTokenInfo.tokenAddress;
            IERC20(tokenAddress).transferFrom(from, address(this), amount);
        }

        Allowance storage allowance = _allowanceForEOA[from][tokenSymbol];

        allowance.free += amount;

        emit TokenTransfered(from, tokenSymbol, amount);
    }

    /**
     * @notice TaskMgt contract request transfer tokens.
     * @param to The address to which token is withdrawn.
     * @param tokenSymbol The token symbol
     * @param amount The amount of tokens to be transfered
     */
    function withdrawToken(
        address to,
        string calldata tokenSymbol,
        uint256 amount
    ) external {
        require(isSupportToken(tokenSymbol), "FeeMgt.withdrawToken: not supported token");

        Allowance storage allowance = _allowanceForEOA[to][tokenSymbol];
        require(allowance.free >= amount, "FeeMgt.withdrawToken: insufficient free allowance");
        allowance.free -= amount;
        if (_isETH(tokenSymbol)) {
            (bool res, )  = payable(address(to)).call{value: amount}(new bytes(0));
            require(res, "FeeMgt.withdrawToken: call error");
        }
        else {
            FeeTokenInfo storage feeTokenInfo = _feeTokenInfoForSymbol[tokenSymbol];
            
            address tokenAddress = feeTokenInfo.tokenAddress;
            IERC20(tokenAddress).transfer(to, amount);
        }

        emit TokenWithdrawn(to, tokenSymbol, amount);
    }

    /**
     * @notice TaskMgt contract request locking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param toLockAmount The amount of fee to lock.
     * @return Returns true if the settlement is successful.
     */
    function lock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol,
        uint256 toLockAmount 
    ) external onlyTaskMgt returns (bool) {
        require(isSupportToken(tokenSymbol), "FeeMgt.lock: not supported token");

        Allowance storage allowance = _allowanceForEOA[submitter][tokenSymbol];

        require(allowance.free >= toLockAmount, "FeeMgt.lock: Insufficient free allowance");

        allowance.free -= toLockAmount;
        allowance.locked += toLockAmount;
        _lockedAmountForTaskId[taskId] = toLockAmount;

        emit FeeLocked(taskId, tokenSymbol, toLockAmount);
        return true;
    }

    /**
     * @notice TaskMgt contract request unlocking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @return Return true if the settlement is successful.
     */
    function unlock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol
    ) external onlyTaskMgt returns (bool) {
        require(isSupportToken(tokenSymbol), "FeeMgt.unlock: not supported token");
        uint256 toUnlockAmount = _lockedAmountForTaskId[taskId];
        require(toUnlockAmount > 0, "FeeMgt.unlock: locked amount is zero");

        Allowance storage allowance = _allowanceForEOA[submitter][tokenSymbol];
        require(allowance.locked >= toUnlockAmount, "FeeMgt.unlock: Insufficient locked allowance");

        allowance.free += toUnlockAmount;
        allowance.locked -= toUnlockAmount;
        _lockedAmountForTaskId[taskId] -= toUnlockAmount;

        emit FeeUnlocked(taskId, tokenSymbol, toUnlockAmount);
        return true;
    }


    /**
     * @notice TaskMgt contract request pay workers.
     * @param taskId The task id.
     * @param submitter The task submitter.
     * @param workerOwner The owner of the worker.
     * @param tokenSymbol The symbol of the token.
     */
    function payWorker(
        bytes32 taskId,
        address submitter,
        address workerOwner,
        string calldata tokenSymbol
    ) external {
        require(isSupportToken(tokenSymbol), "FeeMgt.settle: not supported token");
        uint256 computingPrice = _feeTokenInfoForSymbol[tokenSymbol].computingPrice;
        require(computingPrice > 0, "FeeMgt.settle: computing price is not set");
        uint256 lockedAmount = _lockedAmountForTaskId[taskId];
        require(lockedAmount >= computingPrice, "FeeMgt.payWorker: insufficient lockedAmount");
        _lockedAmountForTaskId[taskId] -= computingPrice;

        _allowanceForEOA[submitter][tokenSymbol].locked -= computingPrice;
        _allowanceForEOA[workerOwner][tokenSymbol].free += computingPrice;

    }

    /**
     * @notice TaskMgt contract request settlement fee.
     * @param taskId The task id.
     * @param taskResultStatus The task run result status.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function settle(
        bytes32 taskId,
        TaskStatus taskResultStatus,
        address submitter,
        string calldata tokenSymbol,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external onlyTaskMgt returns (bool) {
        require(isSupportToken(tokenSymbol), "FeeMgt.settle: not supported token");

        // TODO
        if (taskResultStatus == TaskStatus.COMPLETED) {}

        uint256 lockedAmount = _lockedAmountForTaskId[taskId];

        Allowance storage allowance = _allowanceForEOA[submitter][tokenSymbol];

        uint256 expectedAllowance = dataPrice * dataProviders.length;

        require(expectedAllowance <= allowance.locked, "FeeMgt.settle: insufficient locked allowance");
        require(lockedAmount >= expectedAllowance, "FeeMgt.settle: locked not enough");

        if (expectedAllowance > 0) {
            _settle(
                taskId,
                submitter,
                tokenSymbol,
                dataPrice,
                dataProviders
            );
        }
        if (lockedAmount > expectedAllowance) {
            uint256 toReturnAmount = lockedAmount - expectedAllowance;
            allowance.locked -= toReturnAmount;
            allowance.free += toReturnAmount;
            
            emit FeeUnlocked(taskId, tokenSymbol, toReturnAmount);
        }

        return true;
    }

    /**
     * @notice Add the fee token.
     * @param tokenSymbol The new fee token symbol.
     * @param tokenAddress The new fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the adding is successful.
     */
    function addFeeToken(string calldata tokenSymbol, address tokenAddress, uint256 computingPrice) external onlyOwner returns (bool) {
        return _addFeeToken(tokenSymbol, tokenAddress, computingPrice);
    }

    /**
     * @notice Update the fee token.
     * @param tokenSymbol The fee token symbol.
     * @param tokenAddress The fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the updating is successful.
     */
    function updateFeeToken(string calldata tokenSymbol, address tokenAddress, uint256 computingPrice) external onlyOwner returns (bool) {
        FeeTokenInfo storage feeTokenInfo = _feeTokenInfoForSymbol[tokenSymbol];
        require(feeTokenInfo.tokenAddress != address(0), "FeeMgt.updateFeeToken: fee token does not exist");

        if (tokenAddress != address(0)) {
            feeTokenInfo.tokenAddress = tokenAddress;
        }
        if (computingPrice != 0) {
            feeTokenInfo.computingPrice = computingPrice;
        }
        emit FeeTokenUpdated(tokenSymbol, tokenAddress, computingPrice);
        return true;
    }
    /**
     * @notice Add the fee token.
     * @param tokenSymbol The new fee token symbol.
     * @param tokenAddress The new fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the adding is successful.
     */
    function _addFeeToken(string memory tokenSymbol, address tokenAddress, uint256 computingPrice) internal returns (bool) {
        require(_feeTokenInfoForSymbol[tokenSymbol].tokenAddress == address(0), "FeeMgt._addFeeToken: token symbol already exists");

        FeeTokenInfo memory feeTokenInfo = FeeTokenInfo({
            symbol: tokenSymbol,
            tokenAddress: tokenAddress,
            computingPrice: computingPrice
        });
        _feeTokenInfoForSymbol[tokenSymbol] = feeTokenInfo;
        _symbolList.push(tokenSymbol);

        emit FeeTokenAdded(tokenSymbol, tokenAddress, computingPrice);
        return true;
    }

    /**
     * @notice Get the all fee tokens.
     * @return Returns the all fee tokens info.
     */
    function getFeeTokens() external view returns (FeeTokenInfo[] memory) {
        uint256 symbolListLength = _symbolList.length;
        FeeTokenInfo[] memory tokenInfos = new FeeTokenInfo[](symbolListLength);

        for (uint256 i = 0; i < _symbolList.length; i++) {
            string storage symbol = _symbolList[i];

            tokenInfos[i] = _feeTokenInfoForSymbol[symbol]; 
        }

        return tokenInfos;
    }

    /**
     * @notice Get fee token by token symbol.
     * @param tokenSymbol The token symbol.
     * @return Returns the fee token.
     */
    function getFeeTokenBySymbol(string calldata tokenSymbol) external view returns (FeeTokenInfo memory) {
        FeeTokenInfo storage info = _feeTokenInfoForSymbol[tokenSymbol]; 

        if (!_isETH(tokenSymbol)) {
            require(info.tokenAddress != address(0), "FeeMgt.getFeeTokenBySymbol: fee token does not exist");
        }
        return info;
    }

    /**
     * @notice Determine whether a token can pay the handling fee.
     * @return Returns true if a token can pay fee, otherwise returns false.
     */
    function isSupportToken(string calldata tokenSymbol) public view returns (bool) {
        if (_isETH(tokenSymbol)) {
            return true;
        }
        return _feeTokenInfoForSymbol[tokenSymbol].tokenAddress != address(0);
    }

    /**
     * @notice Get allowance info.
     * @param eoa The address of EOA
     * @param tokenSymbol The token symbol for the EOA
     * @return Allowance for the EOA
     */
    function getAllowance(address eoa, string calldata tokenSymbol) external view returns (Allowance memory) {
        return _allowanceForEOA[eoa][tokenSymbol];
    }

    /**
     * @notice Whether the token symbol is ETH
     * @param tokenSymbol The token symbol
     * @return True if the token symbol is ETH, else false
     */
    function _isETH(string memory tokenSymbol) internal pure returns (bool) {
        return keccak256(bytes(tokenSymbol)) == keccak256(bytes("ETH"));
    }

    /**
     * @notice TaskMgt contract request settlement fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     */
    function _settle(
        bytes32 taskId,
        address submitter,
        string memory tokenSymbol,
        uint256 dataPrice,
        address[] memory dataProviders
    ) internal {
        uint256 settledFee = 0;

        for (uint256 i = 0; i < dataProviders.length; i++) {
            _allowanceForEOA[dataProviders[i]][tokenSymbol].free += dataPrice;
            settledFee += dataPrice;
        }
        _allowanceForEOA[submitter][tokenSymbol].locked -= settledFee;
        emit FeeSettled(taskId, tokenSymbol, settledFee);
    }

    modifier onlyTaskMgt() {
        require(msg.sender == address(router.getTaskMgt()), "FeeMgt.onlyTaskMgt: only task mgt allowed to call");
        _;
    }

    /**
     * @notice updateRouter
     * @param _router The router
     */
    function updateRouter(IRouter _router) external {
        IRouter oldRouter = router;
        router = _router;
        emit RouterUpdated(oldRouter, _router);
    }
}
