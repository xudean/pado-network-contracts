// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {ITaskMgt} from "./ITaskMgt.sol";
import {Allowance, FeeTokenInfo, TaskStatus} from "../types/Common.sol";

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

    // emit in transfer token
    event TokenTransfered(
        address from,
        string tokenSymbol,
        uint256 amount
    );

    // emit in lock
    event FeeLocked(
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

    // emit in setTaskMgt
    event TaskMgtUpdated(
        address from,
        address to
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
    ) external returns (bool);

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
     * @notice Get allowance info.
     * @param dataUser The address of data user
     * @param tokenSymbol The token symbol for the data user
     * @return Allowance for the data user
     */
    function getAllowance(address dataUser, string calldata tokenSymbol) external view returns (Allowance memory);

    /**
     * @notice Set TaskMgt.
     * @param taskMgt The TaskMgt
     */
    function setTaskMgt(ITaskMgt taskMgt) external;
}
