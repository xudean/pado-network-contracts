// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Utils} from "../utils/Utils.s.sol";
import {UpgradeContractParser} from "../utils/UpgradeContractParser.sol";

import "../../../contracts/WorkerMgt.sol";
import "../../../contracts/FeeMgt.sol";
import "../../../contracts/DataMgt.sol";
import "../../../contracts/TaskMgt.sol";
import "../../../contracts/Router.sol";

//forge script script/deploy/mainnet/Mainnet_UpgradePADONetworkContracts.s.sol:Mainnet_UpgradePADONetworkContracts --rpc-url [rpc_url]  --private-key [private_key] --broadcast
contract Mainnet_UpgradePADONetworkContracts is Utils, UpgradeContractParser {
    string public existingUpgradeInfoPath =
        string(
            bytes(
                "./script/deploy/mainnet/config/padonetwork_contracts_deployment_data_mainnet.json"
            )
        );
    address public networkOwner;
    address public networkUpgrader;

    //PADO Network contracts
    WorkerMgt public workerMgt;
    WorkerMgt public workerMgtImplementation;
    FeeMgt public feeMgt;
    FeeMgt public feeMgtImplementation;
    DataMgt public dataMgt;
    DataMgt public dataMgtImplementation;
    TaskMgt public taskMgt;
    TaskMgt public taskMgtImplementation;
    Router public router;
    Router public routerImplementation;

    function run() external {
        _readConfigData();

        require(
            proxyAdmin.owner() == msg.sender,
            "Caller is not the owner of ProxyAdmin"
        );
        vm.startBroadcast();
        _upgradeContracts();
        vm.stopBroadcast();
    }

    function _readConfigData() internal {
        // READ JSON CONFIG DATA
        string memory config_data = vm.readFile(existingUpgradeInfoPath);
        workerMgt = WorkerMgt(
            stdJson.readAddress(config_data, ".addresses.workerMgt")
        );
        proxyAdmin = ProxyAdmin(
            stdJson.readAddress(config_data, ".addresses.proxyAdmin")
        );
        dataMgt = DataMgt(
            stdJson.readAddress(config_data, ".addresses.dataMgt")
        );
        feeMgt = FeeMgt(stdJson.readAddress(config_data, ".addresses.feeMgt"));
        taskMgt = TaskMgt(
            payable(stdJson.readAddress(config_data, ".addresses.taskMgt"))
        );
        taskMgt = TaskMgt(
            payable(stdJson.readAddress(config_data, ".addresses.taskMgt"))
        );

        router = Router(payable(stdJson.readAddress(config_data, ".addresses.router")));
    }

    function _upgradeContracts() internal {
        workerMgtImplementation = new WorkerMgt();
        dataMgtImplementation = new DataMgt();
        feeMgtImplementation = new FeeMgt();
        taskMgtImplementation = new TaskMgt();
        routerImplementation = new Router();

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(workerMgt))),
            address(workerMgtImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(dataMgt))),
            address(dataMgtImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(feeMgt))),
            address(feeMgtImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(taskMgt))),
            address(taskMgtImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(router))),
            address(routerImplementation)
        );
        console.log("workerMgt proxy is:{}", address(workerMgt));
        console.log("feeMgt proxy is:{}", address(feeMgt));
        console.log("dataMgt proxy is:{}", address(dataMgt));
        console.log("taskMgt proxy is:{}", address(taskMgt));
        console.log("router proxy is:{}", address(router));

        console.log(
            "workerMgtImplementation  is:{}",
            address(workerMgtImplementation)
        );
        console.log(
            "feeMgtImplementation  is:{}",
            address(feeMgtImplementation)
        );
        console.log(
            "dataMgtImplementation  is:{}",
            address(dataMgtImplementation)
        );
        console.log(
            "taskMgtImplementation  is:{}",
            address(taskMgtImplementation)
        );
        console.log(
            "routerImplementation  is:{}",
            address(routerImplementation)
        );
    }
}
