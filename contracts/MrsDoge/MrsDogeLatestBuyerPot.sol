// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./SafeMath.sol";
import "./MrsDoge.sol";
import "./MrsDogePot.sol";
import "./MrsDogeRound.sol";
import "./MathUtils.sol";

contract MrsDogeLatestBuyerPot {
    using SafeMath for uint256;

    MrsDoge public token;

    uint256 public permillePerHour;

    struct LatestBuyer
    {
        address user;
        uint256 roundNumber;
        uint256 blockNumber;
        uint256 earningsPerBlock;
    }

    LatestBuyer public latestBuyer;

    modifier onlyCurrentRound() {
        MrsDogeRound round = token.getCurrentRound();
        require(msg.sender == address(round), "MRSDogeLatestBuyerPot: caller is not the current round");
        _;
    }

    modifier onlyTokenOwner() {
        require(msg.sender == token.owner(), "MRSDogeLatestBuyerPot: caller is not the token owner");
        _;
    }

    event PermillePerHourUpdated(uint256 newValue, uint256 oldValue);
    event LatestBuyerPayout(address indexed user, uint256 indexed roundNumber, uint256 amount, uint256 blocksElapsed);

    constructor() public {
        MrsDogePot pot = MrsDogePot(msg.sender);

    	  token = MrsDoge(payable(pot.owner()));

        permillePerHour = 50;
        emit PermillePerHourUpdated(permillePerHour, 0);
    }

    receive() external payable {

    }

    function updatePermillePerHour(uint256 _permillePerHour) public onlyTokenOwner {
        require(_permillePerHour <= 500);
        emit PermillePerHourUpdated(_permillePerHour, permillePerHour);
        permillePerHour = _permillePerHour;
    }

    function sendEarnings(address user, uint256 amount, uint256 blocksElapsed) private {
        (bool success,) = user.call {value: amount} ("");

        if(success) {
            emit LatestBuyerPayout(
                latestBuyer.user,
                latestBuyer.roundNumber,
                amount,
                blocksElapsed);
        }
    }

    function calculateEarningsPerBlock(uint256 ticketsBought) private view returns (uint256) {
        uint256 earningsPerHour = permillePerHour.mul(address(this).balance).div(1000);

        earningsPerHour = earningsPerHour.mul(MathUtils.sqrt(ticketsBought.mul(10000)).div(100));

        return earningsPerHour.div(1200);
    }

    function handleBuy(address user, uint256 ticketsBought, uint256 payoutBonusPermille) external onlyCurrentRound {
        uint256 currentRoundNumber = token.getCurrentRound().roundNumber();
        uint256 currentBlock = block.number;

        if(latestBuyer.user != address(0x0) &&
           latestBuyer.roundNumber == currentRoundNumber) {
            uint256 blocksElapsed = currentBlock.sub(latestBuyer.blockNumber);
            uint256 earnings = blocksElapsed.mul(latestBuyer.earningsPerBlock);

            earnings = earnings.add(earnings.mul(payoutBonusPermille).div(1000));

            if(earnings > address(this).balance) {
                earnings = address(this).balance;
            }

            sendEarnings(latestBuyer.user, earnings, blocksElapsed);
        }

        latestBuyer.user = user;
        latestBuyer.roundNumber = currentRoundNumber;
        latestBuyer.blockNumber = currentBlock;
        latestBuyer.earningsPerBlock = calculateEarningsPerBlock(ticketsBought);
    }


    function latestBuyerUser() public view returns (address) {
        return latestBuyer.user;
    }

    function latestBuyerEarningsPerBlock() public view returns (uint256) {
        return latestBuyer.earningsPerBlock;
    }

}
