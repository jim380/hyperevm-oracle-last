// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Aggregator.sol";
import "../src/mocks/MockSystemOracle.sol";

contract AggregatorTest is Test {
    event AssetChanged(
        address indexed _asset,
        bool _isPerpOracle,
        uint32 indexed _metaIndex,
        uint32 _metaDecimals,
        uint256 _price,
        bool _isUpdate
    );
    event KeeperUpdated(address _keeper, bool _newState);
    event RoundDataSubmitted(address[] _assets, uint256[] _prices, uint256 _timestamp);

    Aggregator public aggregator;
    MockSystemOracle public mockOracle;
    address public owner;
    address public keeper;

    function setUp() public {
        owner = address(this);
        keeper = makeAddr("keeper");
        mockOracle = new MockSystemOracle();
        aggregator = new Aggregator();
    }

    function testConstructor() public {
        assertEq(aggregator.owner(), owner);
        assertEq(address(aggregator.systemOracle()), address(0x1111111111111111111111111111111111111111));
    }

    // setAsset Tests
    function testOnlyOwnerCanAddAsset() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        aggregator.setAsset(makeAddr("asset"), true, 1, 8, 1000e8, false);
    }

    function testSetPerpOracleAsset() public {
        address asset = makeAddr("asset");
        uint32 metaIndex = 1;
        uint32 metaDecimals = 8;
        uint256 price = 1000e8;

        vm.expectEmit(true, true, true, true);
        emit AssetChanged(asset, true, metaIndex, metaDecimals, price, false);

        aggregator.setAsset(asset, true, metaIndex, metaDecimals, price, false);

        (bool exists, bool isPerpOracle, uint32 storedMetaIndex, uint32 storedDecimals, uint256 ema,) =
            aggregator.assetDetails(asset);

        assertTrue(exists);
        assertTrue(isPerpOracle);
        assertEq(storedMetaIndex, metaIndex);
        assertEq(storedDecimals, metaDecimals);
        assertEq(ema, price);
    }

    function testCannotAddDuplicateAsset() public {
        address asset = makeAddr("asset");
        aggregator.setAsset(asset, true, 1, 8, 1000e8, false);

        vm.expectRevert("setAsset: asset already exists");
        aggregator.setAsset(asset, true, 1, 8, 1000e8, false);
    }

    // keeper Tests
    function testToggleKeeper() public {
        assertFalse(aggregator.keepers(keeper));

        vm.expectEmit(true, true, true, true);
        emit KeeperUpdated(keeper, true);
        aggregator.toggleKeeper(keeper);

        assertTrue(aggregator.keepers(keeper));
    }

    // submit Data Tests
    function testSubmitRoundData() public {
        address asset = makeAddr("asset");
        aggregator.setAsset(asset, false, 999, 8, 1000e8, false);
        aggregator.toggleKeeper(keeper);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory prices = new uint256[](1);
        prices[0] = 1500e8;

        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        (,,,, uint256 ema,) = aggregator.assetDetails(asset);
        assertEq(ema, 1000e8);
    }

    function testRevertStaleSubmission() public {
        aggregator.toggleKeeper(keeper);

        address[] memory assets = new address[](1);
        uint256[] memory prices = new uint256[](1);

        // warp to future time
        vm.warp(block.timestamp + 2 minutes);

        vm.prank(keeper);
        vm.expectRevert("submitRoundData: expired");
        aggregator.submitRoundData(assets, prices, block.timestamp - 2 minutes);
    }

    // price Reading Tests
    function testGetPriceNonExistentAsset() public {
        vm.expectRevert("getPrice: asset not found");
        aggregator.getPrice(makeAddr("nonexistent"));
    }

    function testGetPriceStaleEMA() public {
        address asset = makeAddr("asset");
        aggregator.setAsset(asset, false, 999, 8, 1000e8, false);

        // warp beyond stale threshold
        vm.warp(block.timestamp + aggregator.MAX_EMA_STALE_SECONDS() + 1);

        vm.expectRevert("getPrice: stale EMA price");
        aggregator.getPrice(asset);
    }

    // edge Cases
    function testZeroPrice() public {
        address asset = makeAddr("asset");
        aggregator.setAsset(asset, false, 999, 8, 0, false);
        aggregator.toggleKeeper(keeper);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory prices = new uint256[](1);
        prices[0] = 0;

        vm.prank(keeper);
        aggregator.submitRoundData(assets, prices, block.timestamp);

        assertEq(aggregator.getPrice(asset), 0);
    }

    function testMaxPrice() public {
        address asset = makeAddr("asset");
        uint256 maxPrice = 10_000_000_000 * 1e8;
        aggregator.setAsset(asset, false, 999, 8, maxPrice, false);

        assertEq(aggregator.getPrice(asset), maxPrice);
    }
}
