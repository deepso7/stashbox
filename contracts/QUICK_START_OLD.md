# Stashbox Quick Start Guide

## 5-Minute Setup

### 1. Install & Build
```bash
cd contracts
forge install
forge build
```

### 2. Run Tests
```bash
# All tests
forge test

# With gas report
forge test --gas-report

# Verbose output
forge test -vv
```

### 3. Deploy Locally
```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
forge script script/DeployJarManager.s.sol:DeployJarManagerLocal \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### 4. Interact with Contract

```bash
# Set contract address from deployment
CONTRACT=<deployed_address>

# Create a jar
cast send $CONTRACT "createJar(string,uint256)" "PS5 Fund" 500000000 \
  --rpc-url http://localhost:8545 \
  --private-key <your_private_key>

# Check your jars
cast call $CONTRACT "getUserJarIds(address)" <your_address> \
  --rpc-url http://localhost:8545
```

## Common Commands

### Testing
```bash
forge test --match-test test_CreateJar        # Single test
forge test --match-contract JarManagerTest    # Test suite
forge test --gas-report                       # With gas
forge snapshot                                # Gas snapshot
forge coverage                                # Coverage report
```

### Building
```bash
forge build                 # Build all
forge build --force         # Force rebuild
forge clean                 # Clean artifacts
```

### Deployment
```bash
# Local
forge script script/DeployJarManager.s.sol:DeployJarManagerLocal --broadcast

# Testnet (set env vars first)
export PRIVATE_KEY=0x...
export SEPOLIA_RPC_URL=https://...
forge script script/DeployJarManager.s.sol:DeployJarManager \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

## Key Files

- `src/JarManager.sol` - Main contract
- `test/JarManager.t.sol` - Unit tests
- `test/JarManagerFuzz.t.sol` - Fuzz tests
- `test/JarManagerInvariant.t.sol` - Invariant tests
- `script/DeployJarManager.s.sol` - Deployment
- `README.md` - Full documentation
- `GAS_OPTIMIZATION_REPORT.md` - Gas analysis

## Need Help?

1. Check `README.md` for detailed docs
2. See `IMPLEMENTATION_SUMMARY.md` for architecture
3. Read `GAS_OPTIMIZATION_REPORT.md` for gas details
4. Run `forge test -vvv` for verbose test output

Happy building! 🚀
