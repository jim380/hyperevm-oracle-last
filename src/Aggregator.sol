// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "./utils/Ownable.sol";
import { FixedPointMathLib } from "./utils/FixedPointMathLib.sol";
import { ISystemOracle } from "./interfaces/ISystemOracle.sol";

///@title Aggregator
///@author fbsloXBT
///@notice A price oracle aggregator for HyperEVM. 
///@dev There are 2 types of assets:
/// - perp-oracle assets where HL SystemOracle has the oracle price (submitted by L1 validators).
/// - assets, where price is provided by an off-chain keepers (and then exponential moving average is used)
contract Aggregator is Ownable {
    ///@notice Hyperliquid L1 system oracle
    ISystemOracle public systemOracle = ISystemOracle(0x1111111111111111111111111111111111111111);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice maximum allowed age of the price data submitted by keepers
    uint256 public MAX_TIMESTAMP_DELAY_SECONDS = 1 minutes;
    ///@notice maxumum allowed time between rounds, then getPrice() reverts
    uint256 public MAX_EMA_STALE_SECONDS = 20 minutes;
    ///@notice exponential moving average window in seconds
    int256 public EMA_WINDOW_SECONDS = 866; //600 / ln(2)

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MAPPINGS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice information about certain asset
    ///@dev first variables are packed in one slot
    struct AssetDetails {
        bool exists;
        bool isPerpOracle;
        uint32 metaIndex;
        uint32 metaDecimals;
        uint256 ema;
        uint256 lastTimestamp;
    }

    ///@notice mapping of Hyperliquid system oracle indexes to asset address
    mapping(uint256 => address) public metaIndexes;
    ///@notice mapping of asset addresses to details
    mapping(address => AssetDetails) public assetDetails;
    ///@notice mapping of whitelisted keepers who can submit prices
    mapping(address => bool) public keepers;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          EVENTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice event emmited when an asset is added or updated
    event AssetChanged(address indexed _asset, bool _isPerpOracle, uint32 indexed _metaIndex, uint32 _metaDecimals, uint256 _price, bool _isUpdate);
    ///@notice event emmited when new data is submited for non-perp oracle assets
    event RoundDataSubmitted(address[] _assets, uint256[] _prices, uint256 _timestamp);
    ///@notice event emmited when a keeper is added or removed
    event KeeperUpdated(address _keeper, bool _newState);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODIFIERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice modifier allowing only whitelisted keepers to call functions
    modifier onlyKeeper(){
      require(keepers[msg.sender] || msg.sender == owner(), "only keepers");
      _;
    }

    constructor() Ownable(msg.sender) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       READ-ONLY                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice function used to read the latest price data
    ///@param _asset address of the asset
    function getPrice(address _asset) external view returns (uint256){
        require(assetDetails[_asset].exists == true, "getPrice: asset not found");

        AssetDetails memory _assetInfo = assetDetails[_asset];

        if (_assetInfo.isPerpOracle){
            return _getPerpOraclePrice(_asset);
        } else {
            require(block.timestamp - _assetInfo.lastTimestamp < MAX_EMA_STALE_SECONDS, "getPrice: stale EMA price");
            return _assetInfo.ema;
        }
    }

    /// @notice function used to read the timestamp of the last price update for a certain asset
    /// @dev for perp assets, it returns block.timestamp
    function getUpdateTimestamp(address _asset) external view returns (uint256){
        require(assetDetails[_asset].exists == true, "getUpdateTimestamp: asset not found");

        AssetDetails memory _assetInfo = assetDetails[_asset];

        if (_assetInfo.isPerpOracle){
            return block.timestamp;
        } else {
            return _assetInfo.lastTimestamp;
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       AUTH-ONLY                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice function used to add or update supported assets
    ///@param _asset address of the asset
    ///@param _isPerpOracle indicates if HL perp oracle price is available
    ///@param _metaIndex index of the asset price in SystemOracle data (only for perp-oracle assets)
    ///@param _metaDecimals number of decimals of price in SystemOracle data (only for perp-oracle assets: price = x / Math.pow(10, 6 - decimals))
    ///@param _isUpdate indicates if asset is being added or updated
    function setAsset(address _asset, bool _isPerpOracle, uint32 _metaIndex, uint32 _metaDecimals, uint256 _price, bool _isUpdate) external onlyOwner() {
        if (!_isUpdate) {
            require(assetDetails[_asset].exists == false, "setAsset: asset already exists");
            require(metaIndexes[_metaIndex] == address(0), "setAsset: metaIndex already exists");
        }

        assetDetails[_asset] = AssetDetails({
            exists: true,
            isPerpOracle: _isPerpOracle,
            metaIndex: _metaIndex,
            metaDecimals: _metaDecimals,
            ema: _price,
            lastTimestamp: block.timestamp
        });
        //if asset is not a perp, we can use any (unused) random high number for metaIndex
        metaIndexes[_metaIndex] = _asset;

        emit AssetChanged(_asset, _isPerpOracle, _metaIndex, _metaDecimals, _price, _isUpdate);
    }

    ///@notice function used to add or oremove keepers
    ///@param _keeper address of the keeper
    function toggleKeeper(address _keeper) external onlyOwner() {
        keepers[_keeper] = !keepers[_keeper];
        emit KeeperUpdated(_keeper, keepers[_keeper]);
    }

    ///@notice function used to submit a batch of prices
    ///@param _assets array of addresses for assets
    ///@param _prices array of prices for assets (must be in the same order as _assets)
    ///@param _submitTimestamp unix timestamp (in seconds) when transaction was sent by the keeper
    ///@dev prices must be scaled to 8 decimals before they are submitted
    function submitRoundData(address[] calldata _assets, uint256[] calldata _prices, uint256 _submitTimestamp) external onlyKeeper() {
        require(block.timestamp - _submitTimestamp < MAX_TIMESTAMP_DELAY_SECONDS, "submitRoundData: expired");
        require(_assets.length == _prices.length, "submitRoundData: length mismatch");

        for (uint256 i = 0; i < _assets.length; i++){
            //even if the asset is not added yet, we can write the price, since reading it will revert
            _calculateEma(_assets[i], _prices[i]);
        }

        emit RoundDataSubmitted(_assets, _prices, block.timestamp);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL HELPERS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///@notice helper function used to calculate new EMA when price is added
    ///@dev we are using calculation for unevenly spaced time series
    function _calculateEma(address _asset, uint256 _price) internal {
        AssetDetails memory assetInfo = assetDetails[_asset];

        uint256 lastTimestamp = assetInfo.lastTimestamp;
        uint256 currentEma = assetInfo.ema;

        //Andreas Eckner (2010): Algorithms for Unevenly Spaced Time Series: Moving Averages and Other Rolling Operators
        int256 x = -int256(int256(block.timestamp - lastTimestamp) * 10**18 / EMA_WINDOW_SECONDS);
        int256 alpha = FixedPointMathLib.expWad(x);
        uint256 newEma = uint256((int256(currentEma) * alpha + int256(_price) * (10**18 - alpha)) / 10**18);
        
        assetDetails[_asset].lastTimestamp = block.timestamp;
        assetDetails[_asset].ema = newEma;
    }

    ///@notice helper function used to fetch perp-oracle price from SystemOracle
    function _getPerpOraclePrice(address _asset) internal view returns (uint256) {
        AssetDetails memory assetInfo = assetDetails[_asset];

        uint256[] memory oraclePrices = systemOracle.getOraclePxs();
        uint256 _metaIndex = assetInfo.metaIndex;

        uint256 _price = oraclePrices[_metaIndex];
        uint256 _decimals = assetInfo.metaDecimals;

        //scale to 8 decimals and remove decimals from systemOracle
        //https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/evm/system-contract
        return _price * (10**8) / (10**(6 - _decimals));
    }
}