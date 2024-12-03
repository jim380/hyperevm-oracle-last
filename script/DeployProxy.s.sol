// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/AssetOracleProxy.sol";

contract DeployProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address aggregator = vm.envAddress("AGGREGATOR");
        address asset = vm.envAddress("ASSET");

        string memory description = vm.envString("DESCRIPTION");
        uint256 decimals = vm.envUint("DECIMALS");

        vm.startBroadcast(deployerPrivateKey);

        new AssetOracleProxy(aggregator, description, decimals, asset);

        vm.stopBroadcast();
    }
}
