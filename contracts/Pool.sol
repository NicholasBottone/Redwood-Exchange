pragma solidity 0.5.3;

import "./Exc.sol";
import "../contracts/libraries/math/SafeMath.sol";

contract Pool {
    // SafeMath
    using SafeMath for uint256;
    using SafeMath for uint256;

    /// @notice some parameters for the pool to function correctly, feel free to add more as needed
    address private tokenP; // pine address
    address private token1; // other token address
    address private dex; // exchange address (Exc address)
    bytes32 private tokenPT; // pine ticker
    bytes32 private token1T; // other token ticker

    // Pool balances (for tracking the ratio between pine and token)
    uint256 public poolPine;
    uint256 public poolToken;

    // Pool market order IDs
    bool public ordersExist;
    uint256 public buyOrderID;
    uint256 public sellOrderID;

    // todo: fill in the initialize method, which should simply set the parameters of the contract correctly. To be called once
    // upon deployment by the factory.
    function initialize(
        address _token0,
        address _token1,
        address _dex,
        uint256 whichP,
        bytes32 _tickerQ,
        bytes32 _tickerT
    ) external {
        // hypothetically done

        dex = _dex;

        if (whichP == 1) {
            tokenP = _token0;
            token1 = _token1;
            tokenPT = _tickerQ;
            token1T = _tickerT;
        } else {
            tokenP = _token1;
            token1 = _token0;
            tokenPT = _tickerT;
            token1T = _tickerQ;
        }
    }

    // todo: implement wallet functionality and trading functionality

    // todo: implement withdraw and deposit functions so that a single deposit and a single withdraw can unstake
    // both tokens at the same time
    function deposit(uint256 tokenAmount, uint256 pineAmount) external {
        // Approve the Dex to deposit the amount of Pine and token
        IERC20(tokenP).approve(dex, pineAmount);
        IERC20(token1).approve(dex, tokenAmount);

        // Add to the pool
        poolPine = poolPine.add(pineAmount);
        poolToken = poolToken.add(tokenAmount);

        // Deposit Pine and token to the exchange
        IExc(dex).deposit(pineAmount, tokenPT);
        IExc(dex).deposit(tokenAmount, token1T);

        // Delete old limit orders
        if (ordersExist) {
            IExc(dex).deleteLimitOrder(buyOrderID, token1T, IExc.Side.BUY);
            IExc(dex).deleteLimitOrder(sellOrderID, token1T, IExc.Side.SELL);
        }

        // Make a buy limit order and sell limit order with the calculated market price
        uint256 tradeRatio = getTradeRatio();
        IExc(dex).makeLimitOrder(
            token1T,
            tokenAmount,
            tradeRatio,
            IExc.Side.SELL
        );
        sellOrderID = IExc(dex).getLastOrderId();
        IExc(dex).makeLimitOrder(
            token1T,
            pineAmount.div(tradeRatio),
            tradeRatio,
            IExc.Side.BUY
        );
        buyOrderID = IExc(dex).getLastOrderId();
        ordersExist = true;
    }

    function withdraw(uint256 tokenAmount, uint256 pineAmount) external {
        // Delete old limit orders
        if (ordersExist) {
            IExc(dex).deleteLimitOrder(buyOrderID, token1T, IExc.Side.BUY);
            IExc(dex).deleteLimitOrder(sellOrderID, token1T, IExc.Side.SELL);
        }

        // Approve the Dex to withdraw the amount of Pine and token
        IERC20(tokenP).approve(dex, pineAmount);
        IERC20(token1).approve(dex, tokenAmount);

        // Withdraw Pine and token from the exchange
        IExc(dex).withdraw(pineAmount, tokenPT);
        IExc(dex).withdraw(tokenAmount, token1T);

        // Subtract from the pool
        poolPine = poolPine.sub(pineAmount);
        poolToken = poolToken.sub(tokenAmount);

        if (ordersExist) {
            // Make a buy limit order and sell limit order with the calculated market price
            uint256 tradeRatio = getTradeRatio();
            IExc(dex).makeLimitOrder(
                token1T,
                tokenAmount,
                tradeRatio,
                IExc.Side.SELL
            );
            sellOrderID = IExc(dex).getLastOrderId();
            IExc(dex).makeLimitOrder(
                token1T,
                pineAmount.div(tradeRatio),
                tradeRatio,
                IExc.Side.BUY
            );
            buyOrderID = IExc(dex).getLastOrderId();
        }
    }

    function getTradeRatio() internal view returns (uint256) {
        if (poolToken == 0 || poolPine == 0) {
            // if either token or pine is 0, return 0
            return 0;
        }

        return poolToken.div(poolPine); // token to pine ratio
    }

    function testing(uint256 testMe) public pure returns (uint256) {
        if (testMe == 1) {
            return 5;
        } else {
            return 3;
        }
    }
}
