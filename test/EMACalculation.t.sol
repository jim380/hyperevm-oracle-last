// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";

contract EMACalculationTest is Test {
    Aggregator public aggregator;
    address public keeper;
    address public asset;

    function setUp() public {
        aggregator = new Aggregator();
        keeper = makeAddr("keeper");
        asset = makeAddr("asset");

        aggregator.toggleKeeper(keeper);
        aggregator.setAsset(asset, false, 999, 8, 1000e8, false);
    }

    function testFirstEMACalculation() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory prices = new uint256[](1);
        prices[0] = 1500e8;

        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        (, , , , uint256 ema, ) = aggregator.assetDetails(asset);
        assertEq(ema, 1000e8);
    }

    function testEMAWithTimeIntervals() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory prices = new uint256[](1);

        prices[0] = 1500e8;
        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        vm.warp(block.timestamp + 5 minutes);
        prices[0] = 2000e8;
        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        (, , , , uint256 ema, ) = aggregator.assetDetails(asset);
        assertTrue(ema >= 1000e8 && ema <= 2000e8);
    }

    function testBatchProcessing() public {
        address asset2 = makeAddr("asset2");
        aggregator.setAsset(asset2, false, 998, 8, 2000e8, false);

        address[] memory assets = new address[](2);
        assets[0] = asset;
        assets[1] = asset2;
        uint256[] memory prices = new uint256[](2);
        prices[0] = 1500e8;
        prices[1] = 2500e8;

        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        (, , , , uint256 ema1, ) = aggregator.assetDetails(asset);
        (, , , , uint256 ema2, ) = aggregator.assetDetails(asset2);

        assertEq(ema1, 1000e8);
        assertEq(ema2, 2000e8);
    }
}
