// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "./MrsDoge.sol";
import "./MrsDogeStorage.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router.sol";
import "./IERC20.sol";

library MrsDogeToken {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;


    struct Token {
        address tokenAddress;
        uint256 liquidityFee;
        uint256 dividendFeeLow;
        uint256 potFeeLow;
        uint256 dividendFeeHigh;
        uint256 potFeeHigh;
        uint256 feesLoweringDuration;
        uint256 gasForProcessing;
        uint256 tokenSwapThreshold;
        uint256 accumulatedLiquidityTokens;
        uint256 accumulatedDividendTokens;
        uint256 accumulatedPotTokens;
        bool inSwap;
        address uniswapV2Pair;
        IUniswapV2Router02 uniswapV2Router;
        mapping (address => bool) isExcludedFromFees;
        mapping (address => uint256) feeBeginTimestamp;
    }

    enum TransferType {
        Normal,
        Buy,
        Sell,
        RemoveLiquidity
    }

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    function excludeFromFees(Token storage token, address account, bool excluded) public {
        require(token.isExcludedFromFees[account] != excluded, "MRSDoge: account is already excluded");
        token.isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function updateGasForProcessing(Token storage token, uint256 newValue) public {
        require(newValue >= 200000 && newValue <= 500000, "MRSDoge: gasForProcessing must be between 200,000 and 500,000");
        require(newValue != token.gasForProcessing, "MRSDoge: Cannot update gasForProcessing to same value");
        emit GasForProcessingUpdated(newValue, token.gasForProcessing);
        token.gasForProcessing = newValue;
    }

    function getTransferType(
        Token storage token,
        address from,
        address to)
        public
        view
        returns (TransferType) {
        if(from == token.uniswapV2Pair) {
            if(to == address(token.uniswapV2Router)) {
                return TransferType.RemoveLiquidity;
            }
            return TransferType.Buy;
        }
        if(to == token.uniswapV2Pair) {
            return TransferType.Sell;
        }
        if(from == address(token.uniswapV2Router)) {
            return TransferType.RemoveLiquidity;
        }

        return TransferType.Normal;
    }

    function swapTokensForEth(Token storage token, uint256 tokenAmount) public returns (uint256) {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = token.uniswapV2Router.WETH();

        uint256 initialBalance = address(this).balance;

        // make the swap
        token.uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        return address(this).balance.sub(initialBalance);
    }

    function addLiquidity(Token storage token, address recipient, uint256 tokenAmount, uint256 ethAmount) public {
        // add the liquidity
        token.uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            recipient,
            block.timestamp
        );

    }

    function swapAndLiquify(Token storage token, address recipient, uint256 tokens) public {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(token, half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 difference = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(token, recipient, otherHalf, difference);

        emit SwapAndLiquify(half, difference, otherHalf);
    }

    function incrementAccumulatedTokens(
        Token storage token,
        MrsDogeStorage.Fees memory fees) public {
        token.accumulatedLiquidityTokens = token.accumulatedLiquidityTokens.add(fees.liquidityFees);
        token.accumulatedDividendTokens = token.accumulatedDividendTokens.add(fees.dividendFees);
        token.accumulatedPotTokens = token.accumulatedDividendTokens.add(fees.potFees);
    }

    function totalAccumulatedTokens(
        Token storage token) public view returns (uint256) {
        return token.accumulatedLiquidityTokens
               .add(token.accumulatedDividendTokens)
               .add(token.accumulatedPotTokens);
    }

    function getTokenPrice(Token storage token) public view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(token.uniswapV2Pair);
        (uint256 left, uint256 right,) = pair.getReserves();

        (uint tokenReserves, uint bnbReserves) = (token.tokenAddress < token.uniswapV2Router.WETH()) ?
        (left, right) : (right, left);

        return (bnbReserves * 10**18) / tokenReserves;
    }

}
