// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Utils} from "../utils/Utils.s.sol";
import {ExistingDeploymentParser} from "../utils/ExistingDeploymentParser.sol";

// OpenZeppelin
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../contracts/PADORegistryCoordinator.sol";

import "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

import "../../../contracts/WorkerMgt.sol";
import "../../../contracts/FeeMgt.sol";
import "../../../contracts/DataMgt.sol";
import "../../../contracts/TaskMgt.sol";

// # To deploy and verify our contract
// forge script script/deploy/holesky/Holesky_DeployPADONetworkContracts.s.sol:Holesky_DeployPADONetworkContracts --rpc-url $HOLESKY_RPC_URL --private-key $PRIVATE_KEY //--broadcast -vvvv
contract Holesky_Update_Worker is Utils, ExistingDeploymentParser {
    string public existingDeploymentInfoPath =
    string(
        bytes(
            "script/deploy/holesky/output/17000/padonetwork_contracts_deployment_data_holesky.json"
        )
    );

    ProxyAdmin public proxyAdmin;
    address public networkOwner;
    address public networkUpgrader;

    // Middleware contracts to deploy
    PADORegistryCoordinator public registryCoordinator;
    PADORegistryCoordinator public registryCoordinatorImplementation;

    //PADO Network contracts
    WorkerMgt public workerMgt;
    WorkerMgt public workerMgtImplementation;

//    FeeMgt public feeMgt;
////    FeeMgt public feeMgtImplementation;
//    DataMgt public dataMgt;
////    DataMgt public dataMgtImplementation;
//    TaskMgt public taskMgt;
//    TaskMgt public taskMgtImplementation;

    function run()
    external
    returns (WorkerMgt, ProxyAdmin)
    {
        console.log("deployer is:%s", msg.sender);

        // READ JSON CONFIG DATA
        string memory config_data = vm.readFile(existingDeploymentInfoPath);

        // check that the chainID matches the one in the config
        uint256 currentChainId = block.chainid;
        uint256 configChainId = stdJson.readUint(
            config_data,
            ".chainInfo.chainId"
        );
        emit log_named_uint("You are deploying on ChainID", currentChainId);
        require(
            configChainId == currentChainId,
            "You are on the wrong chain for this config"
        );

        // parse the addresses of permissioned roles
//        networkOwner = stdJson.readAddress(
//            config_data,
//            ".permissions.networkOwner"
//        );
//        networkUpgrader = stdJson.readAddress(
//            config_data,
//            ".permissions.networkUpgrader"
//        );

        vm.startBroadcast();
        _deployPadoNeworkContracts(config_data);

        vm.stopBroadcast();

        return (workerMgt, proxyAdmin);
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployPadoNeworkContracts(string memory config_data) internal {
        uint256 computingPriceForETH = 1000000000;
        proxyAdmin = ProxyAdmin(stdJson.readAddress(
            config_data,
            ".addresses.proxyAdmin"
        ));

        console.log("proxyAdmin");
        //workerMgt
        workerMgt = WorkerMgt(stdJson.readAddress(
            config_data,
            ".addresses.workerMgt"
        ));
        console.log("workerMgt is %s", address(workerMgt));

        workerMgtImplementation = new WorkerMgt();

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(workerMgt))),
            address(workerMgtImplementation)
        );
        console.log("upgrade taskMgt");
        console.log("workerMgt is:%s", address(workerMgt));
        workerMgt.setDataMgtAddr(stdJson.readAddress(
            config_data,
            ".addresses.dataMgt"
        ));

    }

    function getVersion() external pure returns (uint256)  {
        return 1;
    }
//
//    function _writeOutput(string memory config_data) internal {
//        string memory parent_object = "parent object";
//        string memory deployed_addresses = "addresses";
//        vm.serializeAddress(
//            deployed_addresses,
//            "workerMgt",
//            address(workerMgt)
//        );
//        vm.serializeAddress(
//            deployed_addresses,
//            "workerMgtImplementation",
//            address(workerMgtImplementation)
//        );
//
//        vm.serializeAddress(deployed_addresses, "feeMgt", address(feeMgt));
////        vm.serializeAddress(
////            deployed_addresses,
////            "feeMgtImplementation",
////            address(feeMgtImplementation)
////        );
//
//        vm.serializeAddress(deployed_addresses, "dataMgt", address(dataMgt));
////        vm.serializeAddress(
////            deployed_addresses,
////            "dataMgtImplementation",
////            address(dataMgtImplementation)
////        );
//
//        vm.serializeAddress(deployed_addresses, "taskMgt", address(taskMgt));
//        vm.serializeAddress(
//            deployed_addresses,
//            "proxyAdmin",
//            address(proxyAdmin)
//        );
//
//        string memory deployed_addresses_output = vm.serializeAddress(
//            deployed_addresses,
//            "taskMgtImplementation",
//            address(taskMgtImplementation)
//        );
//
//        string memory finalJson = vm.serializeString(
//            parent_object,
//            deployed_addresses,
//            deployed_addresses_output
//        );
//        vm.writeJson(finalJson, outputPath);
//    }
}
