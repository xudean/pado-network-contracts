// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IFeeMgt, FeeTokenInfo, Allowance} from "./interface/IFeeMgt.sol";
import {TaskStatus} from "./interface/ITaskMgt.sol";


/**
 * @title FeeMgt
 * @notice FeeMgt - Fee Management Contract.
 */
contract FeeMgt is IFeeMgt, Initializable {
    mapping(string symbol => address tokenAddress) private _tokenAddressForSymbol;
    mapping(string symbol => uint256 computingFee) private _computingPriceForSymbol;

    string[] private _symbolList;

    mapping(address dataUser => mapping(string tokenSymbol => Allowance allowance)) private _allowanceForDataUser;

    mapping(bytes32 taskId => uint256 amount) private _lockedAmountForTaskId;

    function initialize(uint256 computingPriceForETH) public initializer {
        _addFeeToken("ETH", address(0), computingPriceForETH);
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
    ) payable external {
        require(isSupportToken(tokenSymbol), "not supported token");
        if (_isETH(tokenSymbol)) {
            require(amount == msg.value, "numTokens is not correct");
        }
        else {
            require(_tokenAddressForSymbol[tokenSymbol] != address(0), "tokenSymbol is not supported");
            
            address tokenAddress = _tokenAddressForSymbol[tokenSymbol];
            IERC20(tokenAddress).transferFrom(from, address(this), amount);
        }

        Allowance storage allowance = _allowanceForDataUser[from][tokenSymbol];

        allowance.free += amount;
    }

    /**
     * @notice TaskMgt contract request locking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param workerOwners The owner address of all workers which have already run the task.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function lock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol,
        address[] calldata workerOwners,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external returns (bool) {
        require(isSupportToken(tokenSymbol), "not supported token");
        uint256 computingPrice = _computingPriceForSymbol[tokenSymbol];
        require(computingPrice > 0, "computing price is not set");

        uint256 toLockAmount = workerOwners.length * computingPrice + dataProviders.length * dataPrice;
        Allowance storage allowance = _allowanceForDataUser[submitter][tokenSymbol];

        require(allowance.free >= toLockAmount, "Insufficient free allowance");

        allowance.free -= toLockAmount;
        allowance.locked += toLockAmount;
        _lockedAmountForTaskId[taskId] = toLockAmount;
        return true;
    }

    /**
     * @notice TaskMgt contract request settlement fee.
     * @param taskId The task id.
     * @param taskResultStatus The task run result status.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param workerOwners The owner address of all workers which have already run the task.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function settle(
        bytes32 taskId,
        TaskStatus taskResultStatus,
        address submitter,
        string calldata tokenSymbol,
        address[] calldata workerOwners,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external returns (bool) {
        require(isSupportToken(tokenSymbol), "not supported token");
        uint256 computingPrice = _computingPriceForSymbol[tokenSymbol];
        require(computingPrice > 0, "computing price is not set");

        // TODO
        if (taskResultStatus == TaskStatus.COMPLETED) {}

        uint256 lockedAmount = _lockedAmountForTaskId[taskId];

        Allowance storage allowance = _allowanceForDataUser[submitter][tokenSymbol];

        uint256 expectedAllowance = computingPrice * workerOwners.length + dataPrice * dataProviders.length;

        require(expectedAllowance <= allowance.locked, "insufficient locked allowance");
        require(lockedAmount >= expectedAllowance, "locked not enough");

        if (expectedAllowance > 0) {
            if (_isETH(tokenSymbol)) {
                for (uint256 i = 0; i < workerOwners.length; i++) {
                    payable(workerOwners[i]).transfer(computingPrice);
                }
    
                for (uint256 i = 0; i < dataProviders.length; i++) {
                    payable(dataProviders[i]).transfer(dataPrice);
                }
            }
            else {
                require(_tokenAddressForSymbol[tokenSymbol] != address(0), "can not find token address");
                IERC20 tokenAddress = IERC20(_tokenAddressForSymbol[tokenSymbol]);
    
                for (uint256 i = 0; i < workerOwners.length; i++) {
                    tokenAddress.transfer(workerOwners[i], computingPrice);
                }
    
                for (uint256 i = 0; i < dataProviders.length; i++) {
                    tokenAddress.transfer(dataProviders[i], dataPrice);
                }
            }
    
            allowance.locked -= expectedAllowance;
        }
        if (lockedAmount > expectedAllowance) {
            uint256 toReturnAmount = lockedAmount - expectedAllowance;
            allowance.locked -= toReturnAmount;
            allowance.free += toReturnAmount;

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
    function addFeeToken(string calldata tokenSymbol, address tokenAddress, uint256 computingPrice) external returns (bool) {
        return _addFeeToken(tokenSymbol, tokenAddress, computingPrice);
    }

    /**
     * @notice Add the fee token.
     * @param tokenSymbol The new fee token symbol.
     * @param tokenAddress The new fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the adding is successful.
     */
    function _addFeeToken(string memory tokenSymbol, address tokenAddress, uint256 computingPrice) internal returns (bool) {
        require(_tokenAddressForSymbol[tokenSymbol] == address(0), "token symbol already exists");
        require(_computingPriceForSymbol[tokenSymbol] == 0, "computing price already exists");

        _tokenAddressForSymbol[tokenSymbol] = tokenAddress;
        _computingPriceForSymbol[tokenSymbol] = computingPrice;
        _symbolList.push(tokenSymbol);
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

            tokenInfos[i] = FeeTokenInfo({
                symbol: symbol,
                tokenAddress: _tokenAddressForSymbol[symbol],
                computingPrice: _computingPriceForSymbol[symbol]
            });
        }


        return tokenInfos;
    }

    /**
     * @notice Get fee token by token symbol.
     * @param tokenSymbol The token symbol.
     * @return Returns the fee token.
     */
    function getFeeTokenBySymbol(string calldata tokenSymbol) external view returns (FeeTokenInfo memory) {
        FeeTokenInfo memory info = FeeTokenInfo({
            symbol: tokenSymbol,
            tokenAddress: _tokenAddressForSymbol[tokenSymbol],
            computingPrice: _computingPriceForSymbol[tokenSymbol]
        });

        if (!_isETH(tokenSymbol)) {
            require(info.tokenAddress != address(0), "fee token does not exist");
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
        return _tokenAddressForSymbol[tokenSymbol] != address(0);
    }

    /**
     * @notice Get allowance info.
     * @param dataUser The address of data user
     * @param tokenSymbol The token symbol for the data user
     * @return Allowance for the data user
     */
    function getAllowance(address dataUser, string calldata tokenSymbol) external view returns (Allowance memory) {
        return _allowanceForDataUser[dataUser][tokenSymbol];
    }

    /**
     * @notice Whether the token symbol is ETH
     * @param tokenSymbol The token symbol
     * @return True if the token symbol is ETH, else false
     */
    function _isETH(string memory tokenSymbol) internal pure returns (bool) {
        return keccak256(bytes(tokenSymbol)) == keccak256(bytes("ETH"));
    }
}
