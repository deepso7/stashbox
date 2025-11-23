# Quick Start - Deploy Stashbox to Base Sepolia

## Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Wallet with Base Sepolia ETH
- RPC URL for Base Sepolia (default: https://sepolia.base.org)

## Step 1: Environment Setup

Create `.env` file in `contracts` directory:
```bash
cd contracts
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=your_basescan_api_key_optional
EOF
```

Load environment:
```bash
source .env
```

## Step 2: Get Testnet Funds

1. **Get Base Sepolia ETH**
   - Visit: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
   - Or bridge from Sepolia: https://bridge.base.org/

2. **Get Test USDC** (if available)
   - Check Uniswap V4 Discord for test token faucets
   - Or deploy your own test ERC20

## Step 3: Update Token Addresses

Edit `script/DeployBaseSepolia.s.sol`:
```solidity
// Update these with actual Base Sepolia addresses
address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Verify this
address constant DAI = 0x7683022d84F726a96c4A6611cD31DBf5409c0Ac9;  // Verify this
```

## Step 4: Build Contracts

```bash
forge build
```

Expected output:
```
Compiling...
Compiler run successful!
```

## Step 5: Run Tests (Optional)

```bash
# Unit tests (fast)
forge test

# Fork tests (requires RPC)
forge test --match-contract JarManagerForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vvv
```

## Step 6: Deploy

```bash
forge script script/DeployBaseSepolia.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Note:** Remove `--verify` if you don't have a BaseScan API key.

## Step 7: Save Contract Address

The script will output:
```
JarManager deployed at: 0x...
```

Save this address - you'll need it for the frontend!

## Next Steps

✅ Contract deployed
✅ Tests passing  
⏳ Frontend integration
⏳ End-to-end testing

## Resources

- **Base Sepolia Explorer**: https://sepolia.basescan.org
- **README_DEPLOYMENT.md** - Detailed deployment guide
- **UNISWAP_V4_INTEGRATION.md** - Technical details
- **INTEGRATION_SUMMARY.md** - Overview of changes
