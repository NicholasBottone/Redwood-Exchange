pragma solidity 0.5.3;
pragma experimental ABIEncoderV2;

import "../contracts/libraries/token/ERC20/ERC20.sol";
import "../contracts/libraries/math/SafeMath.sol";
import "../contracts/libraries/math/Math.sol";
import "./IExc.sol";

contract Exc is IExc {
    using SafeMath for uint256;
    using SafeMath for uint256;

    /// @notice these declarations are incomplete. You will still need a way to store the orderbook, the balances
    /// of the traders, and the IDs of the next trades and orders. Reference the NewTrade event and the IExc
    /// interface for more details about orders and sides.
    mapping(bytes32 => Token) public tokens;
    bytes32[] public tokenList;
    bytes32 constant PIN = bytes32("PIN"); // pine

    // Wallet --> Trader balances by token
    mapping(address => mapping(bytes32 => uint256)) public traderBalances;

    // The orderbook is a list of orders sorted by price.
    uint256[] public orderBookIds;
    mapping(uint256 => Order) public orderBook;

    // Last order ID
    uint256 private lastOrderId;

    // The next trade ID
    uint256 private nextTradeId;

    /// @notice an event representing all the needed info regarding a new trade on the exchange
    event NewTrade(
        uint256 tradeId,
        uint256 orderId,
        bytes32 indexed ticker,
        address indexed trader1,
        address indexed trader2,
        uint256 amount,
        uint256 price,
        uint256 date
    );

    /// @notice an event representing all the needed info regarding a new order on the exchange
    event NewOrder(
        uint256 orderId,
        bytes32 indexed ticker,
        address indexed trader,
        uint256 amount,
        uint256 price,
        uint256 date
    );

    /// @notice an event representing all the needed info regarding a cancel order on the exchange
    event DeleteOrder(
        uint256 orderId,
        bytes32 indexed ticker,
        address indexed trader,
        uint256 date
    );

    /// @notice an event representing all the needed info regarding a filled limit order on the exchange
    event FilledLimitOrder(
        uint256 orderId,
        bytes32 indexed ticker,
        address indexed trader,
        uint256 date
    );

    // Gets the last order ID
    function getLastOrderID() external view returns (uint256) {
        return lastOrderId;
    }

    // todo: implement getOrders, which simply returns the orders for a specific token on a specific side
    function getOrders(bytes32 ticker, Side side)
        external
        view
        tokenExists(ticker)
        returns (Order[] memory)
    {
        Order[] memory returnList;

        for (uint256 i = 0; i < orderBookIds.length; i++) {
            Order memory order = orderBook[orderBookIds[i]];
            if (order.ticker == ticker && order.side == side) {
                returnList[returnList.length] = order;
            }
        }

        return returnList;
    }

    // todo: implement getTokens, which simply returns an array of the tokens currently traded on in the exchange
    function getTokens() external view returns (Token[] memory) {
        Token[] memory returnTokens;

        for (uint256 i = 0; i < tokenList.length; i++) {
            Token memory token = tokens[tokenList[i]];
            returnTokens[returnTokens.length] = token;
        }

        return returnTokens;
    }

    // todo: implement addToken, which should add the token desired to the exchange by interacting with tokenList and tokens
    function addToken(bytes32 ticker, address tokenAddress) external {
        if (tokens[ticker].tokenAddress != address(0)) {
            return; // Token already exists
        }
        tokenList.push(ticker);
        tokens[ticker] = Token(ticker, tokenAddress);
    }

    // todo: implement deposit, which should deposit a certain amount of tokens from a trader to their on-exchange wallet,
    // based on the wallet data structure you create and the IERC20 interface methods. Namely, you should transfer
    // tokens from the account of the trader on that token to this smart contract, and credit them appropriately
    function deposit(uint256 amount, bytes32 ticker) external tokenExists(ticker) {
        IERC20(tokens[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount);
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].add(amount);
    }

    // todo: implement withdraw, which should do the opposite of deposit. The trader should not be able to withdraw more than
    // they have in the exchange.
    function withdraw(uint256 amount, bytes32 ticker) external tokenExists(ticker) {
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].sub(amount);
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }

    // todo: implement makeLimitOrder, which creates a limit order based on the parameters provided. This method should only be
    // used when the token desired exists and is not pine. This method should not execute if the trader's token or pine balances
    // are too low, depending on side. This order should be saved in the orderBook
    //
    // todo: implement a sorting algorithm for limit orders, based on best prices for market orders having the highest priority.
    // i.e., a limit buy order with a high price should have a higher priority in the orderbook.
    function makeLimitOrder(
        bytes32 ticker,
        uint256 amount,
        uint256 price,
        Side side
    ) external tokenExists(ticker) notPine(ticker) {
        // check if trader has enough tokens
        if (side == Side.BUY) {
            traderBalances[msg.sender][PIN].sub(price);
        } else {
            traderBalances[msg.sender][ticker].sub(amount);
        }

        // create the order
        lastOrderId++;
        Order memory order = Order(lastOrderId, msg.sender, side, ticker, amount, 0, price, now);
        orderBookIds.push(lastOrderId);
        orderBook[lastOrderId] = order;

        sort(); // sort the orderbook

        // fire the event
        emit NewOrder(lastOrderId, ticker, msg.sender, amount, price, now);
    }

    // todo: implement deleteLimitOrder, which will delete a limit order from the orderBook as long as the same trader is deleting
    // it.
    function deleteLimitOrder(
        uint256 id,
        bytes32 ticker,
        Side side
    ) external tokenExists(ticker) returns (bool) {
        // check if the trader is deleting the order they created and other info is correct
        if (
            orderBook[id].trader == msg.sender &&
            orderBook[id].side == side &&
            orderBook[id].ticker == ticker
        ) {
            orderBookIds[id] = orderBookIds[orderBookIds.length - 1]; // move the last order to the deleted order's position
            orderBookIds.pop(); // delete the last order (pop goes the weasel)
            delete orderBook[id];
            sort(); // sort the orderbook

            // fire the event
            emit DeleteOrder(id, ticker, msg.sender, now);
            return true;
        }
        return false;
    }

    // todo: implement makeMarketOrder, which will execute a market order on the current orderbook. The market order need not be
    // added to the book explicitly, since it should execute against a limit order immediately. Make sure you are getting rid of
    // completely filled limit orders!
    function makeMarketOrder(
        bytes32 ticker,
        uint256 amount,
        Side side
    ) external tokenExists(ticker) notPine(ticker) {
        uint256 amountLeft = amount;

        if (side == Side.BUY) {
            // if the trader is buying tokens from the exchange

            while (amountLeft > 0) {
                // buy tokens from the market until the market order is satisified

                Order memory order = getBestOrder(ticker, Side.SELL); // get the best order (by price) for the token on the market
                uint256 amountToBuy = Math.min(amountLeft, order.amount); // get the amount of tokens to buy
                uint256 total = order.price.mul(amountToBuy); // get the total price of the order

                // charge/pay the limit order trader
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].sub(
                    amountToBuy
                );
                traderBalances[msg.sender][PIN] = traderBalances[msg.sender][PIN].add(total);

                // charge/pay the market order trader
                traderBalances[msg.sender][PIN] = traderBalances[msg.sender][PIN].sub(total);
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].add(
                    amountToBuy
                );

                amountLeft = amountLeft.sub(amountToBuy);
                order.filled = order.filled.add(amountToBuy);

                checkIfOrderFilled(order); // check if the order is completely filled, delete it if it is

                // Emit a NewTrade event
                emit NewTrade(
                    nextTradeId++,
                    order.id,
                    ticker,
                    order.trader,
                    msg.sender,
                    amountToBuy,
                    order.price,
                    now
                );
            }
        } else {
            // if the trader is selling tokens to the exchange

            while (amountLeft > 0) {
                // sell tokens to the market until the market order is satisfied

                Order memory order = getBestOrder(ticker, Side.BUY); // get the best order (by price) for the token on the market
                uint256 amountToSell = Math.min(amountLeft, order.amount); // get the amount of tokens to sell
                uint256 total = order.price.mul(amountToSell); // get the total price of the order

                // charge/pay the limit order trader
                traderBalances[msg.sender][PIN] = traderBalances[msg.sender][PIN].sub(total);
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].add(
                    amountToSell
                );

                // charge/pay the market order trader
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].sub(
                    amountToSell
                );
                traderBalances[msg.sender][PIN] = traderBalances[msg.sender][PIN].add(total);

                amountLeft = amountLeft.sub(amountToSell);
                order.filled = order.filled.add(amountToSell);

                checkIfOrderFilled(order); // check if the order is completely filled, delete it if it is

                // Emit a NewTrade event
                emit NewTrade(
                    nextTradeId++,
                    order.id,
                    ticker,
                    order.trader,
                    msg.sender,
                    amountToSell,
                    order.price,
                    now
                );
            }
        }
    }

    function getBestOrder(bytes32 ticker, Side side) internal view returns (Order memory) {
        for (uint256 i = 0; i < orderBookIds.length; i++) {
            // for each order in the orderbook
            Order memory order = orderBook[orderBookIds[i]];
            if (order.side == side && order.ticker == ticker) {
                return order;
            }
        }
        require(false); // no order was found
    }

    // check if the order is filled, if so delete the order from the orderbook
    function checkIfOrderFilled(Order memory order) internal returns (bool) {
        if (order.filled >= order.amount) {
            // if the order is completely filled, delete it
            orderBookIds[order.id] = orderBookIds[orderBookIds.length - 1];
            orderBookIds.pop();
            delete orderBook[order.id];
            sort(); // sort the orderbook

            // emit the event
            emit FilledLimitOrder(order.id, order.ticker, order.trader, now);
            return true;
        } else {
            // if the order is not completely filled, update it
            orderBook[order.id] = order;
            return false;
        }
    }

    // modifiers for methods as detailed in handout:

    // tokenExists is a modifier for methods that take in a ticker. It should return true if the token exists, and false otherwise.
    modifier tokenExists(bytes32 ticker) {
        require(tokens[ticker].ticker == ticker);
        _;
    }

    // notPine is a modifier for methods that take in a ticker. It should return true if the token is not pine, and false otherwise.
    modifier notPine(bytes32 ticker) {
        require(ticker != PIN);
        _;
    }

    // Quick Sort the orderBookIds array by price
    function quickSort() internal {
        uint256 length = orderBookIds.length;
        quickSortHelper(0, length - 1); // start recursion
    }

    function quickSortHelper(uint256 start, uint256 end) internal {
        if (start < end) {
            // if there is more than one element
            uint256 pivot = partition(start, end); // partition the array
            quickSortHelper(start, pivot - 1); // recursively sort the left side
            quickSortHelper(pivot + 1, end); // recursively sort the right side
        }
    }

    function partition(uint256 start, uint256 end) internal returns (uint256) {
        uint256 pivot = orderBookIds[start];
        uint256 i = start;
        uint256 j = end;
        while (true) {
            while (orderBook[orderBookIds[++i]].price < orderBook[orderBookIds[pivot]].price) {
                // while the left side is smaller than the pivot
                if (i == end) {
                    break;
                }
            }
            while (orderBook[orderBookIds[--j]].price > orderBook[orderBookIds[pivot]].price) {
                // while the right side is larger than the pivot
                if (j == start) {
                    break;
                }
            }
            if (i >= j) {
                break;
            }
            uint256 temp = orderBookIds[i];
            orderBookIds[i] = orderBookIds[j];
            orderBookIds[j] = temp;
        }
        uint256 temp = orderBookIds[i];
        orderBookIds[i] = orderBookIds[end];
        orderBookIds[end] = temp;
        return i;
    }

    // Insertion Sort the orderBookIds array by price
    function insertionSort() internal {
        uint256 length = orderBookIds.length;
        for (uint256 i = 1; i < length; i++) {
            uint256 j = i;
            while (
                j > 0 && orderBook[orderBookIds[j - 1]].price > orderBook[orderBookIds[j]].price
            ) {
                uint256 temp = orderBookIds[j];
                orderBookIds[j] = orderBookIds[j - 1];
                orderBookIds[j - 1] = temp;
                j--;
            }
        }
    }

    function sort() internal {
        // quickSort();
        insertionSort();
    }
}
