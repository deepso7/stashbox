# Critical Fixes Applied - Uniswap V4 Integration

## Overview
Three critical bugs were identified and fixed in the Uniswap V4 integration that would have caused the contract to revert on Base Sepolia.

---

## ❌ Bug #1: Flash Accounting Signs Backwards

### The Problem
**Location**: `_settleDeltas()` function

The original code incorrectly interpreted Uniswap V4's flash accounting deltas:
```solidity
// WRONG - This is backwards!
if (delta0 > 0) {
    // We owe tokens to the pool
    DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(delta0));
    POOL_MANAGER.settle();
} else if (delta0 < 0) {
    // Pool owes us tokens
    POOL_MANAGER.take(poolKey.currency0, address(this), uint128(-delta0));
}
```

### Why It's Wrong
In Uniswap V4's flash accounting system:
- **NEGATIVE delta** = You OWE tokens to the pool (must settle/pay)
- **POSITIVE delta** = The pool OWES you tokens (can take)

This is the opposite of what might be intuitive! The signs represent debts, not balances.

### The Fix
```solidity
// CORRECT - Signs are now right
if (delta0 < 0) {
    // We owe tokens to the pool (negative = debt)
    POOL_MANAGER.sync(poolKey.currency0);
    DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(-delta0));
    POOL_MANAGER.settle();
} else if (delta0 > 0) {
    // Pool owes us tokens (positive = credit)
    POOL_MANAGER.take(poolKey.currency0, address(this), uint128(delta0));
}
```

### Impact
**Without this fix**: Every single deposit/withdrawal would have reverted with "CurrencyNotSettled" because we would try to:
- Take tokens when we should pay (on deposits)
- Pay tokens when we should take (on withdrawals)

---

## ❌ Bug #2: Incorrect `sync()` Usage

### The Problem
**Location**: `_settleDeltas()` function

The code was calling `POOL_MANAGER.sync()` but with incorrect logic and placement.

### Why It's Required
The V4 PoolManager needs to know which currency you're about to settle:
1. **Call `sync(currency)`** - Tells PoolManager which currency to expect
2. **Transfer tokens** - Send tokens to PoolManager
3. **Call `settle()`** - Finalizes the settlement

### The Fix
Proper 3-step settlement process:
```solidity
if (delta0 < 0) {
    // Step 1: Sync to identify the currency
    POOL_MANAGER.sync(poolKey.currency0);
    
    // Step 2: Transfer the tokens
    DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(-delta0));
    
    // Step 3: Settle to finalize
    POOL_MANAGER.settle();
}
```

### Impact
**Without this fix**: Settlement would fail because PoolManager wouldn't know which currency's balance to check.

---

## ❌ Bug #3: Withdrawal Math Loses User Yield

### The Problem
**Location**: `withdraw()` function

When users withdrew principal, the code would save their yield to a snapshot, but the calculation was wrong:

```solidity
// WRONG - Saves yield AFTER modifying shares
jar.shares -= sharesToBurn;
jar.principalDeposited -= amount;
jar.yieldDebt = (jar.shares * accYieldPerShare) / PRECISION; // Wrong!
```

This would reset `yieldDebt` without properly accounting for the yield that should be preserved.

### Why It's Wrong
The yield preservation logic had a subtle bug:
1. User has 100 shares with 10 tokens of yield
2. User withdraws 50% of principal
3. We burn 50 shares
4. We calculate new `yieldDebt = (50 * accYieldPerShare) / PRECISION`
5. **Problem**: The old yield snapshot is overridden, and yield is lost

### The Fix
Properly calculate and preserve the proportional yield:

```solidity
// Get current pending yield BEFORE we modify anything
uint256 currentYield = _pendingYield(jar);

// Calculate shares to burn
uint256 sharesToBurn = (amount * jar.shares) / jar.principalDeposited;

// Calculate how much yield to preserve
// If withdrawing X% of principal, also "withdraw" X% of yield
// The remaining (100-X)% of yield should be preserved
uint256 yieldWithdrawn = (currentYield * amount) / jar.principalDeposited;
uint256 yieldRemaining = currentYield - yieldWithdrawn;

// Update jar state
jar.shares -= sharesToBurn;
jar.principalDeposited -= amount;

// Save the REMAINING yield (this preserves it for the user)
jar.pendingYieldSnapshot = yieldRemaining;

// Reset debt for new share amount
jar.yieldDebt = (jar.shares * accYieldPerShare) / PRECISION;
```

### Example
**Before fix:**
- User has 1000 principal + 100 yield
- Withdraws 500 principal
- Expected: Should keep 50 yield
- Actual: Lost all 100 yield ❌

**After fix:**
- User has 1000 principal + 100 yield
- Withdraws 500 principal (50%)
- Keeps 50 yield (50% of 100) ✅

### Impact
**Without this fix**: Users would lose all their accumulated yield whenever they made a partial withdrawal. This is a **critical financial bug** that would result in loss of user funds.

---

## Testing the Fixes

### Unit Tests
All existing tests continue to pass:
```bash
forge test --match-contract JarManagerTest
```

### Yield Preservation Test
The yield tests now correctly verify that:
1. Yield accumulates properly
2. Partial withdrawals preserve proportional yield
3. Multiple deposit/withdrawal cycles maintain yield accuracy

### Fork Tests
Can now test against real V4 contracts:
```bash
forge test --match-contract JarManagerForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vvv
```

---

## Verification Checklist

### ✅ Flash Accounting
- [x] Negative delta = we owe (must settle)
- [x] Positive delta = pool owes us (can take)
- [x] Correct amount conversion (use absolute value when owing)

### ✅ Settlement Flow
- [x] Call `sync(currency)` first
- [x] Transfer tokens to PoolManager
- [x] Call `settle()` to finalize
- [x] Handle both currency0 and currency1

### ✅ Yield Preservation
- [x] Calculate current yield before modifications
- [x] Calculate proportional yield to preserve
- [x] Save remaining yield to snapshot
- [x] Properly reset yieldDebt for new share amount

---

## Additional Notes

### Why These Bugs Were Easy to Miss

1. **Flash Accounting**: The negative/positive convention is counterintuitive and opposite to typical balance accounting

2. **sync() Usage**: The function exists but its requirement isn't immediately obvious from just reading the interface

3. **Yield Math**: The bug only manifests with partial withdrawals after yield has accumulated - easy to miss in simple tests

### Prevention Going Forward

1. **Always test with real V4 contracts** on a fork
2. **Test edge cases**: Partial withdrawals after yield accumulation
3. **Reference official V4 examples** for settlement patterns
4. **Add explicit comments** about flash accounting conventions

---

## Resources

- [Uniswap V4 Flash Accounting](https://docs.uniswap.org/contracts/v4/concepts/flash-accounting)
- [Settlement Pattern Examples](https://github.com/Uniswap/v4-core/tree/main/test)
- [V4 Core Documentation](https://docs.uniswap.org/contracts/v4/overview)

---

**Status**: ✅ All critical bugs fixed and verified
**Last Updated**: Nov 23, 2024
**Reviewed By**: Code audit
