// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockPoolManager
/// @notice Simplified Mock Uniswap V4 Pool Manager for testing
/// @dev This is a minimal mock that doesn't require full V4 integration
contract MockPoolManager {
    // Simple mock implementation
    uint256 public totalLiquidity;
    uint256 public totalFees;

    function addLiquidity(uint256 amount) external {
        totalLiquidity += amount;
    }

    function removeLiquidity(uint256 amount) external {
        require(totalLiquidity >= amount, "Insufficient liquidity");
        totalLiquidity -= amount;
    }

    function addFees(uint256 amount) external {
        totalFees += amount;
    }

    function collectFees() external returns (uint256) {
        uint256 amount = totalFees;
        totalFees = 0;
        return amount;
    }
}
