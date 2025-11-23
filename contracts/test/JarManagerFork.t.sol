// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {JarManager} from "../src/JarManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @title JarManagerForkTest
/// @notice Fork tests against real Uniswap V4 contracts on Base Sepolia
/// @dev Run with: forge test --match-contract JarManagerForkTest --fork-url $BASE_SEPOLIA_RPC_URL -vvv
contract JarManagerForkTest is Test {
    JarManager public jarManager;
    IPoolManager public poolManager;
    PoolKey public poolKey;
    
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    
    // You need to update these with actual token addresses on Base Sepolia
    // These are placeholder addresses - replace with actual testnet token addresses
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // PLACEHOLDER
    address constant DAI = 0x7683022d84F726a96c4A6611cD31DBf5409c0Ac9; // PLACEHOLDER
    
    address public alice;
    address public bob;
    
    uint256 constant INITIAL_BALANCE = 10_000 * 1e6; // 10,000 USDC
    uint256 constant DEPOSIT_AMOUNT = 1_000 * 1e6; // 1,000 USDC

    function setUp() external {
        // Create test users
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        // Get pool manager
        poolManager = IPoolManager(POOL_MANAGER);
        
        // Create pool key (ensure currency0 < currency1)
        (address token0, address token1) = USDC < DAI ? (USDC, DAI) : (DAI, USDC);
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 500, // 0.05%
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        
        // Deploy JarManager
        jarManager = new JarManager(USDC, address(poolManager), poolKey);
        
        // Fund test users with tokens
        // Note: In a real fork test, you'd need to either:
        // 1. Use deal() to give tokens if the token supports it
        // 2. Impersonate a whale address that has tokens
        // 3. Get tokens from a faucet
        
        // Example using deal (if token supports it):
        deal(USDC, alice, INITIAL_BALANCE);
        deal(USDC, bob, INITIAL_BALANCE);
        
        // Approve JarManager
        vm.prank(alice);
        IERC20(USDC).approve(address(jarManager), type(uint256).max);
        
        vm.prank(bob);
        IERC20(USDC).approve(address(jarManager), type(uint256).max);
    }
    
    function test_Fork_CreateJarAndDeposit() public {
        vm.startPrank(alice);
        
        // Create jar
        uint256 jarId = jarManager.createJar("Test Jar", 500 * 1e6);
        
        // Deposit
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        assertEq(jar.principalDeposited, DEPOSIT_AMOUNT, "Principal mismatch");
        assertGt(jar.shares, 0, "Should have shares");
    }
    
    function test_Fork_LiquidityAddedToV4() public {
        vm.startPrank(alice);
        
        uint256 jarId = jarManager.createJar("Test Jar", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        
        vm.stopPrank();
        
        // Check that liquidity was added
        (,,uint128 liquidity) = jarManager.position();
        assertGt(liquidity, 0, "Should have liquidity in position");
    }
    
    function test_Fork_WithdrawRemovesLiquidity() public {
        vm.startPrank(alice);
        
        uint256 jarId = jarManager.createJar("Test Jar", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        
        uint256 balanceBefore = IERC20(USDC).balanceOf(alice);
        
        // Withdraw half
        jarManager.withdraw(jarId, DEPOSIT_AMOUNT / 2);
        
        vm.stopPrank();
        
        uint256 balanceAfter = IERC20(USDC).balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, DEPOSIT_AMOUNT / 2, "Should receive withdrawn amount");
    }
    
    function test_Fork_MultipleUsersShareLiquidity() public {
        // Alice deposits
        vm.prank(alice);
        uint256 aliceJar = jarManager.createJar("Alice Jar", 1000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJar, DEPOSIT_AMOUNT);
        
        // Bob deposits
        vm.prank(bob);
        uint256 bobJar = jarManager.createJar("Bob Jar", 1000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJar, DEPOSIT_AMOUNT * 2);
        
        // Check total liquidity
        (,,uint128 totalLiquidity) = jarManager.position();
        assertEq(totalLiquidity, DEPOSIT_AMOUNT + DEPOSIT_AMOUNT * 2, "Total liquidity mismatch");
    }
    
    function testFail_Fork_CannotDepositWithoutApproval() public {
        address charlie = makeAddr("charlie");
        deal(USDC, charlie, INITIAL_BALANCE);
        
        vm.prank(charlie);
        uint256 jarId = jarManager.createJar("Test Jar", 500 * 1e6);
        
        // Should fail - no approval
        vm.prank(charlie);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
    }
}
