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
contract Holesky_Update_Fee is Utils, ExistingDeploymentParser {
    string public existingDeploymentInfoPath =
    string(
        bytes(
            "./script/deploy/holesky/output/17000/padonetwork_middleware_deployment_data_holesky.json"
        )
    );
    string public outputPath =
    string.concat(
        "script/deploy/holesky/output/17000/padonetwork_contracts_deployment_data_holesky_1.json"
    );

    ProxyAdmin public proxyAdmin;
    address public networkOwner;
    address public networkUpgrader;

    FeeMgt public feeMgt;
    FeeMgt public feeMgtImplementation;


    function run()
    external
    returns (FeeMgt , ProxyAdmin)
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

        return (feeMgt,proxyAdmin);
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployPadoNeworkContracts(string memory config_data) internal {
        proxyAdmin = ProxyAdmin(0x457c30270eB49e20CB1b8336bA9A24D2e09379E1);

        console.log("proxyAdmin");

        feeMgt = FeeMgt(0xfcde80f61B97FA974A5E1De2A2580A5843CaABE2);

        console.log("feeMgt address is:%s",address(feeMgt));

//        dataMgtImplementation = new DataMgt();
        feeMgtImplementation = new FeeMgt();

        console.log("networkOwner:",address(networkOwner));
        console.log("proxyAdmin:",address(proxyAdmin));
        console.log("feeMgtImplementation:",address(feeMgtImplementation));

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(feeMgt))),
            address(feeMgtImplementation)
        );
        console.log("upgrade feeMgt");

    }

    function getVersion() external pure returns (uint256)  {
        return 1;
    }

}
