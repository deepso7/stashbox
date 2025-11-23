# Stashbox - Smart Contract Savings Jars

A gas-efficient savings jar system built on Ethereum with automatic yield generation through Uniswap V4.

## Overview

Stashbox allows users to create individual savings jars (like "PS5 Fund", "Vacation Savings") that automatically earn yield while maintaining separate goals and tracking. All funds are pooled into a single Uniswap V4 liquidity position for maximum capital efficiency and gas savings.

## Features

- ✅ Create unlimited named savings jars with target amounts
- ✅ Deposit stablecoins (USDC) into individual jars
- ✅ Automatic yield generation through Uniswap V4 liquidity provision
- ✅ Proportional share accounting for fair yield distribution
- ✅ Withdraw principal or claim yield separately
- ✅ Emergency withdraw functionality
- ✅ Gas-optimized through shared liquidity pool
- ✅ Comprehensive test suite (unit, fuzz, invariant)
- ✅ Full NatSpec documentation

## Quick Start

### Installation

```bash
# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test suite
forge test --match-contract JarManagerTest

# Run fuzz tests
forge test --match-contract JarManagerFuzzTest

# Run invariant tests
forge test --match-contract JarManagerInvariantTest
```

### Deployment

```bash
# Local deployment
forge script script/DeployJarManager.s.sol:DeployJarManagerLocal --rpc-url http://localhost:8545 --broadcast

# Testnet deployment
forge script script/DeployJarManager.s.sol:DeployJarManager --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Architecture

### Core Contracts

- **JarManager.sol** (src/contracts/JarManager.sol:1): Main contract handling jar creation, deposits, withdrawals, and Uniswap V4 integration

### Key Design Decisions

1. **Shared Liquidity Pool**: All user funds go into a single Uniswap V4 position, reducing gas costs by 30-40%
2. **Proportional Shares**: Internal accounting tracks each jar's share of the total pool
3. **Lazy Yield Updates**: Yield is calculated on-demand to save gas
4. **Tight Range Position**: Stablecoin pair (USDC/DAI) with minimal impermanent loss
5. **Reentrancy Protection**: All state-changing functions are protected
6. **Custom Errors**: Gas-efficient error handling

## Usage Examples

### Create a Jar

```solidity
// Create a savings jar for a PS5
uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6); // 500 USDC target
```

### Deposit Funds

```solidity
// Approve USDC first
usdc.approve(address(jarManager), amount);

// Deposit to jar
jarManager.deposit(jarId, 100 * 1e6); // Deposit 100 USDC
```

### Withdraw Principal

```solidity
// Withdraw 50 USDC from jar
jarManager.withdraw(jarId, 50 * 1e6);
```

### Claim Yield

```solidity
// Claim all accumulated yield
jarManager.claimYield(jarId);
```

### Check Jar Status

```solidity
// Get jar details
JarManager.Jar memory jar = jarManager.getJar(msg.sender, jarId);

// Calculate current yield (including uncollected)
uint256 currentYield = jarManager.calculateCurrentYield(msg.sender, jarId);
```

## Gas Optimization

See [GAS_OPTIMIZATION_REPORT.md](./GAS_OPTIMIZATION_REPORT.md) for detailed analysis.

**Key Metrics:**
- Create Jar: ~65,000 gas
- Deposit: ~85,000 gas
- Withdraw: ~90,000 gas
- **30-40% savings vs. individual positions**

## Testing Strategy

### Unit Tests
- Jar creation scenarios
- Deposit/withdrawal flows
- Access control
- Error conditions

### Fuzz Tests (256 runs)
- Random deposit amounts
- Multiple actors
- Share accounting edge cases
- Emergency withdrawals

### Invariant Tests (128 runs, depth 15)
- Total shares = sum of jar shares
- Total principal = sum of jar principals
- Contract balance ≥ total obligations
- Yield distribution proportionality

## Security

### Implemented Protections

1. **Reentrancy Guards**: All state-changing functions use `nonReentrant` modifier
2. **Access Control**: Only jar owners can withdraw from their jars
3. **CEI Pattern**: Checks-Effects-Interactions pattern followed throughout
4. **Input Validation**: All user inputs are validated
5. **Custom Errors**: Gas-efficient error handling

### Audit Status

⚠️ **Not yet audited** - DO NOT use in production without professional security audit

## Project Structure

```
contracts/
├── src/
│   └── JarManager.sol           # Main contract
├── test/
│   ├── JarManager.t.sol         # Unit tests
│   ├── JarManagerFuzz.t.sol     # Fuzz tests
│   ├── JarManagerInvariant.t.sol # Invariant tests
│   ├── handlers/
│   │   └── JarManagerHandler.sol # Invariant test handler
│   └── mocks/
│       ├── MockERC20.sol
│       └── MockPoolManager.sol
├── script/
│   └── DeployJarManager.s.sol   # Deployment script
├── foundry.toml                 # Foundry config
├── GAS_OPTIMIZATION_REPORT.md
└── README.md                    # This file
```

## Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

MIT License

---

**Built with Foundry** 🛠️
