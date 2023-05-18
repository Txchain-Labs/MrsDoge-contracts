// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./MrsDoge.sol";
import "./SafeMath.sol";
import "./MathUtils.sol";

library MrsDogeGameSettings {
    using SafeMath for uint256;

	struct RoundSettings {
        bool contractsDisabled; //Whether contracts are banned from buying tickets
        uint256 tokensNeededToBuyTickets; //Number of tokens a user needs to buy tickets
        uint256 userBonusDivisor; //Divisor in function to calculate user's bonus (tokens^(3/8) * userBonusDivisor / 100)
        uint256 gameFeePotPercent; //Percent of game fees going towards the pot
        uint256 gameFeeBuyTokensForPotPercent; //Percent of game fees going towards buying tokens for the pot
        uint256 gameFeeReferrerPercent; //Percent of gae fees going to the referrer of the buyer
        uint256 roundLengthBlocks; //The length of a round (not including added time), in blocks
        uint256 blocksAddedPer100TicketsBought; //How many blocks are added to length of round for every 100 tickets bought. Minimum is always 1 block.
        uint256 initialTicketPrice; //How much one ticket costs at the start of the round, in Wei
        uint256 ticketPriceIncreasePerBlock; //How much the price increases per block, in Wei
        uint256 ticketPriceRoundPotDivisor; //If set, the price of a ticket costs (Round Pot / ticketPriceRoundPotDivisor)
        uint256 gameCooldownBlocks; //Number of blocks after the round ends before the next round starts
    }

    struct PayoutSettings {
        uint256 roundPotPercent; //Percent of main pot that is paid out to the round pot
        uint256 lastBuyerPayoutPercent; //Percent of round pot that is paid to the last ticket buyer
        uint256[3] placePayoutPercents; //Percent of round pot that is paid to first place in tickets bought
        uint256 smallHolderLotteryPayoutPercent; //Percent of round that is paid to 'smallHolderLotteryPayoutCount' small holders
        uint256 largeHolderLotteryPayoutPercent; //Percent of round that is paid to 'largeHolderLotteryPayoutCount' large holders
        uint256 hugeHolderLotteryPayoutPercent; //Percent of round that is paid to 'hugeHolderLotteryPayoutCount' huge holders
        uint256 smallHolderLotteryPayoutCount; //Number of small holders randomly chosen to split 'smallHolderLotteryPayoutPercent'
        uint256 largeHolderLotteryPayoutCount; //Number of large holders randomly chosen to split 'largeHolderLotteryPayoutPercent'
        uint256 hugeHolderLotteryPayoutCount; //Number of huge holders randomly chosen to split 'hugeHolderLotteryPayoutPercent'
        uint256 marketingPayoutPercent; //Percent of round pot that is paid to the marketing wallet, for marketing
    }




    event RoundSettingsUpdated(
        bool contractsDisabled,
        uint256 tokensNeededToBuyTickets,
        uint256 userBonusDivisor,
        uint256 gameFeePotPercent,
        uint256 gameFeeBuyTokensForPotPercent,
        uint256 gameFeeReferrerPercent,
        uint256 roundLengthBlocks,
        uint256 blocksAddedPer100TicketsBought,
        uint256 initialTicketPrice,
        uint256 ticketPriceIncreasePerBlock,
        uint256 ticketPriceRoundPotDivisor,
        uint256 gameCooldownBlocks);

    event PayoutSettingsUpdated(
        uint256 roundPotPercent,
        uint256 lastBuyerPayoutPercent,
        uint256[3] placePayoutPercents,
        uint256[2] smallHolderSettings,
        uint256[2] laregHolderSettings,
        uint256[2] hugeHolderSettings,
        uint256 marketingPayoutPercent);

    // for any non-zero value it updates the game settings to that value
    function updateRoundSettings(
        RoundSettings storage roundSettings,
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
        external {
        roundSettings.contractsDisabled = contractsDisabled;
        roundSettings.tokensNeededToBuyTickets = tokensNeededToBuyTickets;
        roundSettings.userBonusDivisor = userBonusDivisor;
        roundSettings.gameFeePotPercent = gameFeePotPercent;
        roundSettings.gameFeeBuyTokensForPotPercent = gameFeeBuyTokensForPotPercent;
        roundSettings.gameFeeReferrerPercent = gameFeeReferrerPercent;
        roundSettings.roundLengthBlocks = roundLengthBlocks;
        roundSettings.blocksAddedPer100TicketsBought = blocksAddedPer100TicketsBought;
        roundSettings.initialTicketPrice = ticketPriceInfo[0];
        roundSettings.ticketPriceIncreasePerBlock = ticketPriceInfo[1];
        roundSettings.ticketPriceRoundPotDivisor = ticketPriceInfo[2];
        roundSettings.gameCooldownBlocks = gameCooldownBlocks;

        validateRoundSettings(roundSettings);

        emit RoundSettingsUpdated(
            contractsDisabled,
            tokensNeededToBuyTickets,
            userBonusDivisor,
            gameFeePotPercent,
            gameFeeBuyTokensForPotPercent,
            gameFeeReferrerPercent,
            roundLengthBlocks,
            blocksAddedPer100TicketsBought,
            ticketPriceInfo[0],
            ticketPriceInfo[1],
            ticketPriceInfo[2],
            gameCooldownBlocks);
    }

    function validateRoundSettings(RoundSettings storage roundSettings) private view {

        require(roundSettings.tokensNeededToBuyTickets <= 50000 * 10**18,
            "MRSDogeGameSettings: tokensNeededToBuyTickets must be <= 50000 tokens");

        require(roundSettings.userBonusDivisor >= 20 && roundSettings.userBonusDivisor <= 40,
            "MRSDogeGameSettings: userBonusDivisor must be between 20 and 40");

        require(roundSettings.gameFeeReferrerPercent <= 5,
            "MRSDogeGameSettings: gameFeeReferrerPercent must be <= 5");

        require(
            roundSettings.gameFeePotPercent
                .add(roundSettings.gameFeeBuyTokensForPotPercent)
                .add(roundSettings.gameFeeReferrerPercent) == 100,
            "MRSDogeGameSettings: pot percent, buy tokens percent, and referrer percent must sum to 100"
        );

        require(roundSettings.roundLengthBlocks >= 20 && roundSettings.roundLengthBlocks <= 28800,
            "MRSDogeGameSettings: round length blocks must be between 20 and 28800");
        require(roundSettings.blocksAddedPer100TicketsBought >= 1 && roundSettings.blocksAddedPer100TicketsBought <= 6000,
            "MRSDogeGameSettings: blocks added per 100 tickets bought must be between 1 and 6000");
        require(roundSettings.initialTicketPrice <= 10**18,
            "MRSDogeGameSettings: initial ticket price must not exceed 1 BNB");
        require(roundSettings.ticketPriceIncreasePerBlock <= 10**17,
            "MRSDogeGameSettings: ticket price increase per block must not exceed 0.1 BNB");

        require(roundSettings.ticketPriceRoundPotDivisor == 0 ||
            (roundSettings.ticketPriceRoundPotDivisor >= 10 && roundSettings.ticketPriceRoundPotDivisor <= 100000),
            "MRSDogeGameSettings: if set, ticket price round pot divisor must be between 10 and 10000");

        require(roundSettings.gameCooldownBlocks >= 20 && roundSettings.gameCooldownBlocks <= 28800,
            "MRSDogeGameSettings: cooldown must be between 20 and 28800 blocks");
    }

     // for any non-zero value it updates the game settings to that value
    function updatePayoutSettings(
        PayoutSettings storage payoutSettings,
        uint256 roundPotPercent,
        uint256 lastBuyerPayoutPercent,
        uint256[3] memory placePayoutPercents,
        uint256[2] memory smallHolderSettings,
        uint256[2] memory laregHolderSettings,
        uint256[2] memory hugeHolderSettings,
        uint256 marketingPayoutPercent)
        external {
        payoutSettings.roundPotPercent = roundPotPercent;
        payoutSettings.lastBuyerPayoutPercent = lastBuyerPayoutPercent;

        for(uint256 i = 0; i < 3; i++) {
            payoutSettings.placePayoutPercents[i] = placePayoutPercents[i];
        }

        payoutSettings.smallHolderLotteryPayoutPercent = smallHolderSettings[0];
        payoutSettings.largeHolderLotteryPayoutPercent = laregHolderSettings[0];
        payoutSettings.hugeHolderLotteryPayoutPercent = hugeHolderSettings[0];
        payoutSettings.smallHolderLotteryPayoutCount = smallHolderSettings[1];
        payoutSettings.largeHolderLotteryPayoutCount = laregHolderSettings[1];
        payoutSettings.hugeHolderLotteryPayoutCount = hugeHolderSettings[1];
        payoutSettings.marketingPayoutPercent = marketingPayoutPercent;

        validatePayoutSettings(payoutSettings);

        emit PayoutSettingsUpdated(
            roundPotPercent,
            lastBuyerPayoutPercent,
            placePayoutPercents,
            smallHolderSettings,
            laregHolderSettings,
            hugeHolderSettings,
            marketingPayoutPercent);
    }

    function validatePayoutSettings(PayoutSettings storage payoutSettings) private view {
        require(payoutSettings.roundPotPercent >= 1 && payoutSettings.roundPotPercent <= 50,
            "MRSDogeGameSettings: round pot percent must be between 1 and 50");
        require(payoutSettings.lastBuyerPayoutPercent <= 100,
            "MRSDogeGameSettings: last buyer percent must not exceed 100");
        require(payoutSettings.smallHolderLotteryPayoutPercent <= 50,
            "MRSDogeGameSettings: small holder lottery percent must not exceed 50");
        require(payoutSettings.largeHolderLotteryPayoutPercent <= 50,
            "MRSDogeGameSettings: large holder lottery percent must not exceed 50");
        require(payoutSettings.hugeHolderLotteryPayoutPercent <= 50,
            "MRSDogeGameSettings: huge holder lottery percent must not exceed 50");
        require(payoutSettings.marketingPayoutPercent <= 10,
            "MRSDogeGameSettings: marketing percent must not exceed 10");

        uint256 totalPayoutPercent = 0;

        for(uint256 i = 0; i < 3; i++) {
            totalPayoutPercent = totalPayoutPercent.add(payoutSettings.placePayoutPercents[i]);
        }

        totalPayoutPercent = totalPayoutPercent.
                                add(payoutSettings.lastBuyerPayoutPercent).
                                add(payoutSettings.smallHolderLotteryPayoutPercent).
                                add(payoutSettings.largeHolderLotteryPayoutPercent).
                                add(payoutSettings.hugeHolderLotteryPayoutPercent).
                                add(payoutSettings.marketingPayoutPercent);

        require(totalPayoutPercent == 100,
            "MRSDogeGameSettings: total payout percent must sum to 100");

        require(payoutSettings.smallHolderLotteryPayoutCount <= 20,
            "MRSDogeGameSettings: small holder lottery payout count must not exceed 20");
        require(payoutSettings.largeHolderLotteryPayoutCount <= 10,
            "MRSDogeGameSettings: large holder lottery payout count must not exceed 10");
        require(payoutSettings.hugeHolderLotteryPayoutCount <= 5,
            "MRSDogeGameSettings: huge holder lottery payout count must not exceed 5");
    }


    function calculatePriceForTickets(
        RoundSettings storage roundSettings,
        PayoutSettings storage payoutSettings,
        MrsDoge gameToken,
        uint256 startBlock,
        uint256 potBalance,
        address user,
        uint256 amount)
    public view returns (uint256) {
        if(amount == 0) {
            return 0;
        }

        uint256 price;

        if(roundSettings.ticketPriceRoundPotDivisor > 0) {
            uint256 roundPot = potBalance.mul(payoutSettings.roundPotPercent).div(100);

            uint256 roundPotAdjusted = MathUtils.sqrt(
                                            MathUtils.sqrt(roundPot ** 3).mul(10**9)
                                       );

            price = roundPotAdjusted.div(roundSettings.ticketPriceRoundPotDivisor);
        }
        else {
            price = roundSettings.initialTicketPrice;

            uint256 blocksElapsed = block.number.sub(startBlock);

            price = price.add(blocksElapsed.mul(roundSettings.ticketPriceIncreasePerBlock));
        }

        price = price.mul(amount);

        uint256 discount = calculateBonus(roundSettings, gameToken, user, price);

        price = price.sub(discount);

        return price;
    }

    function getUserBonusPermille(
        RoundSettings storage roundSettings,
        MrsDoge gameToken,
        address user)
    public view returns (uint256) {
        if(gameToken.isExcludedFromFees(user)) {
            return 0;
        }

        uint256 balanceWholeTokens = gameToken.balanceOf(user).div(10**18);

        uint256 value = balanceWholeTokens ** 3;
        value = MathUtils.eighthRoot(value);
        value = value.mul(roundSettings.userBonusDivisor).div(100);

        //max 33.3% bonus no matter what
        uint256 maxBonus = 333;

        if(value > maxBonus) {
            value = maxBonus;
        }

        return value;
    }

    function calculateBonus(
        RoundSettings storage roundSettings,
        MrsDoge gameToken,
        address user,
        uint256 amount)
    public view returns (uint256) {
        uint256 bonusPermille = getUserBonusPermille(roundSettings, gameToken, user);

        return amount.mul(bonusPermille).div(1000);
    }
}
