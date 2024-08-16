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
import "../../../contracts/Router.sol";

// # To deploy and verify our contract
// forge script script/deploy/mainnet/Mainnet_DeployPADONetworkContracts.s.sol:Mainnet_DeployPADONetworkContracts --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY //--broadcast -vvvv
contract Mainnet_DeployPADONetworkContracts is Utils, ExistingDeploymentParser {
    string public existingDeploymentInfoPath =
        string(
            bytes(
                "./script/deploy/mainnet/output/1/padonetwork_middleware_deployment_data_mainnet.json"
            )
        );
    string public outputPath =
        string.concat(
            "script/deploy/mainnet/output/1/padonetwork_contracts_deployment_data_mainnet.json"
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
    FeeMgt public feeMgtImplementation;
    DataMgt public dataMgt;
    DataMgt public dataMgtImplementation;
    TaskMgt public taskMgt;
    TaskMgt public taskMgtImplementation;
    Router public router;
    Router public routerImplementation;

    function run()
        external
        returns (WorkerMgt, FeeMgt, DataMgt, TaskMgt, ProxyAdmin, Router)
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
        networkOwner = stdJson.readAddress(
            config_data,
            ".permissions.networkOwner"
        );
        networkUpgrader = stdJson.readAddress(
            config_data,
            ".permissions.networkUpgrader"
        );

        vm.startBroadcast();
        _deployPadoNeworkContracts(config_data);

        vm.stopBroadcast();

        return (workerMgt, feeMgt, dataMgt, taskMgt, proxyAdmin,router);
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployPadoNeworkContracts(string memory config_data) internal {
        uint256 computingPriceForETH = 1000000000;
        proxyAdmin = new ProxyAdmin();
        emptyContract = EmptyContract(
            0x9690d52B1Ce155DB2ec5eCbF5a262ccCc7B3A6D2
        );

        console.log("proxyAdmin");
        registryCoordinator = PADORegistryCoordinator(
            stdJson.readAddress(config_data, ".addresses.registryCoordinator")
        );
        console.log("registryCoordinator is %s", address(registryCoordinator));
        //workerMgt
        workerMgt = WorkerMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        console.log("workerMgt proxy deployed");

        //feeMgt
        feeMgt = FeeMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        console.log("feeMgt proxy deployed");

        //dataMgt
        dataMgt = DataMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        console.log("dataMgt proxy deployed");

        //taskMgt
        taskMgt = TaskMgt(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyContract),
                        address(proxyAdmin),
                        ""
                    )
                )
            )
        );

        console.log("taskMgt proxy deployed");

        //router
        router = Router(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(emptyContract),
                        address(proxyAdmin),
                        ""
                    )
                )
            )
        );

        console.log("router proxy deployed");

        workerMgtImplementation = new WorkerMgt();
        feeMgtImplementation = new FeeMgt();
        dataMgtImplementation = new DataMgt();
        taskMgtImplementation = new TaskMgt();
        routerImplementation = new Router();
        console.log("implementation proxy deployed");

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(workerMgt))),
            address(workerMgtImplementation),
            abi.encodeWithSelector(
                WorkerMgt.initialize.selector,
                registryCoordinator,
                networkOwner
            )
        );
        console.log("upgrade workerMgt");

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(feeMgt))),
            address(feeMgtImplementation),
            abi.encodeWithSelector(
                FeeMgt.initialize.selector,
                router,
                computingPriceForETH,
                networkOwner
            )
        );

        console.log("upgrade feeMgt");

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(dataMgt))),
            address(dataMgtImplementation),
            abi.encodeWithSelector(DataMgt.initialize.selector, router, networkOwner)
        );
        console.log("upgrade dataMgt");

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(taskMgt))),
            address(taskMgtImplementation),
            abi.encodeWithSelector(
                TaskMgt.initialize.selector,
                router,
                networkOwner
            )
        );
        console.log("upgrade taskMgt");

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(router))),
            address(routerImplementation),
            abi.encodeWithSelector(
                Router.initialize.selector,
                dataMgt,
                feeMgt,
                taskMgt,
                workerMgt,
                networkOwner
            )
        );
        console.log("upgrade router");


        console.log(
            "registryCoordinator is:%s,owner is:%s",
            address(registryCoordinator),
            registryCoordinator.owner()
        );
        console.log("workerMgt is:%s", address(workerMgt));
        registryCoordinator.setWorkerMgt(workerMgt);
        proxyAdmin.transferOwnership(networkUpgrader);
        console.log("networkUpgrader is:%s", address(networkUpgrader));

        _writeOutput(config_data);
    }

    function _writeOutput(string memory config_data) internal {
        string memory parent_object = "parent object";
        string memory deployed_addresses = "addresses";
        vm.serializeAddress(
            deployed_addresses,
            "workerMgt",
            address(workerMgt)
        );
        vm.serializeAddress(
            deployed_addresses,
            "workerMgtImplementation",
            address(workerMgtImplementation)
        );

        vm.serializeAddress(deployed_addresses, "feeMgt", address(feeMgt));
        vm.serializeAddress(
            deployed_addresses,
            "feeMgtImplementation",
            address(feeMgtImplementation)
        );

        vm.serializeAddress(deployed_addresses, "dataMgt", address(dataMgt));
        vm.serializeAddress(
            deployed_addresses,
            "dataMgtImplementation",
            address(dataMgtImplementation)
        );

        vm.serializeAddress(deployed_addresses, "taskMgt", address(taskMgt));
        vm.serializeAddress(
            deployed_addresses,
            "proxyAdmin",
            address(proxyAdmin)
        );


        vm.serializeAddress(deployed_addresses, "router", address(router));
        vm.serializeAddress(
            deployed_addresses,
            "routerImplementation",
            address(routerImplementation)
        );

        string memory deployed_addresses_output = vm.serializeAddress(
            deployed_addresses,
            "taskMgtImplementation",
            address(taskMgtImplementation)
        );


        string memory finalJson = vm.serializeString(
            parent_object,
            deployed_addresses,
            deployed_addresses_output
        );
        vm.writeJson(finalJson, outputPath);
    }
}
