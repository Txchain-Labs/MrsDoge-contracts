// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./IUniswapV2Router.sol";
import "./MrsDogeRound.sol";

contract MrsDogeRoundFactory {
    function createMrsDogeRound(
        IUniswapV2Router02 _uniswapV2Router,
        uint256 roundNumber)
        public
        returns (MrsDogeRound) {
        MrsDogeRound round = new MrsDogeRound(
            _uniswapV2Router,
            roundNumber);

        round.makeTokenOwner(msg.sender);

        return round;
    }
}
