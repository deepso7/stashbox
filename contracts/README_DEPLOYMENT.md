# Stashbox Deployment Guide - Base Sepolia

## Overview
This guide explains how to deploy the JarManager contract to Base Sepolia testnet using real Uniswap V4 contracts.

## Base Sepolia Contract Addresses

### Uniswap V4 Core Contracts
- **PoolManager**: `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`
- **Universal Router**: `0x492e6456d9528771018deb9e87ef7750ef184104`
- **PositionManager**: `0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80`
- **StateView**: `0x571291b572ed32ce6751a2cb2486ebee8defb9b4`
- **Quoter**: `0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba`
- **PoolSwapTest**: `0x8b5bcc363dde2614281ad875bad385e0a785d3b9`
- **PoolModifyLiquidityTest**: `0x37429cd17cb1454c34e7f50b09725202fd533039`
- **Permit2**: `0x000000000022D473030F116dDEE9F6B43aC78BA3`

### Chain Information
- **Network**: Base Sepolia
- **Chain ID**: 84532
- **RPC URL**: https://sepolia.base.org
- **Explorer**: https://sepolia.basescan.org

## Prerequisites

1. **Get Base Sepolia ETH**
   - Use the [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
   - Or bridge from Sepolia using the [Base Bridge](https://bridge.base.org/)

2. **Get Test Tokens**
   - You'll need USDC on Base Sepolia for testing
   - Check Uniswap V4 docs or community faucets for test token addresses

3. **Set up Environment Variables**
   ```bash
   # Create .env file in contracts directory
   PRIVATE_KEY=your_private_key_here
   BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
   BASESCAN_API_KEY=your_basescan_api_key
   ```

## Deployment Steps

### 1. Update Token Addresses
Before deploying, update the token addresses in `script/DeployBaseSepolia.s.sol`:
- Find the correct USDC contract address on Base Sepolia
- Find a suitable paired token (like WETH or another stablecoin)

You can find these by:
- Checking the Uniswap V4 Base Sepolia documentation
- Looking at existing pools on Base Sepolia
- Using the StateView contract to query existing pools

### 2. Compile Contracts
```bash
cd contracts
forge build
```

### 3. Deploy to Base Sepolia
```bash
forge script script/DeployBaseSepolia.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
```

### 4. Verify the Contract (if not auto-verified)
```bash
forge verify-contract <CONTRACT_ADDRESS> src/JarManager.sol:JarManager \
  --chain-id 84532 \
  --constructor-args $(cast abi-encode "constructor(address,address,(address,address,uint24,int24,address))" \
    <USDC_ADDRESS> <POOL_MANAGER> <POOL_KEY_TUPLE>) \
  --verifier-url https://api-sepolia.basescan.org/api
```

## Post-Deployment

### 1. Initialize the Pool (if needed)
If the USDC/paired token pool doesn't exist yet, you'll need to initialize it:
```solidity
// Call initialize on the PoolManager
poolManager.initialize(poolKey, sqrtPriceX96);
```

The `sqrtPriceX96` should represent 1:1 ratio for stablecoins:
- For 1:1 price: `sqrtPriceX96 = 2^96 = 79228162514264337593543950336`

### 2. Add Initial Liquidity
After deployment, the contract is ready to accept user deposits which will automatically be added as liquidity to the V4 pool.

### 3. Test the Deployment
```bash
# Create a jar
cast send <JARMANAGER_ADDRESS> "createJar(string,uint256)" "Test Jar" 1000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Deposit (make sure to approve first)
cast send <USDC_ADDRESS> "approve(address,uint256)" <JARMANAGER_ADDRESS> 1000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send <JARMANAGER_ADDRESS> "deposit(uint256,uint256)" 0 100000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Important Notes

### Liquidity Management
- The contract uses Uniswap V4's unlock callback pattern for all liquidity operations
- Liquidity is added to a tight range (ticks -60 to +60) suitable for stablecoin pairs
- The admin can rebalance the position if needed using `rebalancePosition()`

### Fee Collection
- Fees accrue automatically in the Uniswap V4 position
- The contract tracks fees via balance changes
- Yield is distributed proportionally to all jar holders

### Security Considerations
1. The contract is non-upgradeable - verify all parameters before deployment
2. Admin functions are protected by Ownable
3. All user operations are protected by ReentrancyGuard
4. Test thoroughly on testnet before any mainnet deployment

## Troubleshooting

### "Pool not initialized" Error
- Initialize the pool first using the PoolManager
- Check that the pool key matches exactly (currency0 < currency1)

### "Insufficient balance" Error
- Ensure you have approved the JarManager contract to spend your tokens
- Check that you have enough token balance

### Settlement Errors
- Verify that the unlock callback is implemented correctly
- Check that token approvals are in place
- Ensure the PoolManager address is correct

## Next Steps

After successful deployment:
1. Update the frontend with the new contract address
2. Configure the frontend to connect to Base Sepolia (chain ID 84532)
3. Test all functionality through the UI
4. Monitor the contract for any issues

## Resources

- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Base Sepolia Explorer](https://sepolia.basescan.org)
- [Base Documentation](https://docs.base.org)
- [Foundry Book](https://book.getfoundry.sh/)
