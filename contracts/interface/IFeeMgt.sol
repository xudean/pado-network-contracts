// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @notice A struct representing a fee token symbol and address.
 */
struct FeeTokenInfo {
    string symbol; // Fee token symbol.
    address tokenAddress; // Fee token address.
}
/**
 * @notice A struct representing allowance for data user.
 */
struct Allowance {
    uint256 free;
    uint256 locked;
}
/**
 * @title IFeeMgt
 * @notice FeeMgt - Fee Management interface.
 */
interface IFeeMgt {
    /**
     * @notice TaskMgt contract request transfer tokens.
     * @param tokenSymbol The token symbol
     * @param amount The amount of tokens to be transfered
     */
    function transferToken(
        string calldata tokenSymbol,
        uint256 amount
    ) payable external;

    /**
     * @notice TaskMgt contract request locking fee.
     * @param taskId The task id.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param computingPrice The computing price of the task.
     * @param workerOwners The owner address of all workers which have already run the task.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function lock(
        bytes32 taskId,
        address submitter,
        string calldata tokenSymbol,
        uint256 computingPrice,
        address[] calldata workerOwners,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external returns (bool);

    /**
     * @notice TaskMgt contract request settlement fee.
     * @param taskId The task id.
     * @param taskResultStatus The task run result status.
     * @param submitter The submitter of the task.
     * @param tokenSymbol The fee token symbol.
     * @param computingPrice The computing price of the task.
     * @param workerOwners The owner address of all workers which have already run the task.
     * @param dataPrice The data price of the task.
     * @param dataProviders The address of data providers which provide data to the task.
     * @return Returns true if the settlement is successful.
     */
    function settle(
        bytes32 taskId,
        uint8 taskResultStatus,
        address submitter,
        string calldata tokenSymbol,
        uint256 computingPrice,
        address[] calldata workerOwners,
        uint256 dataPrice,
        address[] calldata dataProviders
    ) external returns (bool);
    
    /**
     * @notice Add the fee token.
     * @param tokenSymbol The new fee token symbol.
     * @param tokenAddress The new fee token address.
     * @return Returns true if the adding is successful.
     */
    function addFeeToken(string calldata tokenSymbol, address tokenAddress) external returns (bool);

    /**
     * @notice Get the all fee tokens.
     * @return Returns the all fee tokens info.
     */
    function getFeeTokens() external view returns (FeeTokenInfo[] memory);

    /**
     * @notice Determine whether a token can pay the handling fee.
     * @return Returns true if a token can pay fee, otherwise returns false.
     */
    function isSupportToken(string calldata tokenSymbol) external view returns (bool);
}
