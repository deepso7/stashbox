// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {JarManager} from "../src/JarManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title DeployJarManager
/// @notice Deployment script for JarManager contract
contract DeployJarManager is Script {
    // Sepolia testnet addresses (example - update with actual addresses)
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Example USDC
    address constant SEPOLIA_POOL_MANAGER = address(0); // Update with actual V4 PoolManager
    address constant SEPOLIA_DAI = address(0); // Update with actual DAI

    // Mainnet addresses (for reference)
    address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant MAINNET_POOL_MANAGER = address(0); // Update with actual V4 PoolManager
    address constant MAINNET_DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function run() public {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== JarManager Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);

        // Determine which addresses to use based on chain ID
        address depositToken;
        address poolManager;
        address pairedToken;

        if (block.chainid == 11155111) {
            // Sepolia
            depositToken = SEPOLIA_USDC;
            poolManager = SEPOLIA_POOL_MANAGER;
            pairedToken = SEPOLIA_DAI;
            console.log("Deploying to Sepolia testnet");
        } else if (block.chainid == 1) {
            // Mainnet
            depositToken = MAINNET_USDC;
            poolManager = MAINNET_POOL_MANAGER;
            pairedToken = MAINNET_DAI;
            console.log("Deploying to Ethereum mainnet");
        } else if (block.chainid == 31337) {
            // Local / Anvil
            console.log("Deploying to local network");
            // For local testing, you'd need to deploy mock contracts first
            revert("Local deployment requires manual setup of mock contracts");
        } else {
            revert("Unsupported network");
        }

        // Validate addresses
        require(depositToken != address(0), "Invalid deposit token address");
        require(poolManager != address(0), "Invalid pool manager address");
        require(pairedToken != address(0), "Invalid paired token address");

        // Create pool key for USDC/DAI pair
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(depositToken),
            currency1: Currency.wrap(pairedToken),
            fee: 500, // 0.05% fee tier
            tickSpacing: 10,
            hooks: IHooks(address(0)) // No hooks for initial deployment
        });

        console.log("\nDeployment Parameters:");
        console.log("Deposit Token (USDC):", depositToken);
        console.log("Pool Manager:", poolManager);
        console.log("Paired Token (DAI):", pairedToken);
        console.log("Pool Fee:", poolKey.fee);
        console.log("Tick Spacing:", uint256(int256(poolKey.tickSpacing)));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy JarManager
        JarManager jarManager = new JarManager(depositToken, poolManager, poolKey);

        console.log("\n=== Deployment Successful ===");
        console.log("JarManager deployed at:", address(jarManager));

        vm.stopBroadcast();

        // Post-deployment verification
        console.log("\n=== Verification ===");
        console.log("Deposit Token:", address(jarManager.DEPOSIT_TOKEN()));
        console.log("Pool Manager:", address(jarManager.POOL_MANAGER()));
        console.log("Owner:", jarManager.owner());
        
        (int24 tickLower, int24 tickUpper,) = jarManager.position();
        console.log("Initial Position - Lower Tick:", int256(tickLower));
        console.log("Initial Position - Upper Tick:", int256(tickUpper));

        // Verify deployment
        require(address(jarManager.DEPOSIT_TOKEN()) == depositToken, "Deposit token mismatch");
        require(address(jarManager.POOL_MANAGER()) == poolManager, "Pool manager mismatch");
        require(jarManager.owner() == deployer, "Owner not set correctly");

        console.log("\n=== Next Steps ===");
        console.log("1. Verify contract on Etherscan:");
        console.log("   forge verify-contract", address(jarManager), "src/JarManager.sol:JarManager --watch");
        console.log("2. Set up initial liquidity position if needed");
        console.log("3. Test jar creation and deposits");
        console.log("========================\n");
    }
}

/// @title DeployJarManagerLocal
/// @notice Deployment script for local testing with mocks
contract DeployJarManagerLocal is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        console.log("=== Local JarManager Deployment ===");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mocks
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockERC20 dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        MockPoolManager poolManager = new MockPoolManager();

        console.log("Mock USDC deployed at:", address(usdc));
        console.log("Mock DAI deployed at:", address(dai));
        console.log("Mock PoolManager deployed at:", address(poolManager));

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(dai)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        // Deploy JarManager
        JarManager jarManager = new JarManager(address(usdc), address(poolManager), poolKey);

        console.log("JarManager deployed at:", address(jarManager));

        // Mint some USDC for testing
        address deployer = vm.addr(deployerPrivateKey);
        usdc.mint(deployer, 1_000_000 * 1e6); // 1M USDC

        vm.stopBroadcast();

        console.log("\nTest tokens minted to deployer:", deployer);
        console.log("USDC Balance:", usdc.balanceOf(deployer));
    }
}

// Mock contracts for local deployment
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockPoolManager {
    // Minimal mock for deployment
}
