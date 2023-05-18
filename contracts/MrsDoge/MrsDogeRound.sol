// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./DividendPayingToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./MrsDoge.sol";
import "./MrsDogeRoundStorage.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogeRoundBuyers.sol";
import "./MrsDogeToken.sol";
import "./MrsDogeRoundFactory.sol";
import "./IReceivesBogRandV2.sol";
import "./IBogRandOracleV2.sol";
import "./IUniswapV2Router.sol";


contract MrsDogeRound is Ownable, IReceivesBogRandV2 {
    using SafeMath for uint256;
    using MrsDogeRoundBuyers for MrsDogeRoundBuyers.Buyers;
    using MrsDogeToken for MrsDogeToken.Token;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;
    using MrsDogeGameSettings for MrsDogeGameSettings.PayoutSettings;
    using MrsDogeRoundStorage for MrsDogeRoundStorage.Storage;

    MrsDogeRoundStorage.Storage private _storage;

    modifier onlyTokenContract() {
        require(_msgSender() == address(_storage.gameToken), "MRSDogeRound: caller is not MrsDoge");
        _;
    }

    modifier onlyPot() {
        require(_msgSender() == address(_storage.gameToken.pot()), "MRSDogeRound: caller is not MrsDoge");
        _;
    }

    modifier onlyRNG() {
        require(_msgSender() == address(_storage.rng), "MRSDogeRound: caller is not RNG");
        _;
    }

    constructor(IUniswapV2Router02 _uniswapV2Router, uint256 _roundNumber) public {
        _storage.uniswapV2Router = _uniswapV2Router;
        _storage.roundNumber = _roundNumber;

        //IBogRandOracleV2(0x0eCb31Afe9FE6a10f9A173843aE7957Df39D8236); testnet
        _storage.rng = IBogRandOracleV2(0xe308d2B81e543b21c8E1D0dF200965a7349eb1b7);
    }

    function makeTokenOwner(address tokenAddress) public onlyOwner {
        _storage.gameToken = MrsDoge(payable(tokenAddress));
        transferOwnership(tokenAddress);
    }

    function start() public onlyTokenContract {
        require(_storage.startBlock == 0);
        _storage.start();
    }


    function receiveRoundPot() external payable onlyPot {
        _storage.receiveRoundPot();
    }

    function receiveBonus() external payable onlyPot {

    }

    function receiveGasFees() external payable onlyPot {

    }


    //if the round is over, return the block that the cooldown is over
    function cooldownOverBlock() public view returns (uint256) {
        return _storage.cooldownOverBlock();
    }

    function priceForTickets(address user, uint256 amount) public view returns (uint256) {
        return _storage.calculatePriceForTickets(user, amount);
    }

    function roundPotPercent() public view returns (uint256) {
        return _storage.payoutSettings.roundPotPercent;
    }

    function extendCooldown(uint256 blocks) public onlyTokenContract {
        _storage.extendCooldown(blocks);
    }

    function returnFundsToPot() public onlyTokenContract {
        _storage.returnFundsToPot();
    }

    function buyExactTickets(address user, uint256 amount) external payable onlyTokenContract returns (bool) {
    	bool result = _storage.buyExactTickets(user, amount);
        return result;
    }

    function completeRoundIfOver() public onlyTokenContract returns (bool) {
       return _storage.completeRoundIfOver();
    }

    function receiveRandomness(bytes32 hash, uint256 random) external override onlyRNG {
        _storage.receiveRandomness(hash, random);
    }

    function roundNumber() external view returns (uint256) {
        return _storage.roundNumber;
    }

    function startTimestamp() external view returns (uint256) {
        return _storage.startTimestamp;
    }

    function blocksLeft() external view returns (int256) {
        return _storage.blocksLeft();
    }

    function topBuyer() public view returns (address, uint256) {
        MrsDogeRoundBuyers.Buyer storage buyer = _storage.buyers.topBuyer();
        return (buyer.user, buyer.ticketsBought);
    }


    function getNumberOfTicketsBought(address user) external view returns (uint256) {
        return _storage.getNumberOfTicketsBought(user);
    }

	function gameStats(
                address user)
        external
        view
        returns (uint256[] memory roundStats,
                 int256 blocksLeftAtCurrentBlock,
                 address lastBuyer,
                 uint256[] memory lastBuyerStats,
                 uint256[] memory userStats,
                 address[] memory topBuyerAddress,
                 uint256[] memory topBuyerData) {
        return _storage.generateGameStats(user);
    }

    function roundSettings()
        external
        view
        returns (MrsDogeGameSettings.RoundSettings memory) {
            return _storage.roundSettings;
    }

    function payoutSettings()
        external
        view
        returns (MrsDogeGameSettings.PayoutSettings memory) {
            return _storage.payoutSettings;
    }
}
