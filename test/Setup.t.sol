// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";
import "../src/AssetOracleProxy.sol";
import "../src/PythOracleProxy.sol";

contract SetupTest is Test {
    Aggregator public aggregator;
    AssetOracleProxy public assetProxy;
    PythOracleProxy public pythProxy;
    address public owner;
    address public constant PYTH = address(0x4374726Ee0B1b65C3A93c998E1F07db2C45b341C);

    function setUp() public {
        owner = address(this);
        aggregator = new Aggregator();
    }

    function testAggregatorSetup() public view {
        assertEq(aggregator.owner(), owner);
        assertEq(address(aggregator.systemOracle()), address(0x1111111111111111111111111111111111111111));
        assertEq(aggregator.MAX_TIMESTAMP_DELAY_SECONDS(), 1 minutes);
        assertEq(aggregator.MAX_EMA_STALE_SECONDS(), 20 minutes);
        assertEq(aggregator.EMA_WINDOW_SECONDS(), 866);
    }

    function testAssetProxySetup() public {
        address asset = makeAddr("asset");
        string memory description = "ETH/USD";
        uint256 decimals = 8;

        assetProxy = new AssetOracleProxy(address(aggregator), description, decimals, asset);

        assertEq(address(assetProxy.aggregator()), address(aggregator));
        assertEq(assetProxy.description(), description);
        assertEq(assetProxy.decimals(), decimals);
        assertEq(assetProxy.asset(), asset);
        assertEq(assetProxy.owner(), owner);
    }

    function testPythProxySetup() public {
        address asset = makeAddr("asset");
        string memory description = "ETH/USD";
        bytes32 priceId = bytes32(uint256(1));

        pythProxy = new PythOracleProxy(PYTH, description, asset, priceId);

        assertEq(pythProxy.description(), description);
        assertEq(pythProxy.asset(), asset);
    }

    function testInitialState() public {
        // check initial mappings are empty
        address randomAsset = makeAddr("random");
        (bool exists,,,, uint256 ema,) = aggregator.assetDetails(randomAsset);
        assertFalse(exists);
        assertEq(ema, 0);

        // check initial keeper state
        address randomKeeper = makeAddr("keeper");
        assertFalse(aggregator.keepers(randomKeeper));
    }
}
