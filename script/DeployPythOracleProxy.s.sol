// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PythOracleProxy.sol";

contract DeployPythOracleProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address pyth = vm.envAddress("PYTH_ADDRESS");
        string memory description = vm.envString("DESCRIPTION");
        address asset = vm.envAddress("ASSET_ADDRESS");
        bytes32 priceId = vm.envBytes32("PRICE_FEED_ID");

        vm.startBroadcast(deployerPrivateKey);

        new PythOracleProxy(pyth, description, asset, priceId);

        vm.stopBroadcast();
    }
}
