// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockSystemOracle {
    uint256 public sysBlockNumber;
    uint256[] public markPxs;
    uint256[] public oraclePxs;
    uint256[] public spotPxs;

    // Function to set the list of numbers, only the owner can call this
    function setValues(
        uint256 _sysBlockNumber,
        uint256[] memory _markPxs,
        uint256[] memory _oraclePxs,
        uint256[] memory _spotPxs
    ) public {
        sysBlockNumber = _sysBlockNumber;
        markPxs = _markPxs;
        oraclePxs = _oraclePxs;
        spotPxs = _spotPxs;
    }

    function getMarkPxs() external view returns (uint256[] memory) {
        return markPxs;
    }

    function getOraclePxs() external view returns (uint256[] memory) {
        return oraclePxs;
    }

    function getSpotPxs() external view returns (uint256[] memory) {
        return spotPxs;
    }
}
