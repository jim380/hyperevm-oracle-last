// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISystemOracle.sol";

contract MockSystemOracle {
    uint256[] public prices;

    function setOraclePxs(uint256[] memory _prices) external {
        prices = _prices;
    }

    function getOraclePxs() external view returns (uint256[] memory) {
        return prices;
    }
}
