// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./MrsDoge.sol";
import "./MrsDogeToken.sol";
import "./MrsDogeGame.sol";
import "./MrsDogeDividendTracker.sol";
import "./MrsDogeGameSettings.sol";
import "./MrsDogePot.sol";
import "./MrsDogeTokenHolders.sol";
import "./MrsDogeRoundFactory.sol";
import "./IERC20.sol";


library MrsDogeStorage {
    using SafeMath for uint256;
    using MrsDogeToken for MrsDogeToken.Token;
    using MrsDogeGame for MrsDogeGame.Game;
    using MrsDogeGameSettings for MrsDogeGameSettings.RoundSettings;
    using MrsDogeGameSettings for MrsDogeGameSettings.PayoutSettings;


    struct Storage {
        MrsDogeRoundFactory roundFactory;
        MrsDogeDividendTracker dividendTracker;
        MrsDogePot pot;

        MrsDogeTokenHolders.Holders tokenHolders;

        MrsDogeToken.Token token;
        MrsDogeGame.Game game;

        MrsDogeGameSettings.RoundSettings roundSettings;
        MrsDogeGameSettings.PayoutSettings payoutSettings;

        address teamWallet;
        address presaleWallet;

        bool roundFactoryLocked;
    }

    struct Fees {
        uint256 liquidityFees;
        uint256 dividendFees;
        uint256 potFees;
    }


    event UpdateTeamWallet(
        address newTeamWallet,
        address oldTeamWallet
    );

    event UpdatePresaleWallet(
        address newPresaleWallet,
        address oldPresaleWallet
    );

    event UpdateRoundFactory(
        address newRoundFactory,
        address oldRoundFactory
    );

    event RoundFactoryLocked(
        address roundFactoryAddress
    );



    event CooldownExtended(
        uint256 roundNumber,
        uint256 blocksAdded,
        uint256 endBlock
    );

    event AddToPot(uint256 amount);

    event SendDividends(
        uint256 amount
    );

     event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    function updateTeamWallet(Storage storage _storage, address newTeamWallet) public {
        emit UpdateTeamWallet(newTeamWallet, _storage.teamWallet);
        _storage.teamWallet = newTeamWallet;
    }

    function updatePresaleWallet(Storage storage _storage, address newPresaleWallet) public {
        emit UpdatePresaleWallet(newPresaleWallet, _storage.presaleWallet);
        _storage.presaleWallet = newPresaleWallet;
    }


    function updateRoundFactory(Storage storage _storage, address newRoundFactory) public {
        require(!_storage.roundFactoryLocked, "MRSDoge: round factory is locked");
        emit UpdateRoundFactory(newRoundFactory, address(_storage.roundFactory));
        _storage.roundFactory = MrsDogeRoundFactory(newRoundFactory);
        _storage.game.roundFactory = _storage.roundFactory;
    }

    function lockRoundFactory(Storage storage _storage) public {
        require(!_storage.roundFactoryLocked, "MRSDoge: round factory already locked");
        _storage.roundFactoryLocked = true;
        emit RoundFactoryLocked(address(_storage.roundFactory));
    }

    function isExcludedFromFees(Storage storage _storage, address account) public view returns(bool) {
        return _storage.token.isExcludedFromFees[account];
    }

    function extendCurrentRoundCooldown(Storage storage _storage, uint256 blocks) public {
        require(blocks > 0 && blocks <= 28800, "MRSDoge: invalid value for blocks");

        MrsDogeRound currentRound = _storage.game.getCurrentRound();

        require(address(currentRound) != address(0x0), "MRSDoge: game has not started");

        uint256 cooldownOverBlock = currentRound.cooldownOverBlock();

        require(block.number < cooldownOverBlock, "MRSDoge: the cooldown is not active");

        currentRound.extendCooldown(blocks);

        emit CooldownExtended(
            currentRound.roundNumber(),
            blocks,
            currentRound.cooldownOverBlock()
        );
    }

    function processDividendTracker(
        Storage storage _storage,
        uint256 gas)
    public {
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = _storage.dividendTracker.process(gas);
        emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }


    function handleTransfer(
        Storage storage _storage,
        address from,
        address to,
        uint256 gas)
    public {
        try _storage.dividendTracker.handleTransfer(from, to, gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            if(gas > 0) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            }
        }
        catch {}
    }


    function possiblySwapContractTokens(
        Storage storage _storage,
        address from,
        address to,
        MrsDogeToken.TransferType transferType,
        address owner,
        uint256 contractTokenBalance
    ) public {

        bool overMinTokenBalance = contractTokenBalance >= _storage.token.tokenSwapThreshold;

        if(
            _storage.game.isActive() &&
            overMinTokenBalance &&
            !_storage.token.inSwap &&
            transferType == MrsDogeToken.TransferType.Sell &&
            from != owner &&
            to != owner
        ) {
            _storage.token.inSwap = true;

            _storage.token.swapAndLiquify(_storage.teamWallet, _storage.token.accumulatedLiquidityTokens);

            uint256 sellTokens = contractTokenBalance.sub(_storage.token.accumulatedLiquidityTokens);

            _storage.token.swapTokensForEth(sellTokens);

            uint256 toDividends = _storage.token.tokenAddress.balance.mul(_storage.token.accumulatedDividendTokens).div(sellTokens);
            uint256 toPot = _storage.token.tokenAddress.balance.sub(toDividends);

            (bool success1,) = address(_storage.dividendTracker).call{value: toDividends}("");

            if(success1) {
                emit SendDividends(toDividends);
            }

            (bool success2,) = address(_storage.pot).call{value: toPot}("");

            if(success2) {
                emit AddToPot(toPot);
            }

            _storage.token.accumulatedLiquidityTokens = 0;
            _storage.token.accumulatedDividendTokens = 0;
            _storage.token.accumulatedPotTokens = 0;

            _storage.token.inSwap = false;
        }
    }

    function calculateTokenFee(
        Storage storage _storage,
        address from,
        address to,
        uint256 amount,
        MrsDogeToken.TransferType transferType
    ) public view returns (Fees memory) {
        bool takeFee = _storage.game.isActive() && !_storage.token.inSwap;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(isExcludedFromFees(_storage, from) || isExcludedFromFees(_storage, to)) {
            takeFee = false;
        }

        // no transfer fees for first week
        if(transferType == MrsDogeToken.TransferType.Normal) {
            if(_storage.game.rounds.length == 0) {
                takeFee = false;
            } else {
                MrsDogeRound round = _storage.game.rounds[0];

                uint256 timeSinceStartOfFirstRound = block.timestamp.sub(round.startTimestamp());

                if(timeSinceStartOfFirstRound <= uint256(86400).mul(7)) {
                    takeFee = false;
                }
            }
        }

        if(!takeFee) {
            return Fees(0, 0, 0);
        }

        uint256 liquidityFeePerMillion = _storage.token.liquidityFee.mul(10000);
        uint256 dividendFeePerMillion = _storage.token.dividendFeeLow.mul(10000);
        uint256 potFeePerMillion = _storage.token.potFeeLow.mul(10000);

        if(transferType == MrsDogeToken.TransferType.Sell) {
            uint256 dividendFeePerMillionUpperBound = _storage.token.dividendFeeHigh.mul(10000);
            uint256 potFeePerMillionUpperBound = _storage.token.potFeeHigh.mul(10000);

            uint256 dividendFeeDifferencePerMillion = dividendFeePerMillionUpperBound.sub(dividendFeePerMillion);
            uint256 potFeeDifferencePerMillion = potFeePerMillionUpperBound.sub(potFeePerMillion);

            dividendFeePerMillion = dividendFeePerMillion.add(
                calculateExtraTokenFee(_storage, from, dividendFeeDifferencePerMillion)
            );

            potFeePerMillion = potFeePerMillion.add(
                calculateExtraTokenFee(_storage, from, potFeeDifferencePerMillion)
            );
        }


        return Fees(
            amount.mul(liquidityFeePerMillion).div(1000000),
            amount.mul(dividendFeePerMillion).div(1000000),
            amount.mul(potFeePerMillion).div(1000000)
        );
    }


    function calculateExtraTokenFee(
        Storage storage _storage,
        address from,
        uint256 max
    ) private view returns (uint256) {
        uint256 timeSinceFeeBegin = block.timestamp.sub(_storage.token.feeBeginTimestamp[from]);

        uint256 feeTimeLeft = 0;

        if(timeSinceFeeBegin < _storage.token.feesLoweringDuration) {
            feeTimeLeft = _storage.token.feesLoweringDuration.sub(timeSinceFeeBegin);
        }

        return max
               .mul(feeTimeLeft)
               .div(_storage.token.feesLoweringDuration);
    }

    function calculateTotalFees(Fees memory fees) public pure returns(uint256) {
        return fees.liquidityFees.add(fees.dividendFees).add(fees.potFees);
    }
}
