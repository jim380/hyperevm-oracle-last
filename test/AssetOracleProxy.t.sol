// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AssetOracleProxy.sol";
import "../src/Aggregator.sol";

contract AssetOracleProxyTest is Test {
    AssetOracleProxy public proxy;
    Aggregator public aggregator;
    address public asset;
    string public constant DESCRIPTION = "ETH/USD";
    uint256 public constant DECIMALS = 8;

    function setUp() public {
        aggregator = new Aggregator();
        asset = makeAddr("asset");
        proxy = new AssetOracleProxy(address(aggregator), DESCRIPTION, DECIMALS, asset);
    }

    function testInitialState() public {
        assertEq(address(proxy.aggregator()), address(aggregator));
        assertEq(proxy.description(), DESCRIPTION);
        assertEq(proxy.decimals(), DECIMALS);
        assertEq(proxy.asset(), asset);
    }

    function testLatestAnswer() public {
        uint256 price = 1500e8;
        aggregator.setAsset(asset, false, 999, 8, price, false);
        assertEq(proxy.latestAnswer(), price);
    }

    function testLatestRoundData() public {
        uint256 price = 1500e8;
        aggregator.setAsset(asset, false, 999, 8, price, false);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            proxy.latestRoundData();

        assertEq(roundId, 0);
        assertEq(answer, int256(price));
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
    }

    function testRevertOnStalePrice() public {
        uint256 price = 1500e8;
        aggregator.setAsset(asset, false, 999, 8, price, false);

        // warp beyond stale threshold
        vm.warp(block.timestamp + 20 minutes + 1);

        vm.expectRevert("getPrice: stale EMA price");
        proxy.latestAnswer();
    }
}
