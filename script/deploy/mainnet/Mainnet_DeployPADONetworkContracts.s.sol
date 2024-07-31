// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import {Utils} from "../utils/Utils.s.sol";
import {ExistingDeploymentParser} from "../utils/ExistingDeploymentParser.sol";
import "forge-std/console.sol";


// OpenZeppelin
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// EigenLayer contracts
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/core/DelegationManager.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/core/AVSDirectory.sol";
import {PauserRegistry} from "eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";

// EigenLayer middleware
import {IPauserRegistry} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/src/BLSSignatureChecker.sol";
import {IBLSSignatureChecker} from "@eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {ServiceManager} from "../../../contracts/ServiceManager.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {RewardsCoordinator} from "../../../lib/eigenlayer-middleware/lib/eigenlayer-contracts/src/contracts/core/RewardsCoordinator.sol";
import "../../../contracts/PADORegistryCoordinator.sol";

// # To deploy and verify our contract
// forge script script/deploy/mainnet/Holesky_DeployPADONetworkContracts.s.sol --rpc-url $HOLESKY_RPC_URL --private-key $PRIVATE_KEY //--broadcast -vvvv
contract Holesky_DeployPADONetworkContracts is Utils, ExistingDeploymentParser {
    string public existingDeploymentInfoPath =
    string(
        bytes(
            "./script/deploy/mainnet/config/eigenlayer_deployment_mainnet.json"
        )
    );
    string public deployConfigPath =
    string(
        bytes(
            "./script/deploy/mainnet/config/middleware_config_mainnet.json"
        )
    );
    string public outputPath =
    string.concat(
        "script/deploy/mainnet/output/17000/padonetwork_middleware_deployment_data_mainnet.json"
    );

    ProxyAdmin public proxyAdmin;
    PauserRegistry public pauserRegistry;
    address public networkOwner;
    address public networkUpgrader;
    address public pauser;
    uint256 public initialPausedStatus;

    // Middleware contracts to deploy
    PADORegistryCoordinator public registryCoordinator;
    ServiceManager public serviceManager;
    BLSApkRegistry public blsApkRegistry;
    StakeRegistry public stakeRegistry;
    IndexRegistry public indexRegistry;
    OperatorStateRetriever public operatorStateRetriever;

    PADORegistryCoordinator public registryCoordinatorImplementation;
    StakeRegistry public stakeRegistryImplementation;
    BLSApkRegistry public blsApkRegistryImplementation;
    IndexRegistry public indexRegistryImplementation;
    ServiceManager public serviceManagerImplementation;

    function run()
    external
    returns (
        PADORegistryCoordinator,
        ServiceManager,
        StakeRegistry,
        BLSApkRegistry,
        IndexRegistry,
        OperatorStateRetriever,
        ProxyAdmin
    )
    {
        console.log("deployer is:%s",msg.sender);
        // get info on all the already-deployed contracts
        _parseDeployedContracts(existingDeploymentInfoPath);

        // READ JSON CONFIG DATA
        string memory config_data = vm.readFile(deployConfigPath);

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
        networkOwner = stdJson.readAddress(config_data, ".permissions.owner");
        networkUpgrader = stdJson.readAddress(
            config_data,
            ".permissions.upgrader"
        );
        pauser = stdJson.readAddress(config_data, ".permissions.pauser");
        initialPausedStatus = stdJson.readUint(
            config_data,
            ".permissions.initialPausedStatus"
        );

        vm.startBroadcast();
        (
            registryCoordinator,
            serviceManager,
            stakeRegistry,
            blsApkRegistry,
            indexRegistry,
            operatorStateRetriever,
            proxyAdmin
        ) = _deployMiddlewareContracts(
            delegationManager,
            avsDirectory,
            rewardsCoordinator,
            config_data
        );

        vm.stopBroadcast();

        // sanity checks
        _verifyContractPointers(
            blsApkRegistry,
            serviceManager,
            registryCoordinator,
            indexRegistry,
            stakeRegistry
        );

        _verifyImplementations();

        _verifyInitalizations(config_data);

        //write output
        _writeOutput(config_data);

        return (
            registryCoordinator,
            serviceManager,
            stakeRegistry,
            blsApkRegistry,
            indexRegistry,
            operatorStateRetriever,
            proxyAdmin
        );
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployMiddlewareContracts(
        IDelegationManager delegationManager,
        IAVSDirectory _avsDirectory,
        IRewardsCoordinator _rewardsCoordinator,
        string memory config_data
    )
    internal
    returns (
        PADORegistryCoordinator,
        ServiceManager,
        StakeRegistry,
        BLSApkRegistry,
        IndexRegistry,
        OperatorStateRetriever,
        ProxyAdmin
    )
    {
        // Deploy proxy admin for ability to upgrade proxy contracts
        proxyAdmin = new ProxyAdmin();

        if (pauser == address(0)) {
            // Deploy PauserRegistry with msg.sender as the initial pauser
            address[] memory pausers = new address[](1);
            pausers[0] = networkOwner;
            address unpauser = networkOwner;
            pauserRegistry = new PauserRegistry(pausers, unpauser);
        } else {
            pauserRegistry = PauserRegistry(pauser);
        }

        /**
         * First, deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        registryCoordinator = PADORegistryCoordinator(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        stakeRegistry = StakeRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        indexRegistry = IndexRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        blsApkRegistry = BLSApkRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        serviceManager = ServiceManager(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        stakeRegistryImplementation = new StakeRegistry(
            registryCoordinator,
            delegationManager
        );
        blsApkRegistryImplementation = new BLSApkRegistry(
            registryCoordinator
        );
        indexRegistryImplementation = new IndexRegistry(registryCoordinator);
        serviceManagerImplementation = new ServiceManager(
            _avsDirectory,
            rewardsCoordinator,
            registryCoordinator,
            stakeRegistry
        );

        // Third, upgrade the proxy contracts to point to the implementations
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(stakeRegistry))),
            address(stakeRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsApkRegistry))),
            address(blsApkRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))),
            address(indexRegistryImplementation)
        );

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(serviceManager))),
            address(serviceManagerImplementation),
            abi.encodeWithSelector(
                ServiceManager.initialize.selector,
                networkOwner // _initialOwner
            )
        );

        registryCoordinatorImplementation = new PADORegistryCoordinator(
            serviceManager,
            stakeRegistry,
            blsApkRegistry,
            indexRegistry
        );

        _initRegistryCoordinator(
            proxyAdmin,
            registryCoordinator,
            registryCoordinatorImplementation,
            pauserRegistry,
            config_data
        );

        operatorStateRetriever = new OperatorStateRetriever();

        // transfer ownership of proxy admin to upgrader
        proxyAdmin.transferOwnership(networkUpgrader);

        return (
            registryCoordinator,
            serviceManager,
            stakeRegistry,
            blsApkRegistry,
            indexRegistry,
            operatorStateRetriever,
            proxyAdmin
        );
    }

    function _initRegistryCoordinator(
        ProxyAdmin _proxyAdmin,
        IRegistryCoordinator _registryCoordinator,
        PADORegistryCoordinator _registryCoordinatorImplementation,
        PauserRegistry _pauserRegistry,
        string memory config_data
    ) internal {
        // parse initalization params and permissions from config data
        (
            uint96[] memory minimumStakeForQuourm,
            IStakeRegistry.StrategyParams[][]
            memory strategyAndWeightingMultipliers
        ) = _parseStakeRegistryParams(config_data);
        (
            IRegistryCoordinator.OperatorSetParam[] memory operatorSetParams,
            address churner,
            address ejector
        ) = _parseRegistryCoordinatorParams(config_data);

        _proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(_registryCoordinator))),
            address(_registryCoordinatorImplementation),
            abi.encodeWithSelector(
                PADORegistryCoordinator.initialize.selector,
                networkOwner,
                churner,
                ejector,
                _pauserRegistry,
                initialPausedStatus,
                operatorSetParams,
                minimumStakeForQuourm,
                strategyAndWeightingMultipliers
            )
        );
    }

    function _parseStakeRegistryParams(
        string memory config_data
    )
    internal
    pure
    returns (
        uint96[] memory minimumStakeForQuourm,
        IStakeRegistry.StrategyParams[][]
        memory strategyAndWeightingMultipliers
    )
    {
        bytes memory stakesConfigsRaw = stdJson.parseRaw(
            config_data,
            ".minimumStakes"
        );
        minimumStakeForQuourm = abi.decode(stakesConfigsRaw, (uint96[]));

        bytes memory strategyConfigsRaw = stdJson.parseRaw(
            config_data,
            ".strategyWeights"
        );
        strategyAndWeightingMultipliers = abi.decode(
            strategyConfigsRaw,
            (IStakeRegistry.StrategyParams[][])
        );
    }

    function _parseRegistryCoordinatorParams(
        string memory config_data
    )
    internal
    pure
    returns (
        IRegistryCoordinator.OperatorSetParam[] memory operatorSetParams,
        address churner,
        address ejector
    )
    {
        bytes memory operatorConfigsRaw = stdJson.parseRaw(
            config_data,
            ".operatorSetParams"
        );
        operatorSetParams = abi.decode(
            operatorConfigsRaw,
            (IRegistryCoordinator.OperatorSetParam[])
        );

        churner = stdJson.readAddress(config_data, ".permissions.churner");
        ejector = stdJson.readAddress(config_data, ".permissions.ejector");
    }

    function _verifyContractPointers(
        BLSApkRegistry _apkRegistry,
        ServiceManager _serviceManager,
        PADORegistryCoordinator _registryCoordinator,
        IndexRegistry _indexRegistry,
        StakeRegistry _stakeRegistry
    ) internal view {
        require(
            address(_apkRegistry.registryCoordinator()) ==
            address(registryCoordinator),
            "blsApkRegistry.registryCoordinator() != registryCoordinator"
        );

        require(
            address(_indexRegistry.registryCoordinator()) ==
            address(registryCoordinator),
            "indexRegistry.registryCoordinator() != registryCoordinator"
        );

        require(
            address(_stakeRegistry.registryCoordinator()) ==
            address(registryCoordinator),
            "stakeRegistry.registryCoordinator() != registryCoordinator"
        );
        require(
            address(_stakeRegistry.delegation()) == address(delegationManager),
            "stakeRegistry.delegationManager() != delegation"
        );

        // TODO: add this checks once we update the service manager properties to be public
        // require(address(_serviceManager.registryCoordinator()) == address(registryCoordinator), "_serviceManager.registryCoordinator() != registryCoordinator");
        // require(address(_serviceManager.stakeRegistry()) == address(stakeRegistry), "_serviceManager.stakeRegistry() != stakeRegistry");

        require(
            address(_registryCoordinator.serviceManager()) ==
            address(_serviceManager),
            "registryCoordinator.serviceManager() != _serviceManager"
        );
        require(
            address(_registryCoordinator.stakeRegistry()) ==
            address(stakeRegistry),
            "registryCoordinator.stakeRegistry() != stakeRegistry"
        );
        require(
            address(_registryCoordinator.blsApkRegistry()) ==
            address(_apkRegistry),
            "registryCoordinator.blsApkRegistry() != _apkRegistry"
        );
        require(
            address(_registryCoordinator.indexRegistry()) ==
            address(indexRegistry),
            "registryCoordinator.indexRegistry() != indexRegistry"
        );
    }

    function _verifyImplementations() internal view {
        require(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(serviceManager)))
            ) == address(serviceManagerImplementation),
            "ServiceManager: implementation set incorrectly"
        );
        require(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(
                    payable(address(registryCoordinator))
                )
            ) == address(registryCoordinatorImplementation),
            "registryCoordinator: implementation set incorrectly"
        );
        require(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(blsApkRegistry)))
            ) == address(blsApkRegistryImplementation),
            "blsApkRegistry: implementation set incorrectly"
        );
        require(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(indexRegistry)))
            ) == address(indexRegistryImplementation),
            "indexRegistry: implementation set incorrectly"
        );
        require(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(stakeRegistry)))
            ) == address(stakeRegistryImplementation),
            "stakeRegistry: implementation set incorrectly"
        );
    }

    function _verifyInitalizations(string memory config_data) internal {
        (
            uint96[] memory minimumStakeForQuourm,
            IStakeRegistry.StrategyParams[][]
            memory strategyAndWeightingMultipliers
        ) = _parseStakeRegistryParams(config_data);
        (
            IRegistryCoordinator.OperatorSetParam[] memory operatorSetParams,
            address churner,
            address ejector
        ) = _parseRegistryCoordinatorParams(config_data);

        require(
            serviceManager.owner() == networkOwner,
            "serviceManager.owner() != networkOwner"
        );

        require(
            registryCoordinator.owner() == networkOwner,
            "registryCoordinator.owner() != networkOwner"
        );
        require(
            registryCoordinator.churnApprover() == churner,
            "registryCoordinator.churner() != churner"
        );
        require(
            registryCoordinator.ejector() == ejector,
            "registryCoordinator.ejector() != ejector"
        );
        require(
            registryCoordinator.pauserRegistry() ==
            IPauserRegistry(pauserRegistry),
            "registryCoordinator: pauser registry not set correctly"
        );
        require(
            registryCoordinator.paused() == initialPausedStatus,
            "registryCoordinator: init paused status set incorrectly"
        );

        for (uint8 i = 0; i < operatorSetParams.length; ++i) {
            require(
                keccak256(
                    abi.encode(registryCoordinator.getOperatorSetParams(i))
                ) == keccak256(abi.encode(operatorSetParams[i])),
                "registryCoordinator.operatorSetParams != operatorSetParams"
            );
        }

        for (uint8 i = 0; i < minimumStakeForQuourm.length; ++i) {
            require(
                stakeRegistry.minimumStakeForQuorum(i) ==
                minimumStakeForQuourm[i],
                "stakeRegistry.minimumStakeForQuourm != minimumStakeForQuourm"
            );
        }

        for (uint8 i = 0; i < strategyAndWeightingMultipliers.length; ++i) {
            for (
                uint8 j = 0;
                j < strategyAndWeightingMultipliers[i].length;
                ++j
            ) {
                IStakeRegistry.StrategyParams
                memory strategyParams = stakeRegistry.strategyParamsByIndex(
                    i,
                    j
                );
                require(
                    address(strategyParams.strategy) ==
                    address(strategyAndWeightingMultipliers[i][j].strategy),
                    "stakeRegistry.strategyAndWeightingMultipliers != strategyAndWeightingMultipliers"
                );
                require(
                    strategyParams.multiplier ==
                    strategyAndWeightingMultipliers[i][j].multiplier,
                    "stakeRegistry.strategyAndWeightingMultipliers != strategyAndWeightingMultipliers"
                );
            }
        }

        require(
            operatorSetParams.length ==
            strategyAndWeightingMultipliers.length &&
            operatorSetParams.length == minimumStakeForQuourm.length,
            "operatorSetParams, strategyAndWeightingMultipliers, and minimumStakeForQuourm must be the same length"
        );
    }

    function _writeOutput(string memory config_data) internal {
        string memory parent_object = "parent object";

        string memory deployed_addresses = "addresses";
        vm.serializeAddress(
            deployed_addresses,
            "proxyAdmin",
            address(proxyAdmin)
        );
        vm.serializeAddress(
            deployed_addresses,
            "operatorStateRetriever",
            address(operatorStateRetriever)
        );
        vm.serializeAddress(
            deployed_addresses,
            "serviceManager",
            address(serviceManager)
        );
        vm.serializeAddress(
            deployed_addresses,
            "serviceManagerImplementation",
            address(serviceManagerImplementation)
        );
        vm.serializeAddress(
            deployed_addresses,
            "registryCoordinator",
            address(registryCoordinator)
        );
        vm.serializeAddress(
            deployed_addresses,
            "registryCoordinatorImplementation",
            address(registryCoordinatorImplementation)
        );
        vm.serializeAddress(
            deployed_addresses,
            "blsApkRegistry",
            address(blsApkRegistry)
        );
        vm.serializeAddress(
            deployed_addresses,
            "blsApkRegistryImplementation",
            address(blsApkRegistryImplementation)
        );
        vm.serializeAddress(
            deployed_addresses,
            "indexRegistry",
            address(indexRegistry)
        );
        vm.serializeAddress(
            deployed_addresses,
            "indexRegistryImplementation",
            address(indexRegistryImplementation)
        );
        vm.serializeAddress(
            deployed_addresses,
            "stakeRegistry",
            address(stakeRegistry)
        );
        string memory deployed_addresses_output = vm.serializeAddress(
            deployed_addresses,
            "stakeRegistryImplementation",
            address(stakeRegistryImplementation)
        );

        string memory chain_info = "chainInfo";
        vm.serializeUint(chain_info, "deploymentBlock", block.number);
        string memory chain_info_output = vm.serializeUint(
            chain_info,
            "chainId",
            block.chainid
        );

        address churner = stdJson.readAddress(
            config_data,
            ".permissions.churner"
        );
        address ejector = stdJson.readAddress(
            config_data,
            ".permissions.ejector"
        );
        string memory permissions = "permissions";
        vm.serializeAddress(permissions, "networkOwner", networkOwner);
        vm.serializeAddress(permissions, "networkUpgrader", networkUpgrader);
        vm.serializeAddress(permissions, "churner", churner);
        vm.serializeAddress(
            permissions,
            "pauserRegistry",
            address(pauserRegistry)
        );
        string memory permissions_output = vm.serializeAddress(
            permissions,
            "ejector",
            ejector
        );

        vm.serializeString(parent_object, chain_info, chain_info_output);
        vm.serializeString(
            parent_object,
            deployed_addresses,
            deployed_addresses_output
        );
        string memory finalJson = vm.serializeString(
            parent_object,
            permissions,
            permissions_output
        );
        vm.writeJson(finalJson, outputPath);
    }
}