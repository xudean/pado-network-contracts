// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {ITaskMgt} from "./ITaskMgt.sol";
import {Balance, FeeTokenInfo, TaskStatus} from "../types/Common.sol";

/**
 * @title IFeeMgt
 * @notice FeeMgt - Fee Management interface.
 */
interface IFeeMgt {
    // emit in addFeeToken
    event FeeTokenAdded(
        string indexed tokenSymbol,
        address tokenAddress,
        uint256 computingPrice
    );

    // emit in updateFeeToken
    event FeeTokenUpdated(
        string indexed tokenSymbol,
        address tokenAddress,
        uint256 computingPrice
    );

    // emit in deleteFeeToken
    event FeeTokenDeleted(
        string indexed tokenSymbol
    );

    // emit in transfer token
    event TokenTransfered(
        address from,
        string tokenSymbol,
        uint256 amount
    );

    // emit in withdraw
    event TokenWithdrawn(
        address to,
        string tokenSymbol,
        uint256 amount
    );

    // emit in lock
    event FeeLocked(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    // emit in unlock
    event FeeUnlocked(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    // emit in settle
    event FeeSettled(
        bytes32 indexed taskId,
        string tokenSymbol,
        uint256 amount
    );

    /**
     * @notice TaskMgt contract request transfer tokens.
     * @param from The address from which transfer token.
     * @param tokenSymbol The token symbol
     * @param amount The amount of tokens to be transfered
     */
    function transferToken(
        address from,
        string calldata tokenSymbol,
        uint256 amount
    ) payable external;

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
    ) external;

    /**
     * @notice TaskMgt contract request locking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param toLockAmount The amount of fee to lock.
     * @return Returns true if the locking is successful.
     */
    function lock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol,
        uint256 toLockAmount 
    ) external returns (bool);

    /**
     * @notice TaskMgt contract request unlocking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @return Return true if the unlocking is successful.
     */
    function unlock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol
    ) external returns (bool);

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
    ) external;

    /**
     * @notice TaskMgt contract request settlement fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function settle(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external returns (bool);
    
    /**
     * @notice Add the fee token.
     * @param tokenSymbol The new fee token symbol.
     * @param tokenAddress The new fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the adding is successful.
     */
    function addFeeToken(string calldata tokenSymbol, address tokenAddress, uint256 computingPrice) external returns (bool);

    /**
     * @notice Update the fee token.
     * @param tokenSymbol The fee token symbol.
     * @param tokenAddress The fee token address.
     * @param computingPrice The computing price for the token.
     * @return Returns true if the updating is successful.
     */
    function updateFeeToken(string calldata tokenSymbol, address tokenAddress, uint256 computingPrice) external returns (bool);

    /**
     * @notice Delete the fee token.
     * @param tokenSymbol The fee token symbol.
     */
    function deleteFeeToken(string calldata tokenSymbol) external;

    /**
     * @notice Get the all fee tokens.
     * @return Returns the all fee tokens info.
     */
    function getFeeTokens() external view returns (FeeTokenInfo[] memory);

    /**
     * @notice Get fee token by token symbol.
     * @param tokenSymbol The token symbol.
     * @return Returns the fee token.
     */
    function getFeeTokenBySymbol(string calldata tokenSymbol) external view returns (FeeTokenInfo memory);

    /**
     * @notice Determine whether a token can pay the handling fee.
     * @return Returns true if a token can pay fee, otherwise returns false.
     */
    function isSupportToken(string calldata tokenSymbol) external view returns (bool);

    /**
     * @notice Get balance info.
     * @param dataUser The address of data user
     * @param tokenSymbol The token symbol for the data user
     * @return Balance for the data user
     */
    function getBalance(address dataUser, string calldata tokenSymbol) external view returns (Balance memory);

}
