// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./MrsDoge.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogeRoundBuyers.sol";
import "./MrsDogeTokenHolders.sol";
import "./MrsDogeLatestBuyerPot.sol";
import "./MrsDogeRoundStorageStats.sol";
import "./IUniswapV2Router.sol";
import "./SafeMath.sol";
import "./IBogRandOracleV2.sol";


library MrsDogeRoundStorage {
    using SafeMath for uint256;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;
    using MrsDogeGameSettings for MrsDogeGameSettings.PayoutSettings;
    using MrsDogeRoundBuyers for MrsDogeRoundBuyers.Buyers;

    event Payout(
        address indexed user,
        PayoutType indexed payoutType,
        uint256 indexed place,
        uint256 amount
    );

    event ReferralPayout(
        address indexed referrer,
        address indexed referred,
        uint256 amount
    );

    enum PayoutType {
        LastBuyer,
        TopBuyer,
        SmallHolderLottery,
        LargeHolderLottery,
        HugeHolderLottery,
        Marketing
    }


    struct Storage {
    	uint256 roundNumber;

	    uint256 startBlock;
	    uint256 startTimestamp;

	    uint256 blocksLeftAtLastBuy;
	    uint256 lastBuyBlock;

        uint256 totalSpentOnTickets;
	    uint256 ticketsBought;

        uint256 tokensBurned;

	    uint256 endBlock;
	    uint256 endTimestamp;

	    uint256 mustReceiveRandomnessByBlock;

	    uint256 roundPot;

        MrsDogeRoundBuyers.Buyers buyers;
        IUniswapV2Router02 uniswapV2Router;

        MrsDoge gameToken;
        IBogRandOracleV2 rng;

        MrsDogeGameSettings.RoundSettings roundSettings;
        MrsDogeGameSettings.PayoutSettings payoutSettings;

        bool cooldownHasBeenExtended;

    }

    function start(
        Storage storage _storage
    ) public {

        (MrsDogeGameSettings.RoundSettings memory contractRoundSettings,
        MrsDogeGameSettings.PayoutSettings memory contractPayoutSettings,,,) = _storage.gameToken.settings();

        _storage.roundSettings = contractRoundSettings;
        _storage.payoutSettings = contractPayoutSettings;

        _storage.startBlock = block.number;
        _storage.startTimestamp = block.timestamp;

        _storage.blocksLeftAtLastBuy = _storage.roundSettings.roundLengthBlocks;
        _storage.lastBuyBlock = _storage.startBlock;
    }

    function receiveRoundPot(Storage storage _storage) public {
        require(_storage.endTimestamp > 0, "MRSDogeRound: round is not over");
        require(_storage.roundPot == 0, "MRSDogeRound: round pot already received");

        _storage.roundPot = msg.value;
    }

    function cooldownOverBlock(Storage storage _storage) public view returns(uint256) {
        if(_storage.endBlock == 0) {
            return 0;
        }

        return _storage.endBlock.add(_storage.roundSettings.gameCooldownBlocks);
    }

    function extendCooldown(Storage storage _storage, uint256 blocks) public {
        require(!_storage.cooldownHasBeenExtended, "MRSDogeRound: round cooldown has already been extended");
        _storage.cooldownHasBeenExtended = true;
        _storage.roundSettings.gameCooldownBlocks = _storage.roundSettings.gameCooldownBlocks.add(blocks);
    }

    function returnFundsToPot(Storage storage _storage) public {
        if(address(this).balance > 0) {
            sendToPot(_storage, address(this).balance);
        }
    }

    function blocksLeft(Storage storage _storage) public view returns (int256) {
        if(_storage.endTimestamp > 0) {
            return 0;
        }

        uint256 blocksSinceLastBuy = block.number.sub(_storage.lastBuyBlock);

        return int256(_storage.blocksLeftAtLastBuy) - int256(blocksSinceLastBuy);
    }

    function calculatePriceForTickets(Storage storage _storage, address user, uint256 amount) public view returns (uint256) {
        if(_storage.endTimestamp > 0) {
            return 0;
        }

        return _storage.roundSettings.calculatePriceForTickets(
            _storage.payoutSettings,
            _storage.gameToken,
            _storage.startBlock,
            potBalance(_storage),
            user,
            amount);
    }

    function isContract(address _address) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }

    function uintToString(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }


    function buyExactTickets(Storage storage _storage, address user, uint256 amount) public returns (bool) {
        require(_storage.endTimestamp == 0, "MRSDogeRound: round is over");
        require(amount > 0, "MRSDogeRound: cannot buy zero tickets");
        require(_storage.gameToken.balanceOf(user) >= _storage.roundSettings.tokensNeededToBuyTickets, "MRSDogeRound: insufficient tokens");
        if(_storage.roundSettings.contractsDisabled) {
            require(!isContract(user), "MRSDogeRound: contract cannot buy");
        }

        int256 oldBlocksLeft = blocksLeft(_storage);

        if(oldBlocksLeft < 0) {
            completeRoundIfOver(_storage);

            (bool success,) = user.call {value: msg.value, gas: 5000} ("");
            require(success, "MRSDogeRound: could not return ticket buy money");

            return false;
        }

        uint256 price = calculatePriceForTickets(_storage, user, amount);

        require(msg.value >= price, string(abi.encodePacked("MRSDogeRound: msg.value too low: ", uintToString(msg.value), " ", uintToString(price))));

        uint256 blocksAdded = _storage.roundSettings.blocksAddedPer100TicketsBought.mul(amount).div(100);

        if(blocksAdded == 0) {
            blocksAdded = 1;
        }

        uint256 newBlocksLeft = uint256(oldBlocksLeft + int256(blocksAdded));

        _storage.blocksLeftAtLastBuy = newBlocksLeft;
        _storage.lastBuyBlock = block.number;
        _storage.ticketsBought = _storage.ticketsBought.add(amount);
        _storage.totalSpentOnTickets = _storage.totalSpentOnTickets.add(price);


        if(_storage.blocksLeftAtLastBuy > _storage.roundSettings.roundLengthBlocks) {
            _storage.blocksLeftAtLastBuy = _storage.roundSettings.roundLengthBlocks;
        }

        uint256 returnAmount = msg.value.sub(price);

        (bool success,) = user.call {value: returnAmount } ("");

        require(success, "MRSDogeRound: could not return excess");

        _storage.buyers.handleBuy(user, amount, price);


        MrsDogeLatestBuyerPot latestBuyersPot = _storage.gameToken.pot().latestBuyerPot();


        //if(address(latestBuyersPot) != address(0)) {

            uint256 payoutBonusPermille = _storage.roundSettings.getUserBonusPermille(
                                             _storage.gameToken,
                                             latestBuyersPot.latestBuyerUser()
                                          );


            latestBuyersPot.handleBuy(user, amount, payoutBonusPermille);

        //}


        distribute(_storage, price, user);


        return true;
    }

    function distribute(Storage storage _storage, uint256 amount, address user) private {
        uint256 potFee = amount.mul(_storage.roundSettings.gameFeePotPercent).div(100);
        uint256 buyTokensForPotFee = amount.mul(_storage.roundSettings.gameFeeBuyTokensForPotPercent).div(100);
        uint256 referralFee = amount.sub(potFee).sub(buyTokensForPotFee);


        // send funds to pot
        sendToPot(_storage, potFee);

        // buy tokens for pot
        address[] memory path = new address[](2);
        path[0] = _storage.uniswapV2Router.WETH();
        path[1] = address(_storage.gameToken);

        address potAddress = address(_storage.gameToken.pot());

        uint256 balanceBefore = _storage.gameToken.balanceOf(potAddress);

        // make the swap
        _storage.uniswapV2Router.swapExactETHForTokens {value:buyTokensForPotFee} (
            0,
            path,
            potAddress,
            block.timestamp
        );

        uint256 balanceAfter = _storage.gameToken.balanceOf(potAddress);

        if(balanceAfter > balanceBefore) {
            _storage.tokensBurned = _storage.tokensBurned.add(balanceAfter.sub(balanceBefore));
        }

        //referral
        if(referralFee > 0) {
            address referrer = _storage.gameToken.referredBy(user);

            if(referrer != address(0)) {
                (bool success1,) = referrer.call { value: referralFee, gas: 5000 } ("");

                if(success1) {
                    emit ReferralPayout(referrer, user, referralFee);
                }
            }
            else {
                sendToPot(_storage, referralFee);
            }
        }
    }

    function sendToPot(Storage storage _storage, uint256 amount) private {
        (bool success,) = address(_storage.gameToken.pot()).call {value: amount } ("");
        require(success, "MRSDogeRound: send to pot failed");
    }

    function potBalance(Storage storage _storage) private view returns (uint256) {
        return address(_storage.gameToken.pot()).balance;
    }

    function completeRoundIfOver(Storage storage _storage) public returns (bool) {
        if(_storage.endTimestamp > 0) {
            return false;
        }

        if(blocksLeft(_storage) >= 0) {
            return false;
        }

        _storage.endBlock = block.number;
        _storage.endTimestamp = block.timestamp;

        _storage.gameToken.pot().takeRoundPot();

        uint256 gasCost = 10000000 gwei;

        if(potBalance(_storage) >= gasCost) {
            uint256 blocksToReceiveRandomness = 15;
            _storage.mustReceiveRandomnessByBlock = block.number.add(blocksToReceiveRandomness);

            _storage.gameToken.pot().takeGasFees(gasCost);

            _storage.gameToken.lockTokenHolders(_storage.mustReceiveRandomnessByBlock.add(1));
            _storage.rng.requestRandomnessBNBFee {value: gasCost } ();
        }

        payoutLastBuyer(_storage);
        payoutTopBuyers(_storage);
        payoutMarketing(_storage);

        _storage.gameToken.roundCompleted();

        return true;
    }

    function payoutLastBuyer(Storage storage _storage) private {
        uint256 payout = _storage.roundPot.mul(_storage.payoutSettings.lastBuyerPayoutPercent).div(100);

        if(_storage.buyers.lastBuyer != address(0x0)) {
            uint256 bonus = _storage.roundSettings.calculateBonus(_storage.gameToken, _storage.buyers.lastBuyer, payout);

            if(bonus > 0 && potBalance(_storage) >= bonus) {
                _storage.gameToken.pot().takeBonus(bonus);

                payout = payout.add(bonus);
            }

            (bool success,) = _storage.buyers.lastBuyer.call { value: payout, gas: 5000 } ("");

            if(success) {
                emit Payout(_storage.buyers.lastBuyer, PayoutType.LastBuyer, 0, payout);
            }

            _storage.buyers.lastBuyerPayout = payout;
        }
        else {
            sendToPot(_storage, payout);
        }
    }

    function payoutTopBuyers(Storage storage _storage) private {

        MrsDogeRoundBuyers.Buyer storage buyer = _storage.buyers.topBuyer();

        for(uint256 i = 0; i < MrsDogeRoundBuyers.maxLength(); i = i.add(1)) {
            uint256 payout = _storage.roundPot.mul(_storage.payoutSettings.placePayoutPercents[i]).div(100);

            if(payout == 0) {
                continue;
            }

            if(buyer.user != address(0x0)) {

                uint256 bonus = _storage.roundSettings.calculateBonus(_storage.gameToken, buyer.user, payout);

                if(bonus > 0 && potBalance(_storage) >= bonus) {
                    _storage.gameToken.pot().takeBonus(bonus);

                    payout = payout.add(bonus);
                }

                (bool success,) = buyer.user.call { value: payout, gas: 5000 } ("");

                if(success) {
                    emit Payout(buyer.user, PayoutType.TopBuyer, i.add(1), payout);
                }

                buyer.payout = payout;
            }
            else {
                sendToPot(_storage, payout);
            }

            buyer = _storage.buyers.list[buyer.next];
        }
    }

    function payoutMarketing(Storage storage _storage) private {
        uint256 payout = _storage.roundPot.mul(_storage.payoutSettings.marketingPayoutPercent).div(100);

        if(payout > 0) {
            (bool success,) = _storage.gameToken.teamWallet().call { value: payout, gas: 5000 } ("");

            if(success) {
                emit Payout(_storage.gameToken.teamWallet(), PayoutType.Marketing, 0, payout);
            }
        }
    }

    function receiveRandomness(Storage storage _storage, bytes32, uint256 random) public {
        if(block.number > _storage.mustReceiveRandomnessByBlock) {
            return;
        }

        //unlock
        _storage.gameToken.lockTokenHolders(0);

        address[] memory smallHolders = _storage.gameToken.getRandomHolders(random, _storage.payoutSettings.smallHolderLotteryPayoutCount, MrsDogeTokenHolders.HolderType.Small);
        address[] memory largeHolders = _storage.gameToken.getRandomHolders(random, _storage.payoutSettings.largeHolderLotteryPayoutCount, MrsDogeTokenHolders.HolderType.Large);
        address[] memory hugeHolders = _storage.gameToken.getRandomHolders(random, _storage.payoutSettings.hugeHolderLotteryPayoutCount, MrsDogeTokenHolders.HolderType.Huge);

        payoutHolders(_storage, smallHolders, _storage.payoutSettings.smallHolderLotteryPayoutPercent, PayoutType.SmallHolderLottery);
        payoutHolders(_storage, largeHolders, _storage.payoutSettings.largeHolderLotteryPayoutPercent, PayoutType.LargeHolderLottery);
        payoutHolders(_storage, hugeHolders, _storage.payoutSettings.hugeHolderLotteryPayoutPercent, PayoutType.HugeHolderLottery);
    }


    function payoutHolders(Storage storage _storage, address[] memory holders, uint256 percentOfRoundPot, PayoutType payoutType) private {
        uint256 totalPayout = _storage.roundPot.mul(percentOfRoundPot).div(100);

        if(holders.length > 0) {

            uint256 remaining = totalPayout;

            for(uint256 i = 0; i < holders.length; i = i.add(1)) {
                uint256 payout = remaining.div(holders.length.sub(i));

                uint256 bonus = _storage.roundSettings.calculateBonus(_storage.gameToken, holders[i], payout);

                uint256 payoutWithBonus = payout;

                if(bonus > 0 && potBalance(_storage) >= bonus) {
                    _storage.gameToken.pot().takeBonus(bonus);

                    payoutWithBonus = payout.add(bonus);
                }

                (bool success,) = holders[i].call {value: payoutWithBonus, gas: 5000} ("");

                if(success) {
                    emit Payout(holders[i], payoutType, 0, payoutWithBonus);
                }

                remaining = remaining.sub(payout);
            }
        }
        else {
            sendToPot(_storage, totalPayout);
        }
    }

    function getNumberOfTicketsBought(Storage storage _storage, address user) external view returns (uint256) {
        return _storage.buyers.list[user].ticketsBought;
    }
    
    function generateGameStats(
    			 Storage storage _storage,
        		 address user)
        public
        view
        returns (uint256[] memory roundStats,
                int256 blocksLeftAtCurrentBlock,
                 address lastBuyer,
                 uint256[] memory lastBuyerStats,
                 uint256[] memory userStats,
                 address[] memory topBuyerAddress,
                 uint256[] memory topBuyerData) {

        uint256 currentRoundPot = MrsDogeRoundStorageStats.generateCurrentRoundPot(_storage, cooldownOverBlock(_storage), potBalance(_storage));

        roundStats = MrsDogeRoundStorageStats.generateRoundStats(_storage, currentRoundPot);
        blocksLeftAtCurrentBlock = blocksLeft(_storage);

        lastBuyer = _storage.buyers.lastBuyer;

        lastBuyerStats = MrsDogeRoundStorageStats.generateLastBuyerStats(_storage, currentRoundPot);

        userStats = MrsDogeRoundStorageStats.generateUserStats(_storage, user);
        (topBuyerAddress, topBuyerData) = MrsDogeRoundStorageStats.generateTopBuyerStats(_storage, currentRoundPot);
    }
}
