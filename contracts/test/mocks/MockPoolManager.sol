// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @title MockPoolManager
/// @notice Mock implementation of Uniswap V4 Pool Manager for testing
/// @dev Simulates the unlock callback pattern and flash accounting
contract MockPoolManager {
    uint256 public totalLiquidity;
    uint256 public totalFees;
    
    // Track synced currency for settlement
    Currency private syncedCurrency;
    
    /// @notice Unlock function that calls back to the caller
    function unlock(bytes calldata data) external returns (bytes memory) {
        // Call the unlock callback on the caller
        return IUnlockCallback(msg.sender).unlockCallback(data);
    }
    
    /// @notice Modify liquidity in the pool
    /// @dev Simulates V4's flash accounting with proper delta signs
    function modifyLiquidity(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        bytes calldata hookData
    ) external returns (BalanceDelta delta, BalanceDelta feeDelta) {
        if (params.liquidityDelta > 0) {
            // Adding liquidity
            totalLiquidity += uint256(params.liquidityDelta);
            
            // In V4 flash accounting:
            // NEGATIVE delta = caller owes tokens to pool
            // For adding liquidity, caller must pay tokens
            delta = toBalanceDelta(
                -int128(int256(params.liquidityDelta)),  // currency0: caller owes
                0                                         // currency1: no change for single-sided
            );
        } else if (params.liquidityDelta < 0) {
            // Removing liquidity
            uint256 liquidityToRemove = uint256(-params.liquidityDelta);
            require(totalLiquidity >= liquidityToRemove, "Insufficient liquidity");
            totalLiquidity -= liquidityToRemove;
            
            // In V4 flash accounting:
            // POSITIVE delta = pool owes tokens to caller
            // For removing liquidity, pool pays tokens back
            delta = toBalanceDelta(
                int128(int256(liquidityToRemove)),  // currency0: pool owes caller
                0                                    // currency1: no change for single-sided
            );
        }
        
        feeDelta = toBalanceDelta(0, 0);
        return (delta, feeDelta);
    }
    
    /// @notice Sync currency for settlement
    function sync(Currency currency) external {
        syncedCurrency = currency;
    }
    
    /// @notice Settle outstanding debts
    function settle() external payable returns (uint256) {
        // Mock: Just acknowledge the settlement
        // In real V4, this would check balances and update deltas
        syncedCurrency = Currency.wrap(address(0)); // Reset
        return 0;
    }
    
    /// @notice Take tokens from the pool
    function take(Currency currency, address to, uint256 amount) external {
        // Mock: Transfer tokens from this contract to the recipient
        // In real V4, this would transfer from the PoolManager's reserves
        address token = Currency.unwrap(currency);
        if (token != address(0)) {
            // Transfer ERC20 tokens
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", to, amount)
            );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
        }
        // For native ETH (address(0)), would send ETH - not needed for our tests
    }
    
    /// @notice Add fees to simulate yield
    function addFees(uint256 amount) external {
        totalFees += amount;
    }
    
    /// @notice Collect accumulated fees
    function collectFees() external returns (uint256) {
        uint256 amount = totalFees;
        totalFees = 0;
        return amount;
    }
}
