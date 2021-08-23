# Redwood Exchange
A set of smart contracts forming an exchange and liquidity pool for trading coins on the Ethereum network. Written in Solidity 0.5.3.

## Contracts
 - [**Exc**](contracts/Exc.sol): The exchange that allows traders to store their balances and trade between different token types. Trader balances are stored so they can deposit or withdraw at any time. Limit orders can be created to buy or sell a particular token at a set price. Market orders can be placed to fill a previously placed limit order. Transactions are always used with "PINE" (ticker PIN) as the currency, but this could be changed to USDT, USDC, or anything else.
 - [**Factory**](contracts/Factory.sol): The factory that creates liquidity pools for each ticker that will be traded on the exchange.
 - [**Pool**](contracts/Pool.sol): The liquidity pool that is used to automatically create limit orders on the exchange with a particular token based on the current supply/demand. Traders are incentivized to deposit their tokens and pine into the liquidity pool, which will automatically create limit orders based on the ratio of token to pine. This allows market orders to be made and fulfilled instantly, assuming the pool has enough coins deposited.

## ⚠ Not intended for production use!
This project is not actively maintained and may contain security vulnerabilities.
