// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../contracts/TestContractSender.sol";
import "../contracts/TestContractReceiver.sol";
import "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

//forge script script/deploy/holesky/DeployTestContract.s.sol:DeployTestContract --rpc-url [rpc_url]  --private-key [private_key] --broadcast
contract DeployTestContract is Script, Test {
    function run() external returns (TestContractSender,TestContractReceiver) {
        vm.startBroadcast();
        EmptyContract emptyComtract = EmptyContract(
            0x9690d52B1Ce155DB2ec5eCbF5a262ccCc7B3A6D2
        );

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // receiver
        TestContractReceiver testContractReceiverProxy = TestContractReceiver(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyComtract),
                        address(proxyAdmin),
                        ""
                    )
                )
            )
        );
        TestContractReceiver TestContractReceiverImpl = new TestContractReceiver();
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(testContractReceiverProxy))),
            address(TestContractReceiverImpl)
        );

        //sender
        TestContractSender testContractProxy = TestContractSender(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyComtract),
                        address(proxyAdmin),
                        ""
                    )
                )
            )
        );

        TestContractSender TestContractImpl = new TestContractSender();
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(testContractProxy))),
            address(TestContractImpl)
        );
        testContractProxy.setReceiver(address(testContractReceiverProxy));

        vm.stopBroadcast();
        return (testContractProxy,testContractReceiverProxy);
    }
}
