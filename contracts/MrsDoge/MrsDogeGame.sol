// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./SafeMath.sol";
import "./MrsDogeRound.sol";
import "./MrsDogeToken.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogeRoundFactory.sol";

library MrsDogeGame {
    using SafeMath for uint256;
    using MrsDogeGame for MrsDogeGame.Game;
    using MrsDogeToken for MrsDogeToken.Token;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;
    using MrsDogeGameSettings for MrsDogeGameSettings.PayoutSettings;

    struct Game {
        MrsDogeRound[] rounds;
        MrsDogeRoundFactory roundFactory;
        MrsDogeToken.Token token;
        mapping (address => uint256) userLastTicketBuys; // store last round a user bought tickets
        mapping (address => address) referrals; // maps referred to referrer
    }

    modifier onlyOnceGameHasStarted(Game storage game) {
        MrsDogeRound currentRound = getCurrentRound(game);
        require(address(currentRound) != address(0x0), "MRSDoge: game hasn't started");
        _;
    }

    event Referral(
        address indexed referrer,
        address indexed referred
    );


    event RoundStarted(
        address indexed contractAddress,
        uint256 indexed roundNumber
    );

    event BuyTickets(
        address indexed user,
        uint256 indexed roundNumber,
        uint256 amount,
        uint256 totalTickets,
        int256 blocksLeftBefore,
        int256 blocksLeftAfter
    );

    event RoundCompleted(
        address indexed contractAddress,
        uint256 indexed roundNumber
    );

    function isActive(Game storage game) public view returns (bool) {
        return game.rounds.length > 0;
    }

    function getCurrentRound(Game storage game) public view returns (MrsDogeRound) {
        if(game.rounds.length == 0) {
            return MrsDogeRound(0x0);
        }

        return game.rounds[game.rounds.length - 1];
    }

    function priceForTickets(
        Game storage game,
        MrsDoge gameToken,
        MrsDogeGameSettings.RoundSettings storage roundSettings,
        MrsDogeGameSettings.PayoutSettings storage payoutSettings,
        uint256 potBalance,
        address user,
        uint256 amount)
    public view onlyOnceGameHasStarted(game) returns (uint256) {
        MrsDogeRound currentRound = getCurrentRound(game);

        uint256 cooldownOverBlock = currentRound.cooldownOverBlock();

        if(cooldownOverBlock > 0) {
            require(block.number >= cooldownOverBlock, "MRSDoge: no price during cooldown");

            return roundSettings.calculatePriceForTickets(
                payoutSettings,
                gameToken,
                block.number,
                potBalance,
                user,
                amount);
        }

        return currentRound.priceForTickets(user, amount);
    }

    function buyExactTickets(
        Game storage game,
        address user,
        uint256 amount,
        address referrer)
    public onlyOnceGameHasStarted(game) returns (bool) {
        if(game.referrals[user] == address(0) && referrer != address(0)) {
            game.referrals[user] = referrer;

            emit Referral(referrer, user);
        }

        MrsDogeRound currentRound = getCurrentRound(game);

        // check if need to create a new round
        uint256 cooldownOverBlock = currentRound.cooldownOverBlock();

        if(cooldownOverBlock > 0) {
            require(block.number >= cooldownOverBlock, "MRSDoge: cannot buy during cooldown");

            currentRound = createNewRound(game);
        }

        int blocksLeftBefore = currentRound.blocksLeft();

        if(currentRound.buyExactTickets { value: msg.value } (user, amount)) {
            emit BuyTickets(
                user,
                currentRound.roundNumber(),
                amount,
                currentRound.getNumberOfTicketsBought(user),
                blocksLeftBefore,
                currentRound.blocksLeft());

            game.userLastTicketBuys[user] = currentRound.roundNumber();

            return true;
        }

        return false;
    }

    function createNewRound(
        Game storage game)
    public returns (MrsDogeRound) {
        MrsDogeRound currentRound = getCurrentRound(game);

        if(address(currentRound) != address(0)) {
            currentRound.returnFundsToPot();
        }

        MrsDogeRound round = game.roundFactory.createMrsDogeRound(
            game.token.uniswapV2Router,
            game.rounds.length.add(1));

        round.start();

        game.rounds.push(round);

        emit RoundStarted(
            address(round),
            round.roundNumber()
        );

        return round;
    }

    function completeRound(Game storage game) external onlyOnceGameHasStarted(game) {
        require(getCurrentRound(game).completeRoundIfOver(), "MRSDoge: round could not be completed");
    }

    function roundCompleted(Game storage game) external {
        MrsDogeRound currentRound = getCurrentRound(game);

        emit RoundCompleted(
            address(currentRound),
            currentRound.roundNumber()
        );
    }

    function referredBy(Game storage game, address user) external view returns (address) {
        return game.referrals[user];
    }
}
