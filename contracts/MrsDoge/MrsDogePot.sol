// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./MrsDoge.sol";
import "./MrsDogeRound.sol";
import "./MrsDogeLatestBuyerPot.sol";

contract MrsDogePot is Ownable {
    using SafeMath for uint256;

    MrsDoge public token;
    MrsDogeLatestBuyerPot public latestBuyerPot;

    uint256 public latestBuyerPercent;

    modifier onlyCurrentRound() {
        MrsDogeRound round = token.getCurrentRound();
        require(msg.sender == address(round), "MRSDogePot: caller is not the current round");
        _;
    }

    modifier onlyTokenOwner() {
        require(msg.sender == token.owner(), "MRSDogePot: caller is not the token owner");
        _;
    }

    event LatestBuyerPercentUpdated(uint256 newValue, uint256 oldValue);

    event RoundPotTaken(uint256 indexed roundNumber, uint256 amount);

    constructor() public {
    	token = MrsDoge(payable(owner()));
        latestBuyerPercent = 10;
        emit LatestBuyerPercentUpdated(latestBuyerPercent, 0);
    }

    receive() external payable {
        if(address(latestBuyerPot) == address(0)) {
            latestBuyerPot = new MrsDogeLatestBuyerPot();
        }

        uint256 forwardAmount = msg.value.mul(latestBuyerPercent).div(100);

        safeSend(address(latestBuyerPot), forwardAmount);
    }

    function updateLatestBuyerPercent(uint256 _latestBuyerPercent) public onlyTokenOwner {
        require(_latestBuyerPercent <= 50);
        emit LatestBuyerPercentUpdated(_latestBuyerPercent, latestBuyerPercent);
        latestBuyerPercent = _latestBuyerPercent;
    }

    function safeSend(address account, uint256 amount) private {
        (bool success,) = account.call {value: amount} ("");

        require(success, "MRSDogePot: could not send");
    }

    function takeRoundPot() external onlyCurrentRound {
    	MrsDogeRound round = token.getCurrentRound();

    	uint256 roundPot = address(this).balance.mul(round.roundPotPercent()).div(100);

        round.receiveRoundPot { value: roundPot } ();

        emit RoundPotTaken(round.roundNumber(), roundPot);
    }

    function takeBonus(uint256 amount) external onlyCurrentRound {
        MrsDogeRound round = token.getCurrentRound();

        round.receiveBonus { value: amount } ();
    }

    function takeGasFees(uint256 amount) external onlyCurrentRound {
        MrsDogeRound round = token.getCurrentRound();

        round.receiveGasFees { value: amount } ();
    }
}
