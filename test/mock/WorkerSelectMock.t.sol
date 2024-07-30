// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {console} from "forge-std/Test.sol";

contract WorkerSelectMock {
    uint32[] public workerIds;
    mapping(address => uint32) addressNonce;

    function addWorker(uint32 workerId) external {
        workerIds.push(workerId);
    }


    /**
     * @notice Select workers randomly.
     * @param n The number of workers to select.
     * @return Returns the selected workers.
     */
    function selectWorkers(uint256 n) public returns (uint32[] memory) {
        require(
            workerIds.length >= n,
            "Not enough workers to provide computation"
        );

        //generate a random number
        uint256 randomness = _getRandomNumber();

        uint256[] memory indices = new uint256[](workerIds.length);
        for (uint256 i = 0; i < workerIds.length; i++) {
            indices[i] = i;
        }

        // Fisher-Yates shuffle algorithm
        for (uint256 i = 0; i < n; i++) {
            uint256 j = i + (randomness % (workerIds.length - i));
            (indices[i], indices[j]) = (indices[j], indices[i]);
            randomness = uint256(keccak256(abi.encodePacked(randomness, i)));
        }
        uint32[] memory selectedWorkers = new uint32[](n);
        // Select the first n indices
        for (uint256 i = 0; i < n; i++) {
            //save workerId
            selectedWorkers[i] = workerIds[indices[i]];
        }
        return selectedWorkers;
    }

    //generate a random number
    function _getRandomNumber() internal returns (uint256) {
        console.log("block.timestamp:%s", block.timestamp);
        console.log("msg.sender:%s", msg.sender);
        console.log("nonce:%d", addressNonce[msg.sender]);
        bytes32 hash = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                addressNonce[msg.sender]
            )
        );
        //This operation consumes some gas but guarantees the quality of the random numbers generated.
        addressNonce[msg.sender] = addressNonce[msg.sender] + 1;
        return uint256(hash);
    }
}
