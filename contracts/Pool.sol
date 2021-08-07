pragma solidity 0.5.3;

import './Exc.sol';
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/math/SafeMath.sol";
import '../contracts/libraries/math/SafeMath.sol';

contract Pool {
    
    // SafeMath    
    using SafeMath for uint;
    using SafeMath for uint256;

    /// @notice some parameters for the pool to function correctly, feel free to add more as needed
    address private tokenP; // pine address
    address private token1; // other token address
    address private dex; // exchange address
    bytes32 private tokenPT; // pine ticker
    bytes32 private token1T; // other token ticker
    
    // Pool Wallet --> Trader balances by token that are in the pool
    mapping(address => mapping(bytes32 => uint)) public poolBalances;

    // todo: fill in the initialize method, which should simply set the parameters of the contract correctly. To be called once
    // upon deployment by the factory.
    function initialize(address _token0, address _token1, address _dex, uint whichP, bytes32 _tickerQ, bytes32 _tickerT)
    external { // hypothetically done
        
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
    function deposit(uint tokenAmount, uint pineAmount) external {
        // deposit Pine from msg.sender to the pool
        IERC20(tokenP).transferFrom(msg.sender, dex, pineAmount);
        poolBalances[msg.sender][tokenPT] = poolBalances[msg.sender][tokenPT].add(pineAmount);
        // deposit token1 from msg.sender to the pool
        IERC20(token1).transferFrom(msg.sender, dex, tokenAmount);
        poolBalances[msg.sender][token1T] = poolBalances[msg.sender][token1T].add(tokenAmount);
    }

    function withdraw(uint tokenAmount, uint pineAmount) external {
        // withdraw Pine from the pool to msg.sender
        poolBalances[msg.sender][tokenPT] = poolBalances[msg.sender][tokenPT].sub(pineAmount);
        IERC20(tokenP).transferFrom(dex, msg.sender, pineAmount);
        // withdraw token1 from the pool to msg.sender
        poolBalances[msg.sender][token1T] = poolBalances[msg.sender][token1T].sub(tokenAmount);
        IERC20(token1).transferFrom(dex, msg.sender, tokenAmount);
    }

    function testing(uint testMe) public pure returns (uint) {
        if (testMe == 1) {
            return 5;
        } else {
            return 3;
        }
    }
}