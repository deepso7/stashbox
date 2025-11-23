// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {JarManager} from "../src/JarManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title DeployBaseSepolia
/// @notice Deployment script for JarManager on Base Sepolia testnet
/// @dev This script deploys JarManager using real Uniswap V4 contracts on Base Sepolia
contract DeployBaseSepolia is Script {
    // Base Sepolia Uniswap V4 Contracts
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address constant POSITION_MANAGER = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address constant SWAP_ROUTER = 0x8B5bcC363ddE2614281aD875bad385E0A785D3B9;
    address constant QUOTER = 0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa;
    
    // Common Base Sepolia tokens (you may need to update these)
    // USDC on Base Sepolia
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Example - verify actual address
    // DAI on Base Sepolia  
    address constant DAI = 0x7683022d84F726a96c4A6611cD31DBf5409c0Ac9; // Example - verify actual address
    
    // Pool parameters
    uint24 constant FEE = 500; // 0.05% fee tier
    int24 constant TICK_SPACING = 10;
    
    function run() external {
        // Read private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying JarManager to Base Sepolia...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("PoolManager:", POOL_MANAGER);
        console.log("USDC:", USDC);
        console.log("DAI:", DAI);
        
        // Create pool key for USDC/DAI pair
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(USDC < DAI ? USDC : DAI),
            currency1: Currency.wrap(USDC < DAI ? DAI : USDC),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // No hooks for now
        });
        
        // Deploy JarManager
        JarManager jarManager = new JarManager(
            USDC, // Use USDC as deposit token
            POOL_MANAGER,
            poolKey
        );
        
        console.log("JarManager deployed at:", address(jarManager));
        console.log("\nDeployment Summary:");
        console.log("==================");
        console.log("Network: Base Sepolia (Chain ID: 84532)");
        console.log("JarManager:", address(jarManager));
        console.log("Deposit Token (USDC):", USDC);
        console.log("Pool Manager:", POOL_MANAGER);
        console.log("Pool: USDC/DAI");
        console.log("Fee Tier:", FEE);
        console.log("\nNext Steps:");
        console.log("1. Verify contract on BaseScan");
        console.log("2. Initialize the pool if not already initialized");
        console.log("3. Add initial liquidity");
        console.log("4. Update frontend with contract address");
        
        vm.stopBroadcast();
    }
}
