// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DataMgt} from "../../contracts/DataMgt.sol";
import {TaskMgt} from "../../contracts/TaskMgt.sol";
import {FeeMgt} from "../../contracts/FeeMgt.sol";
// import {WorkerMgtMock} from "./WorkerMgtMock.sol";
import {WorkerMgt} from "../../contracts/WorkerMgt.sol";
import {Router} from "../../contracts/Router.sol";

import {IDataMgt} from "../../contracts/interface/IDataMgt.sol";
import {ITaskMgt} from "../../contracts/interface/ITaskMgt.sol";
import {IFeeMgt} from "../../contracts/interface/IFeeMgt.sol";
import {IWorkerMgt} from "../../contracts/interface/IWorkerMgt.sol";
import {IRouter} from "../../contracts/interface/IRouter.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TestERC20} from "./TestERC20.sol";
import {EmptyContract} from "./EmptyContract.sol";
import "../../contracts/PADORegistryCoordinator.sol";
// import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {RegistryCoordinatorMock} from "./RegistryCoordinatorMock.sol";
import {TaskType} from "../../contracts/types/Common.sol";
import {G2Operations} from "./G2Operations.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

contract MockDeployer is G2Operations {
    using BN254 for *;
    ProxyAdmin proxyAdmin;
    EmptyContract emptyContract;
    IDataMgt dataMgt;
    IFeeMgt feeMgt;
    ITaskMgt taskMgt;
    IWorkerMgt workerMgt;
    IRouter router;
    address contractOwner;

    mapping(string tokenSymbol => TestERC20 erc20) erc20PerSymbol;
    string[] tokenSymbolList;

    function _addOneFeeToken(string memory tokenSymbol) private {
        TestERC20 testToken = new TestERC20();
        testToken.initialize(tokenSymbol, tokenSymbol, 18);
        
        vm.prank(contractOwner);
        feeMgt.addFeeToken(tokenSymbol, address(testToken), 1);
        erc20PerSymbol[tokenSymbol] = testToken;
        tokenSymbolList.push(tokenSymbol);
    }

    function _addFeeTokens() private {
        _addOneFeeToken("bETH");
        _addOneFeeToken("cETH");
        _addOneFeeToken("dETH");
    }

    function _addOneWorker(string memory name) private { 
        bytes memory onePublicKey = bytes("public keys");
        bytes[] memory publicKeys = new bytes[](1);
        publicKeys[0] = onePublicKey;

        TaskType[] memory taskTypes = new TaskType[](1);
        taskTypes[0] = TaskType.DATA_SHARING;

        address workerAddress = address(uint160(uint256(keccak256(bytes(name)))));
        vm.prank(address(contractOwner));
        workerMgt.addWhiteListItem(workerAddress);

        // workerMgt.register(name, "test", taskTypes, publicKeys, 0);

        bytes memory quorumNumbers = new bytes(1);
        string memory socket = "";
        IBLSApkRegistry.PubkeyRegistrationParams memory publicKeyParams;
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        uint privKey = uint(keccak256(abi.encodePacked(name)));
            
        publicKeyParams.pubkeyG1 = BN254.generatorG1().scalar_mul(privKey);
        publicKeyParams.pubkeyG2 = G2Operations.mul(privKey);
        vm.prank(workerAddress);
        workerMgt.registerEigenOperator(taskTypes, publicKeys, quorumNumbers, socket, publicKeyParams, signature);
    }

    function _addWorkers() private {
        _addOneWorker("worker 0");
        _addOneWorker("worker 1");
        _addOneWorker("worker 2");
        _addOneWorker("worker 3");
        _addOneWorker("worker 4");
    }

    function _deployAll() internal {
        proxyAdmin = new ProxyAdmin();
        emptyContract = new EmptyContract();
        contractOwner = msg.sender;

        Router routerImplementation = new Router();
        router = Router(
            address(
                new TransparentUpgradeableProxy(
                    address(routerImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        Router.initialize.selector,
                        address(0),
                        address(0),
                        address(0),
                        address(0),
                        contractOwner
                    ) 
                )
            )
        );

        // WorkerMgtMock workerMgtImplementation = new WorkerMgtMock();
        // workerMgt = WorkerMgtMock(
        //     address(
        //         new TransparentUpgradeableProxy(
        //             address(workerMgtImplementation),
        //             address(proxyAdmin),
        //             abi.encodeWithSelector(
        //                 WorkerMgtMock.initialize.selector
        //             )
        //         )
        //     )
        // );

        IRegistryCoordinator registryCoordinator = new RegistryCoordinatorMock();
        feeMgt = IFeeMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        DataMgt dataMgtImplementation = new DataMgt();
        dataMgt = IDataMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(dataMgtImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        DataMgt.initialize.selector,
                        router,
                        contractOwner
                    )
                )
            )
        );

        WorkerMgt workerMgtImplementation = new WorkerMgt();
        workerMgt = WorkerMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(workerMgtImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        WorkerMgt.initialize.selector,
                        registryCoordinator,
                        address(dataMgt),
                        address(contractOwner)
                    )
                )
            )
        );

        TaskMgt taskMgtImplementation = new TaskMgt();
        taskMgt = ITaskMgt(
            address(
                new TransparentUpgradeableProxy(
                    address(taskMgtImplementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        TaskMgt.initialize.selector,
                        router,
                        contractOwner
                    )
                )
            )
        );

        IFeeMgt feeMgtImplementation = new FeeMgt();
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(feeMgt))),
            address(feeMgtImplementation),
            abi.encodeWithSelector(
                FeeMgt.initialize.selector,
                router,
                1,
                contractOwner
            )
        );

        vm.startPrank(contractOwner);
        router.setDataMgt(dataMgt);
        router.setTaskMgt(taskMgt);
        router.setFeeMgt(feeMgt);
        router.setWorkerMgt(workerMgt);
        vm.stopPrank();

        _addFeeTokens();
        _addWorkers();
    }
}
