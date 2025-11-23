// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {JarManager} from "../src/JarManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title JarManagerYieldTest
/// @notice Tests for accYieldPerShare yield distribution mechanism
contract JarManagerYieldTest is Test {
    JarManager public jarManager;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockPoolManager public poolManager;
    PoolKey public poolKey;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_BALANCE = 10_000 * 1e6; // 10,000 USDC
    uint256 constant DEPOSIT_AMOUNT = 1_000 * 1e6; // 1,000 USDC
    uint256 constant PRECISION = 1e18;

    function setUp() external {
        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // Deploy mock pool manager
        poolManager = new MockPoolManager();

        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(dai)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        // Deploy JarManager
        jarManager = new JarManager(address(usdc), address(poolManager), poolKey);

        // Setup test users with USDC
        usdc.mint(alice, INITIAL_BALANCE);
        usdc.mint(bob, INITIAL_BALANCE);
        usdc.mint(charlie, INITIAL_BALANCE);

        // Approve JarManager to spend USDC
        vm.prank(alice);
        usdc.approve(address(jarManager), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(jarManager), type(uint256).max);

        vm.prank(charlie);
        usdc.approve(address(jarManager), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_YieldDistribution_SingleUser() public {
        // Alice creates jar and deposits
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Simulate yield generation (100 USDC)
        uint256 yieldAmount = 100 * 1e6;
        usdc.mint(address(jarManager), yieldAmount);

        // Update yield distribution
        jarManager.updateYield();

        // Check that accYieldPerShare was updated
        uint256 accYieldPerShare = jarManager.accYieldPerShare();
        assertGt(accYieldPerShare, 0, "accYieldPerShare should be > 0");

        // Calculate expected yield
        uint256 expectedYield = yieldAmount; // Alice has 100% of shares
        uint256 actualYield = jarManager.calculateCurrentYield(alice, jarId);

        assertEq(actualYield, expectedYield, "Yield should equal generated amount");
    }

    function test_YieldDistribution_TwoUsersEqualShares() public {
        // Alice deposits 1000 USDC
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, DEPOSIT_AMOUNT);

        // Bob deposits 1000 USDC (equal shares)
        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 2000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, DEPOSIT_AMOUNT);

        // Simulate yield generation (200 USDC)
        uint256 yieldAmount = 200 * 1e6;
        usdc.mint(address(jarManager), yieldAmount);

        // Update yield distribution
        jarManager.updateYield();

        // Both should get 50% of yield (100 USDC each)
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, aliceJarId);
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);

        assertEq(aliceYield, 100 * 1e6, "Alice should get 100 USDC");
        assertEq(bobYield, 100 * 1e6, "Bob should get 100 USDC");
        assertEq(aliceYield + bobYield, yieldAmount, "Total yield should match generated");
    }

    function test_YieldDistribution_TwoUsersUnequalShares() public {
        // Alice deposits 1000 USDC
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, 1000 * 1e6);

        // Bob deposits 3000 USDC (3x Alice's deposit)
        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 5000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, 3000 * 1e6);

        // Total: 4000 USDC, Alice has 25%, Bob has 75%

        // Simulate yield generation (400 USDC)
        uint256 yieldAmount = 400 * 1e6;
        usdc.mint(address(jarManager), yieldAmount);

        // Update yield distribution
        jarManager.updateYield();

        // Alice should get 25% (100 USDC), Bob should get 75% (300 USDC)
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, aliceJarId);
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);

        assertEq(aliceYield, 100 * 1e6, "Alice should get 25% of yield");
        assertEq(bobYield, 300 * 1e6, "Bob should get 75% of yield");
    }

    function test_YieldDistribution_DepositAfterYieldGeneration() public {
        // Alice deposits first
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, 1000 * 1e6);

        // Generate yield (100 USDC)
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Bob deposits after yield was generated
        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 2000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, 1000 * 1e6);

        // Alice should have all 100 USDC yield
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, aliceJarId);
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);

        assertEq(aliceYield, 100 * 1e6, "Alice should get all yield generated before Bob joined");
        assertEq(bobYield, 0, "Bob should have no yield from before he joined");
    }

    function test_YieldDistribution_MultipleYieldEvents() public {
        // Alice and Bob deposit equally
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, 1000 * 1e6);

        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 2000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, 1000 * 1e6);

        // First yield event (100 USDC)
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Second yield event (200 USDC)
        usdc.mint(address(jarManager), 200 * 1e6);
        jarManager.updateYield();

        // Third yield event (100 USDC)
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Total yield: 400 USDC, each should get 200 USDC
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, aliceJarId);
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);

        assertEq(aliceYield, 200 * 1e6, "Alice should get 50% of total yield");
        assertEq(bobYield, 200 * 1e6, "Bob should get 50% of total yield");
    }

    function test_ClaimYield_UpdatesDebt() public {
        // Alice deposits
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Generate yield
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Check yield before claim
        uint256 yieldBefore = jarManager.calculateCurrentYield(alice, jarId);
        assertEq(yieldBefore, 100 * 1e6, "Should have 100 USDC yield");

        // Claim yield
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        jarManager.claimYield(jarId);
        uint256 balanceAfter = usdc.balanceOf(alice);

        // Verify claim
        assertEq(balanceAfter - balanceBefore, 100 * 1e6, "Should receive 100 USDC");

        // Verify no more pending yield
        uint256 yieldAfter = jarManager.calculateCurrentYield(alice, jarId);
        assertEq(yieldAfter, 0, "Should have no pending yield after claim");
    }

    function test_ClaimYield_DoesNotAffectOthers() public {
        // Alice and Bob deposit
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, DEPOSIT_AMOUNT);

        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 2000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, DEPOSIT_AMOUNT);

        // Generate yield
        usdc.mint(address(jarManager), 200 * 1e6);
        jarManager.updateYield();

        // Alice claims her yield
        vm.prank(alice);
        jarManager.claimYield(aliceJarId);

        // Bob's yield should be unaffected
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);
        assertEq(bobYield, 100 * 1e6, "Bob's yield should be unchanged");
    }

    function test_YieldAccumulation_AcrossDeposits() public {
        // Alice deposits 1000
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 5000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, 1000 * 1e6);

        // Generate yield (100 USDC)
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Alice deposits another 1000
        vm.prank(alice);
        jarManager.deposit(jarId, 1000 * 1e6);

        // Generate more yield (100 USDC)
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Alice should have: 100 (from first period) + 100 (from second period) = 200
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, jarId);
        assertEq(aliceYield, 200 * 1e6, "Should accumulate yield correctly");
    }

    function test_WithdrawPrincipal_PreservesYield() public {
        // Alice deposits
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Generate yield
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        uint256 yieldBefore = jarManager.calculateCurrentYield(alice, jarId);

        // Withdraw 500 USDC principal
        vm.prank(alice);
        jarManager.withdraw(jarId, 500 * 1e6);

        // Yield should still be claimable
        uint256 yieldAfter = jarManager.calculateCurrentYield(alice, jarId);
        
        // Yield should be approximately the same (minor rounding)
        assertApproxEqRel(yieldAfter, yieldBefore, 0.01e18, "Yield should be preserved");
    }

    function test_EmergencyWithdraw_IncludesYield() public {
        // Alice deposits
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Generate yield
        usdc.mint(address(jarManager), 100 * 1e6);
        jarManager.updateYield();

        // Emergency withdraw
        uint256 balanceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        jarManager.emergencyWithdraw(jarId);
        uint256 balanceAfter = usdc.balanceOf(alice);

        // Should receive principal + yield
        assertEq(balanceAfter - balanceBefore, 1100 * 1e6, "Should receive principal + yield");
    }

    function test_AccYieldPerShare_Precision() public {
        // Test with small amounts to verify precision
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 100 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, 1 * 1e6); // 1 USDC

        // Generate very small yield (0.001 USDC = 1000 units)
        usdc.mint(address(jarManager), 1000);
        jarManager.updateYield();

        // Should still track the small yield accurately
        uint256 yield = jarManager.calculateCurrentYield(alice, jarId);
        assertEq(yield, 1000, "Should track small yield amounts");
    }

    function test_YieldDistribution_ThreeUsers() public {
        // Alice: 1000 USDC (25%)
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, 1000 * 1e6);

        // Bob: 2000 USDC (50%)
        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob Jar", 3000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, 2000 * 1e6);

        // Charlie: 1000 USDC (25%)
        vm.prank(charlie);
        uint256 charlieJarId = jarManager.createJar("Charlie Jar", 2000 * 1e6);
        vm.prank(charlie);
        jarManager.deposit(charlieJarId, 1000 * 1e6);

        // Total: 4000 USDC

        // Generate yield (400 USDC)
        usdc.mint(address(jarManager), 400 * 1e6);
        jarManager.updateYield();

        // Verify proportional distribution
        uint256 aliceYield = jarManager.calculateCurrentYield(alice, aliceJarId);
        uint256 bobYield = jarManager.calculateCurrentYield(bob, bobJarId);
        uint256 charlieYield = jarManager.calculateCurrentYield(charlie, charlieJarId);

        assertEq(aliceYield, 100 * 1e6, "Alice should get 25%");
        assertEq(bobYield, 200 * 1e6, "Bob should get 50%");
        assertEq(charlieYield, 100 * 1e6, "Charlie should get 25%");
        assertEq(aliceYield + bobYield + charlieYield, 400 * 1e6, "Total should equal yield");
    }

    function test_YieldEvent_Emission() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("Alice Jar", 2000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Generate yield
        uint256 yieldAmount = 100 * 1e6;
        usdc.mint(address(jarManager), yieldAmount);

        // Expect event with calculated accYieldPerShare
        // accYieldPerShare = (yieldAmount * PRECISION) / totalShares
        // = (100 * 1e6 * 1e18) / 1000 * 1e6 = 100000000000000000 = 1e17
        uint256 expectedAccYieldPerShare = (yieldAmount * 1e18) / DEPOSIT_AMOUNT;
        vm.expectEmit(true, true, true, true);
        emit JarManager.YieldDistributed(yieldAmount, expectedAccYieldPerShare);

        jarManager.updateYield();
    }
}
