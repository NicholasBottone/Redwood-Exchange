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

    // Limit order IDs for buy and sell
    uint256 public buyOrderID;
    uint256 public sellOrderID;
    bool public buyOrderExists;
    bool public sellOrderExists;

    // Wallet --> Trader balances by token
    mapping(address => mapping(bytes32 => uint256)) public traderBalances;

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
        require(tokenAmount > 0 || pineAmount > 0);
        require(IERC20(tokenP).balanceOf(msg.sender) >= pineAmount);
        require(IERC20(token1).balanceOf(msg.sender) >= tokenAmount);

        // Pine
        if (pineAmount > 0) {
            // Transfer the deposited amount to this contract
            IERC20(tokenP).transferFrom(msg.sender, address(this), pineAmount);

            // Approve the Dex to deposit the amount of Pine and token
            IERC20(tokenP).approve(dex, pineAmount);

            // Deposit Pine to the exchange
            IExc(dex).deposit(pineAmount, tokenPT);

            // Update the balances of the wallet
            traderBalances[msg.sender][tokenPT] = traderBalances[msg.sender][
                tokenPT
            ].add(pineAmount);

            // Add to the pool
            poolPine = poolPine.add(pineAmount);
        }

        // Token
        if (tokenAmount > 0) {
            // Transfer the deposited amount to this contract
            IERC20(token1).transferFrom(msg.sender, address(this), tokenAmount);

            // Update the balances of the wallet
            traderBalances[msg.sender][token1T] = traderBalances[msg.sender][
                token1T
            ].add(tokenAmount);

            // Add to the pool
            poolToken = poolToken.add(tokenAmount);

            // Approve the Dex to deposit the amount of Pine and token
            IERC20(token1).approve(dex, tokenAmount);

            // Deposit token to the exchange
            IExc(dex).deposit(tokenAmount, token1T);
        }

        // Remove/cancel the old limit orders
        if (buyOrderExists) {
            if (pineAmount > 0) {
                IExc(dex).deleteLimitOrder(buyOrderID, token1T, IExc.Side.BUY);
            }
        }
        if (sellOrderExists) {
            if (tokenAmount > 0) {
                IExc(dex).deleteLimitOrder(
                    sellOrderID,
                    token1T,
                    IExc.Side.SELL
                );
            }
        }

        // Delete old limit orders
        if (ordersExist) {
            IExc(dex).deleteLimitOrder(buyOrderID, token1T, IExc.Side.BUY);
            IExc(dex).deleteLimitOrder(sellOrderID, token1T, IExc.Side.SELL);
        }

        // Make a buy limit order and sell limit order with the calculated market price
        uint256 tradeRatio = getTradeRatio();
        if (tokenAmount > 0) {
            IExc(dex).makeLimitOrder(
                token1T,
                poolToken,
                tradeRatio,
                IExc.Side.SELL
            );
            sellOrderID = IExc(dex).getLastOrderID();
            sellOrderExists = true;
        }
        if (pineAmount > 0) {
            IExc(dex).makeLimitOrder(
                token1T,
                poolToken,
                tradeRatio,
                IExc.Side.BUY
            );
            buyOrderID = IExc(dex).getLastOrderID();
            buyOrderExists = true;
        }
    }

    function withdraw(uint256 tokenAmount, uint256 pineAmount) external {
        // Ensure balances are sufficient
        require(tokenAmount <= traderBalances[msg.sender][token1T]);
        require(pineAmount <= traderBalances[msg.sender][tokenPT]);

<<<<<<< HEAD
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
=======
        if (tokenAmount > 0) {
            require(sellOrderExists);
        }
        if (pineAmount > 0) {
            require(buyOrderExists);
        }

        // Update the balances of the wallet
        traderBalances[msg.sender][tokenPT] = traderBalances[msg.sender][
            tokenPT
        ].sub(pineAmount);
        traderBalances[msg.sender][token1T] = traderBalances[msg.sender][
            token1T
        ].sub(tokenAmount);

        // Pine
        if (pineAmount > 0) {
            // Remove/cancel the old limit order
            IExc(dex).deleteLimitOrder(buyOrderID, token1T, IExc.Side.BUY);

            // Withdraw Pine from the exchange to this contract
            IExc(dex).withdraw(pineAmount, tokenPT);

            // Subtract from the pool
            poolPine = poolPine.sub(pineAmount);

            // Transfer the withdrawn amount to the trader
            IERC20(tokenP).transfer(msg.sender, pineAmount);
        }

        // Token
        if (tokenAmount > 0) {
            // Remove/cancel the old limit order
            IExc(dex).deleteLimitOrder(sellOrderID, token1T, IExc.Side.SELL);

            // Withdraw token from the exchange to this contract
            IExc(dex).withdraw(tokenAmount, token1T);

            // Subtract from the pool
            poolToken = poolToken.sub(tokenAmount);

            // Transfer the withdrawn amount to the trader
            IERC20(token1).transfer(msg.sender, tokenAmount);
        }

        // Make a buy limit order and sell limit order with the calculated market price
        uint256 tradeRatio = getTradeRatio();
        if (tokenAmount > 0) {
            IExc(dex).makeLimitOrder(
                token1T,
                poolToken,
                tradeRatio,
                IExc.Side.SELL
            );
            sellOrderID = IExc(dex).getLastOrderID();
        }
        if (pineAmount > 0) {
            IExc(dex).makeLimitOrder(
                token1T,
                poolToken,
                tradeRatio,
                IExc.Side.BUY
            );
            buyOrderID = IExc(dex).getLastOrderID();
>>>>>>> be4804be3581734875827a6aae6e394e3e786a56
        }
    }

    function getTradeRatio() internal view returns (uint256) {
        if (poolToken == 0 || poolPine == 0) {
            // if either token or pine is 0, return 0
            return 0;
        }

        return poolPine.div(poolToken); // pine to token ratio
    }

    function testing(uint256 testMe) public pure returns (uint256) {
        if (testMe == 1) {
            return 5;
        } else {
            return 3;
        }
    }
}
