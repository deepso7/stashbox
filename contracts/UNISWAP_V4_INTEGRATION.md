# Uniswap V4 Integration Guide

## Overview
This document explains how the JarManager contract integrates with Uniswap V4 on Base Sepolia.

## Architecture

### Core Components

#### 1. JarManager Contract
- Main contract managing user jars and savings
- Implements `IUnlockCallback` for V4 integration
- Handles liquidity operations through the unlock pattern

#### 2. Unlock Callback Pattern
Uniswap V4 uses an "unlock" pattern for all operations:
```solidity
// User calls: deposit() -> _addLiquidity()
function _addLiquidity(amount) {
    // Triggers unlock on PoolManager
    POOL_MANAGER.unlock(abi.encode(callbackData));
}

// PoolManager calls back:
function unlockCallback(bytes calldata data) {
    // Actually execute the liquidity modification
    POOL_MANAGER.modifyLiquidity(poolKey, params, "");
    // Settle the token deltas
    _settleDeltas(delta, isAdd);
}
```

#### 3. Settlement Flow
When modifying liquidity, tokens need to be settled:
- **Adding liquidity**: Transfer tokens to PoolManager, call `settle()`
- **Removing liquidity**: Call `take()` to receive tokens from PoolManager

## Base Sepolia Deployment

### Contract Addresses
```solidity
PoolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
PositionManager: 0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80
SwapRouter: 0x8b5bcc363dde2614281ad875bad385e0a785d3b9
Quoter: 0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba
```

### Pool Configuration
```solidity
PoolKey({
    currency0: USDC,
    currency1: DAI,
    fee: 500,         // 0.05% fee tier
    tickSpacing: 10,
    hooks: address(0) // No hooks
})
```

### Liquidity Position
```solidity
Position({
    tickLower: -60,  // Tight range for stablecoins
    tickUpper: 60,
    liquidity: uint128
})
```

## Key Functions

### Adding Liquidity
```solidity
function _addLiquidity(uint256 amount) internal {
    // 1. Approve tokens
    DEPOSIT_TOKEN.approve(address(POOL_MANAGER), amount);
    
    // 2. Prepare params
    ModifyLiquidityParams memory params = ModifyLiquidityParams({
        tickLower: position.tickLower,
        tickUpper: position.tickUpper,
        liquidityDelta: int256(uint256(amount)),
        salt: bytes32(0)
    });
    
    // 3. Call via unlock
    POOL_MANAGER.unlock(abi.encode(CallbackData({
        params: params,
        isAdd: true
    })));
    
    // 4. Update state
    position.liquidity += amount;
}
```

### Removing Liquidity
```solidity
function _removeLiquidity(uint256 amount) internal {
    // Similar to add, but with negative liquidityDelta
    ModifyLiquidityParams memory params = ModifyLiquidityParams({
        tickLower: position.tickLower,
        tickUpper: position.tickUpper,
        liquidityDelta: -int256(uint256(amount)),
        salt: bytes32(0)
    });
    
    POOL_MANAGER.unlock(abi.encode(CallbackData({
        params: params,
        isAdd: false
    })));
}
```

### Unlock Callback
```solidity
function unlockCallback(bytes calldata data) external override {
    require(msg.sender == address(POOL_MANAGER), "Only PoolManager");
    
    CallbackData memory callbackData = abi.decode(data, (CallbackData));
    
    // Execute liquidity modification
    (BalanceDelta delta,) = POOL_MANAGER.modifyLiquidity(
        poolKey,
        callbackData.params,
        ""
    );

    // Settle the balance changes
    _settleDeltas(delta, callbackData.isAdd);
    
    return abi.encode(delta);
}
```

### Settlement
```solidity
function _settleDeltas(BalanceDelta delta, bool isAdd) internal {
    int128 delta0 = delta.amount0();
    int128 delta1 = delta.amount1();

    // Handle currency0
    if (delta0 > 0) {
        // We owe tokens
        POOL_MANAGER.sync(poolKey.currency0);
        DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(delta0));
        POOL_MANAGER.settle();
    } else if (delta0 < 0) {
        // Pool owes us tokens
        POOL_MANAGER.take(poolKey.currency0, address(this), uint128(-delta0));
    }
    
    // Handle currency1 similarly...
}
```

## Fee Collection

### How Fees Work in V4
- Fees accrue automatically to liquidity positions
- Unlike V3, fees are not automatically collected
- Our implementation tracks fees via balance changes

### Implementation
```solidity
function _collectFees() internal returns (uint256 feesCollected) {
    // Check for excess balance (represents uncollected fees)
    uint256 currentBalance = DEPOSIT_TOKEN.balanceOf(address(this));
    uint256 expectedBalance = totalPrincipal + totalYieldCollected;
    
    if (currentBalance > expectedBalance) {
        feesCollected = currentBalance - expectedBalance;
    }
    
    return feesCollected;
}
```

## Testing Strategy

### 1. Unit Tests (Mock)
Use MockPoolManager to test logic without V4 dependency:
```bash
forge test --match-contract JarManagerTest
```

### 2. Fork Tests (Real V4)
Test against actual V4 contracts on Base Sepolia:
```bash
forge test --match-contract JarManagerForkTest \
  --fork-url https://sepolia.base.org -vvv
```

### 3. Integration Tests
Deploy to testnet and test end-to-end:
```bash
forge script script/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

## Common Issues & Solutions

### Issue: "CurrencyNotSettled" Error
**Cause**: Tokens not properly settled after modifying liquidity
**Solution**: Ensure `_settleDeltas` handles all cases (positive and negative deltas)

### Issue: "PoolNotInitialized" Error
**Cause**: Pool doesn't exist or hasn't been initialized
**Solution**: Initialize pool first:
```solidity
poolManager.initialize(poolKey, sqrtPriceX96);
```

### Issue: "Insufficient Approval" Error
**Cause**: PoolManager not approved to spend tokens
**Solution**: Call approve before adding liquidity

### Issue: Wrong Delta Amounts
**Cause**: Incorrect liquidity calculation for single-sided deposits
**Solution**: For stablecoin pairs in tight ranges, liquidity ≈ token amount

## Gas Optimization

### Current Gas Usage
- Create Jar: ~155k gas
- Deposit: ~195k gas
- Withdraw: ~175k gas
- Claim Yield: ~95k gas

### Optimization Opportunities
1. Batch operations (multiple jars)
2. Use transient storage (V4 feature)
3. Optimize callback data encoding
4. Consider using ERC6909 for internal accounting

## Security Considerations

### Reentrancy Protection
- All external functions use `nonReentrant`
- Callbacks only callable by PoolManager

### Access Control
- Admin functions protected by `onlyOwner`
- Users can only access their own jars

### Slippage Protection
- Could add min/max amount checks
- Consider deadline parameters

### Precision Loss
- Uses 1e18 precision for yield calculations
- Test with various token decimals

## Upgradeability

The contract is **not upgradeable** by design:
- Simpler, more secure
- Users can trust immutability
- Deploy new version if needed

## Next Steps

1. ✅ Deploy to Base Sepolia
2. ✅ Test with real tokens
3. ⏳ Monitor for edge cases
4. ⏳ Gather user feedback
5. ⏳ Consider mainnet deployment

## Resources

- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)
- [V4 Core Repository](https://github.com/Uniswap/v4-core)
- [Base Sepolia Explorer](https://sepolia.basescan.org)
- [Unlock Callback Pattern](https://docs.uniswap.org/contracts/v4/guides/unlock-callback)
