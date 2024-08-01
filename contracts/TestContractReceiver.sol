// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TestContractReceiver{

    event Received(address sender, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function withdraw() external {
        require(msg.sender == owner, "Only the owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

}
