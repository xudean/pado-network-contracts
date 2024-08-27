// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

// OpenZeppelin
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../../contracts/demo/WhiteListDataPermission.sol";

import "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";

// # To deploy and verify our contract
contract Holesky_Deploy_Demo is Script, Test {


    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    WhiteListDataPermission public whiteListDataPermission;
    WhiteListDataPermission public whiteListDataPermissionImplementation;

    function run()
    external
    returns (WhiteListDataPermission, ProxyAdmin)
    {
        console.log("deployer is:%s", msg.sender);

        vm.startBroadcast();
        _deployPadoNeworkContracts();

        vm.stopBroadcast();

        return (whiteListDataPermission, proxyAdmin);
    }

    /**
     * @notice Deploy  middleware contracts
     */
    function _deployPadoNeworkContracts() internal {

        emptyContract = EmptyContract(
            0x9690d52B1Ce155DB2ec5eCbF5a262ccCc7B3A6D2
        );
        proxyAdmin = new ProxyAdmin();
        whiteListDataPermission = WhiteListDataPermission(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(proxyAdmin),
                    ""
                )
            )
        );

        whiteListDataPermissionImplementation = new WhiteListDataPermission();
        console.log("deploy whiteListDataPermissionImplementation");
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(whiteListDataPermission))),
            address(whiteListDataPermissionImplementation),
            abi.encodeWithSelector(
                WhiteListDataPermission.initialize.selector,
                0x5DDAbE5dB4cE8eb0A4F5C61e40Ec5EBc46460E9F
            )
        );
        console.log("deploy whiteListDataPermission success");
        proxyAdmin.transferOwnership(0x5DDAbE5dB4cE8eb0A4F5C61e40Ec5EBc46460E9F);
        console.log("whiteListDataPermission is:%s", address(whiteListDataPermission));
    }
}
