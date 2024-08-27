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
contract Holesky_Update_Task is Utils, ExistingDeploymentParser {
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


    FeeMgt public feeMgt;
//    FeeMgt public feeMgtImplementation;
    DataMgt public dataMgt;
//    DataMgt public dataMgtImplementation;
    TaskMgt public taskMgt;
    TaskMgt public taskMgtImplementation;

    function run()
    external
    returns (WorkerMgt, FeeMgt, DataMgt, TaskMgt, ProxyAdmin)
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

        vm.startBroadcast();
        _deployPadoNeworkContracts(config_data);

        vm.stopBroadcast();

        return (workerMgt, feeMgt, dataMgt, taskMgt, proxyAdmin);
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployPadoNeworkContracts(string memory config_data) internal {

        proxyAdmin = ProxyAdmin(stdJson.readAddress(
            config_data,
            ".addresses.proxyAdmin"
        ));
        console.log("proxyAdmin:%s", address(proxyAdmin));
        //taskMgt
        taskMgt = TaskMgt(payable(stdJson.readAddress(
            config_data,
            ".addresses.taskMgt"
        )));

        console.log("taskMgt proxy deployed");

        taskMgtImplementation = new TaskMgt();
        console.log("proxyAdmin:", address(proxyAdmin));

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(taskMgt))),
            address(taskMgtImplementation)
        );
        console.log("upgrade taskMgt");
//        _writeOutput(config_data);
    }

}
