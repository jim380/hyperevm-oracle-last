// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PythOracleProxy.sol";

contract PythOracleProxyTest is Test {
    PythOracleProxy public proxy;
    address public constant PYTH =
        address(0x4374726Ee0B1b65C3A93c998E1F07db2C45b341C);
    address public asset;
    bytes32 public constant PRICE_ID = bytes32(uint256(1));
    string public constant DESCRIPTION = "ETH/USD";

    function setUp() public {
        asset = makeAddr("asset");
        proxy = new PythOracleProxy(PYTH, DESCRIPTION, asset, PRICE_ID);
    }

    function testInitialState() public view {
        assertEq(proxy.description(), DESCRIPTION);
        assertEq(proxy.asset(), asset);
    }
}
