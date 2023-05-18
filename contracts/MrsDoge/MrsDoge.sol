// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";
import "./MrsDogeDividendTracker.sol";
import "./MrsDogePot.sol";
import "./MrsDogeRound.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogeTokenHolders.sol";
import "./MrsDogeToken.sol";
import "./MrsDogeGame.sol";
import "./MrsDogeStorage.sol";
import "./MrsDogeRoundFactory.sol";


contract MrsDoge is ERC20, Ownable {
    using SafeMath for uint256;
    //using IterableMapping for IterableMapping.Map;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;
    using MrsDogeGameSettings for MrsDogeGameSettings.PayoutSettings;
    using MrsDogeTokenHolders for MrsDogeTokenHolders.Holders;
    using MrsDogeToken for MrsDogeToken.Token;
    using MrsDogeGame for MrsDogeGame.Game;
    using MrsDogeStorage for MrsDogeStorage.Storage;
    using MrsDogeStorage for MrsDogeStorage.Fees;

    MrsDogeStorage.Storage private _storage;

    modifier onlyCurrentRound() {
        address currentRound = address(_storage.game.getCurrentRound());
        require(currentRound != address(0x0) && msg.sender == currentRound, "MRSDoge: caller must be current round");
        _;
    }

    modifier onlyTeamWallet() {
        require(msg.sender == _storage.teamWallet, "MRSDoge: caller must be the team wallet");
        _;
    }

    constructor() public ERC20("MrsDoge", "MrsDoge") {
        _storage.teamWallet = owner();

        _storage.roundFactory = new MrsDogeRoundFactory();
        _storage.dividendTracker = new MrsDogeDividendTracker();
    	  _storage.pot = new MrsDogePot();


    	  IUniswapV2Router02 _uniswapV2Router =      IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        _approve(address(this), address(_uniswapV2Router), type(uint256).max);


        _storage.token = MrsDogeToken.Token(
            address(this), //token address
            4, // liquidity fee
            4, // dividend fee low
            4, // pot fee low
            13, // dividend fee high
            13, // pot fee high
            86000 * 18, //fees lowering duration
            400000, //gas used for processing
            400000 * 10**18, // token swap threshold
            0, //accumulated liquidity tokens
            0, //accumulated dividend tokens
            0, //accumulated pot tokens
            false, //in swap
            _uniswapV2Pair, //pair
            _uniswapV2Router); //router

        _storage.game = MrsDogeGame.Game(
            new MrsDogeRound[](0),
            _storage.roundFactory,
            _storage.token);


        updateRoundSettings(
            false, //contractsDisabled
            0 * 10 ** 18, // tokensNeededToBuyTickets
            35, //userBonusDivisor
            65, // gameFeePotPercent,
            33, // gameFeeBuyTokensForPotPercent,
            2,  // gameFeeReferrerPercent
            20 * 60 * 12, // roundLengthBlocks,
            1000, // blocksAddedPer100TicketsBought,
            [uint256(0.001 ether), 0.00001 ether, 2000], //[initialTicketPrice, ticketPriceIncreasePerBlock, ticketPriceRoundPotDivisor]
            20 * 60 * 2); // gameCooldownBlocks)

        updatePayoutSettings(
            40,// roundPotPercent,
            25, // lastBuyerPayoutPercent,
            [uint256(20), 10, 5], // placePayoutPercents,
            [uint256(10), 10], // smallHolderSettings (lottery percent, lottery count)
            [uint256(10), 5], // largeHolderSettings
            [uint256(10), 2], // hugeHolderSettings
            10); // marketingPayoutPercent)


        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        _storage.dividendTracker.excludeFromDividends(address(_storage.dividendTracker));
        _storage.dividendTracker.excludeFromDividends(address(this));
        _storage.dividendTracker.excludeFromDividends(owner());
        _storage.dividendTracker.excludeFromDividends(_uniswapV2Pair);
        _storage.dividendTracker.excludeFromDividends(address(_uniswapV2Router));

        _mint(owner(), 500000000 * 10**18);
    }

    receive() external payable {

  	}

    function updateTeamWallet(address newTeamWallet) public onlyOwner {
       _storage.updateTeamWallet(newTeamWallet);
    }

    function updatePresaleWallet(address newPresaleWallet) public onlyOwner {
        _storage.updatePresaleWallet(newPresaleWallet);
        excludeFromFees(newPresaleWallet, true);
        _storage.dividendTracker.excludeFromDividends(newPresaleWallet);
    }

    function updateRoundFactory(address newRoundFactory) external onlyOwner {
        _storage.updateRoundFactory(newRoundFactory);
    }

    function lockRoundFactory() external onlyOwner {
        _storage.lockRoundFactory();
    }

    function getRoundFactory() external view returns (address) {
        return address(_storage.roundFactory);
    }

    function updateRoundSettings(
        bool contractsDisabled,
        uint256 tokensNeededToBuyTickets,
        uint256 userBonusDivisor,
        uint256 gameFeePotPercent,
        uint256 gameFeeBuyTokensForPotPercent,
        uint256 gameFeeReferrerPercent,
        uint256 roundLengthBlocks,
        uint256 blocksAddedPer100TicketsBought,
        uint256[3] memory ticketPriceInfo,
        uint256 gameCooldownBlocks)
        public onlyTeamWallet {
        _storage.roundSettings.updateRoundSettings(
            contractsDisabled,
            tokensNeededToBuyTickets,
            userBonusDivisor,
            gameFeePotPercent,
            gameFeeBuyTokensForPotPercent,
            gameFeeReferrerPercent,
            roundLengthBlocks,
            blocksAddedPer100TicketsBought,
            ticketPriceInfo,
            gameCooldownBlocks
        );
    }

    function updatePayoutSettings(
        uint256 roundPotPercent,
        uint256 lastBuyerPayoutPercent,
        uint256[3] memory placePayoutPercents,
        uint256[2] memory smallHolderSettings,
        uint256[2] memory laregHolderSettings,
        uint256[2] memory hugeHolderSettings,
        uint256 marketingPayoutPercent)
        public onlyTeamWallet {
        _storage.payoutSettings.updatePayoutSettings(
            roundPotPercent,
            lastBuyerPayoutPercent,
            placePayoutPercents,
            smallHolderSettings,
            laregHolderSettings,
            hugeHolderSettings,
            marketingPayoutPercent
        );
    }


    function extendCurrentRoundCooldown(uint256 blocks) public onlyTeamWallet {
        _storage.extendCurrentRoundCooldown(blocks);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _storage.token.excludeFromFees(account, excluded);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        _storage.token.updateGasForProcessing(newValue);
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        _storage.dividendTracker.updateClaimWait(claimWait);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _storage.isExcludedFromFees(account);
    }

    function processDividendTracker(uint256 gas) external {
        _storage.processDividendTracker(gas);
    }

    function claim() external {
        _storage.dividendTracker.processAccount(msg.sender, false);
    }

    function updateTokenHolderStatus(address user) private {
        if(!_storage.dividendTracker.excludedFromDividends(user) && user != address(_storage.pot)) {
            _storage.tokenHolders.updateTokenHolderStatus(user, balanceOf(user));
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0) && to != address(0), "ERC20: zero address transfer");


        MrsDogeRound currentRound = getCurrentRound();

        // complete the current round if it is over
        if(address(currentRound) != address(0x0)) {
            currentRound.completeRoundIfOver();
        } else { // don't allow adding liquidity before game starts
            if(to == _storage.token.uniswapV2Pair) {
                require(/*from == _storage.teamWallet ||*/ from == _storage.presaleWallet, "MRSDoge: cannot add liquidity before game starts");
            }
        }

        MrsDogeToken.TransferType transferType = _storage.token.getTransferType(from, to);

        // game starts when there is first buy from PancakeSwap
        if(transferType == MrsDogeToken.TransferType.Buy && !_storage.game.isActive()) {
            _storage.game.createNewRound();
        }

        _storage.possiblySwapContractTokens(from, to, transferType, owner(), balanceOf(address(this)));

        MrsDogeStorage.Fees memory fees = _storage.calculateTokenFee(from, to, amount, transferType);

        if(amount > 0 && _storage.token.feeBeginTimestamp[to] == 0) {
            _storage.token.feeBeginTimestamp[to] = block.timestamp;
        }

        uint256 totalFees = fees.calculateTotalFees();

        if(totalFees > 0) {
            amount = amount.sub(totalFees);

            super._transfer(from, address(this), totalFees);

            _storage.token.incrementAccumulatedTokens(fees);
        }

        super._transfer(from, to, amount);

        updateTokenHolderStatus(from);
        updateTokenHolderStatus(to);

        bool process = !_storage.token.inSwap && totalFees > 0;
        uint256 gasForProcessing = process ? _storage.token.gasForProcessing : 0;

        _storage.handleTransfer(from, to, gasForProcessing);
    }

    //Game

    function getCurrentRound() public view returns (MrsDogeRound) {
        return _storage.game.getCurrentRound();
    }


    function buyExactTickets(uint256 amount, address referrer) public payable {
        _storage.game.buyExactTickets(msg.sender, amount, referrer);
    }

    function completeRound() external {
        _storage.game.completeRound();
    }

    function lockTokenHolders(uint256 until) external onlyCurrentRound {
        _storage.tokenHolders.lockUntil(until);
    }

    function roundCompleted() external onlyCurrentRound {
        _storage.game.roundCompleted();
    }

    function getRandomHolders(uint256 seed, uint256 count, MrsDogeTokenHolders.HolderType holderType) external view returns (address[] memory) {
        return _storage.tokenHolders.getRandomHolders(seed, count, holderType);
    }

    function dividendTracker() external view returns (MrsDogeDividendTracker) {
        return _storage.dividendTracker;
    }

    function pot() external view returns (MrsDogePot) {
        return _storage.pot;
    }

    function teamWallet() external view returns (address) {
        return _storage.teamWallet;
    }

    function referredBy(address user) external view returns (address) {
        return _storage.game.referredBy(user);
    }

    function gameStats(address user)
        external
        view
        returns (uint256[] memory roundStats,
                 int256 currentBlocksLeft,
                 address lastBuyer,
                 uint256[] memory lastBuyerStats,
                 uint256[] memory userStats,
                 address[] memory topBuyerAddress,
                 uint256[] memory topBuyerData) {
        MrsDogeRound currentRound = getCurrentRound();
        if(address(currentRound) != address(0)) {
            return currentRound.gameStats(user);
        } else {
            roundStats = new uint256[](14);

            uint256 potBalance = address(_storage.pot).balance;

            roundStats[7] = potBalance.mul(_storage.payoutSettings.roundPotPercent).div(100);
            roundStats[11] = block.timestamp;
            roundStats[12] = block.number;
            roundStats[13] = potBalance;

            userStats = new uint256[](6);

            userStats[4] = balanceOf(user);
            userStats[5] = _storage.roundSettings.getUserBonusPermille(this, user);
        }
    }

    function settings()
        external
        view
        returns (MrsDogeGameSettings.RoundSettings memory contractRoundSettings,
                 MrsDogeGameSettings.PayoutSettings memory contractPayoutSettings,
                 MrsDogeGameSettings.RoundSettings memory currentRoundRoundSettings,
                 MrsDogeGameSettings.PayoutSettings memory currentRoundPayoutSettings,
                 address currentRoundAddress) {
        MrsDogeRound currentRound = getCurrentRound();

        contractRoundSettings = _storage.roundSettings;
        contractPayoutSettings = _storage.payoutSettings;

        if(address(currentRound) != address(0)) {
            currentRoundRoundSettings = currentRound.roundSettings();
            currentRoundPayoutSettings = currentRound.payoutSettings();
        }

        currentRoundAddress = address(currentRound);
    }
}
