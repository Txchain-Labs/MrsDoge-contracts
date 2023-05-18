// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;


import "./MrsDogeRoundStorage.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogeRoundBuyers.sol";
import "./SafeMath.sol";

library MrsDogeRoundStorageStats {
    using SafeMath for uint256;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;

    function generateRoundStats(MrsDogeRoundStorage.Storage storage _storage, uint256 currentRoundPot)
    	public
    	view
    	returns (uint256[] memory roundStats) {
        roundStats = new uint256[](14);

        roundStats[0] = _storage.roundNumber;
        roundStats[1] = _storage.startBlock;
        roundStats[2] = _storage.startTimestamp;
        roundStats[3] = _storage.endBlock;
        roundStats[4] = _storage.endTimestamp;
        roundStats[5] = _storage.ticketsBought;
        roundStats[6] = _storage.totalSpentOnTickets;
        roundStats[7] = currentRoundPot;
        roundStats[8] = _storage.blocksLeftAtLastBuy;
        roundStats[9] = _storage.lastBuyBlock;
        roundStats[10] = _storage.tokensBurned;
        roundStats[11] = block.timestamp;
        roundStats[12] = block.number;
        roundStats[13] = address(_storage.gameToken.pot()).balance;
    }

    function generateLastBuyerStats(MrsDogeRoundStorage.Storage storage _storage, uint256 currentRoundPot)
    	public
    	view
    	returns (uint256[] memory lastBuyerStats) {
        lastBuyerStats = new uint256[](5);

        if(_storage.buyers.lastBuyerPayout > 0) {
            lastBuyerStats[0] = _storage.buyers.lastBuyerPayout;
        }
        else {
            lastBuyerStats[0] = calculateLastBuyerPayout(_storage, currentRoundPot);
        }

        if(_storage.buyers.lastBuyer != address(0)) {
            lastBuyerStats[1] = _storage.gameToken.balanceOf(_storage.buyers.lastBuyer);

            uint256 bonusPermille = _storage.roundSettings.getUserBonusPermille(_storage.gameToken, _storage.buyers.lastBuyer);
            lastBuyerStats[2] = bonusPermille;

            lastBuyerStats[3] = _storage.buyers.lastBuyerBlock;

            uint256 earningsPerBlock = _storage.gameToken.pot().latestBuyerPot().latestBuyerEarningsPerBlock();
            lastBuyerStats[4] = earningsPerBlock.add(earningsPerBlock.mul(bonusPermille).div(1000));
        }
    }

    function calculateLastBuyerPayout(MrsDogeRoundStorage.Storage storage _storage, uint256 currentRoundPot) private view returns (uint256 lastBuyerPayout) {
        lastBuyerPayout = currentRoundPot.mul(_storage.payoutSettings.lastBuyerPayoutPercent).div(100);
        uint256 bonus = _storage.roundSettings.calculateBonus(_storage.gameToken, _storage.buyers.lastBuyer, lastBuyerPayout);
        lastBuyerPayout = lastBuyerPayout.add(bonus);
    }

    function generateUserStats(
        MrsDogeRoundStorage.Storage storage _storage,
        address user)
    	public
        view
        returns (uint256[] memory userStats) {
        userStats = new uint256[](6);

        userStats[0] = _storage.buyers.list[user].ticketsBought;
        userStats[1] = _storage.buyers.list[user].totalSpentOnTickets;
        userStats[2] = _storage.buyers.list[user].lastBuyBlock;
        userStats[3] = _storage.buyers.list[user].lastBuyTimestamp;
        userStats[4] = _storage.gameToken.balanceOf(user);
        userStats[5] = _storage.roundSettings.getUserBonusPermille(_storage.gameToken, user);
    }

    function generateTopBuyerStats(MrsDogeRoundStorage.Storage storage _storage, uint256 currentRoundPot)
        public
        view
        returns (address[] memory topBuyerAddress,
                uint256[] memory topBuyerData) {
        uint256 maxLength = MrsDogeRoundBuyers.maxLength();

        uint256 topBuyerDataLength = 6;

        topBuyerAddress = new address[](maxLength);
        topBuyerData = new uint256[](maxLength.mul(topBuyerDataLength));

        MrsDogeRoundBuyers.Buyer storage buyer = _storage.buyers.list[_storage.buyers.head];

        for(uint256 i = 0; i < maxLength; i++) {

            uint256 payout = 0;

            if(i < 3) {
                if(buyer.payout > 0) {
                    payout = buyer.payout;
                }
                else {
                    payout = currentRoundPot.mul(_storage.payoutSettings.placePayoutPercents[i]).div(100);
                    payout = payout.add(
                        _storage.roundSettings.calculateBonus(
                            _storage.gameToken,
                            buyer.user,
                            payout
                        )
                    );
                }
            }

            topBuyerAddress[i] = buyer.user;

            uint256 startIndex = i.mul(topBuyerDataLength);

            topBuyerData[startIndex.add(0)] = buyer.ticketsBought;
            topBuyerData[startIndex.add(1)] = buyer.lastBuyBlock;
            topBuyerData[startIndex.add(2)] = buyer.lastBuyTimestamp;
            topBuyerData[startIndex.add(3)] = payout;
            topBuyerData[startIndex.add(4)] = _storage.gameToken.balanceOf(buyer.user);
            topBuyerData[startIndex.add(5)] = _storage.roundSettings.getUserBonusPermille(_storage.gameToken, buyer.user);

            buyer = _storage.buyers.list[buyer.next];
        }
    }

    function generateCurrentRoundPot(MrsDogeRoundStorage.Storage storage _storage, uint256 cooldownOverBlock, uint256 potBalance)
    	public
   	 	view
    	returns (uint256) {
        if(_storage.roundPot > 0 && (cooldownOverBlock == 0 || block.number < cooldownOverBlock)) {
            return _storage.roundPot;
        }

        if(cooldownOverBlock > 0 && block.number > cooldownOverBlock) {
            potBalance = potBalance.add(address(this).balance);
        }

        return potBalance.mul(_storage.payoutSettings.roundPotPercent).div(100);
    }

}
