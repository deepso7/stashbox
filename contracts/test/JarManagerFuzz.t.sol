// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {JarManager} from "../src/JarManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title JarManagerFuzzTest
/// @notice Fuzz tests for JarManager contract
contract JarManagerFuzzTest is Test {
    JarManager public jarManager;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockPoolManager public poolManager;
    PoolKey public poolKey;

    address[] public actors;
    uint256 constant MAX_ACTORS = 5;
    uint256 constant MAX_SUPPLY = 1_000_000 * 1e6; // 1M USDC

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

        // Setup actors
        for (uint256 i = 0; i < MAX_ACTORS; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            
            usdc.mint(actor, MAX_SUPPLY);
            
            vm.prank(actor);
            usdc.approve(address(jarManager), type(uint256).max);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Deposit_ValidAmounts(uint96 amount, uint256 actorSeed) public {
        // Bound inputs
        amount = uint96(bound(amount, 1, MAX_SUPPLY));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        // Create jar
        vm.prank(actor);
        uint256 jarId = jarManager.createJar("Fuzz Jar", amount * 2);

        // Deposit
        vm.prank(actor);
        jarManager.deposit(jarId, amount);

        // Verify state
        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        assertEq(jar.principalDeposited, amount, "Principal mismatch");
        assertGt(jar.shares, 0, "Shares should be greater than 0");
        assertEq(jarManager.totalPrincipal(), amount, "Total principal mismatch");
    }

    function testFuzz_Deposit_MultipleDeposits(
        uint96 amount1,
        uint96 amount2,
        uint96 amount3,
        uint256 actorSeed
    ) public {
        // Bound inputs
        amount1 = uint96(bound(amount1, 1, MAX_SUPPLY / 3));
        amount2 = uint96(bound(amount2, 1, MAX_SUPPLY / 3));
        amount3 = uint96(bound(amount3, 1, MAX_SUPPLY / 3));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        uint256 jarId = jarManager.createJar("Multi Deposit Jar", MAX_SUPPLY);

        uint256 totalDeposited = 0;

        if (amount1 > 0) {
            jarManager.deposit(jarId, amount1);
            totalDeposited += amount1;
        }

        if (amount2 > 0) {
            jarManager.deposit(jarId, amount2);
            totalDeposited += amount2;
        }

        if (amount3 > 0) {
            jarManager.deposit(jarId, amount3);
            totalDeposited += amount3;
        }

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        assertEq(jar.principalDeposited, totalDeposited, "Total deposits mismatch");
    }

    function testFuzz_Deposit_MultipleActors(
        uint96 amount1,
        uint96 amount2,
        uint256 actor1Seed,
        uint256 actor2Seed
    ) public {
        // Bound inputs
        amount1 = uint96(bound(amount1, 1, MAX_SUPPLY));
        amount2 = uint96(bound(amount2, 1, MAX_SUPPLY));
        address actor1 = actors[bound(actor1Seed, 0, actors.length - 1)];
        address actor2 = actors[bound(actor2Seed, 0, actors.length - 1)];
        
        // Ensure actors are different to avoid balance issues
        vm.assume(actor1 != actor2);

        // Actor 1 deposits
        vm.prank(actor1);
        uint256 jar1 = jarManager.createJar("Actor1 Jar", amount1 * 2);
        vm.prank(actor1);
        jarManager.deposit(jar1, amount1);

        // Actor 2 deposits
        vm.prank(actor2);
        uint256 jar2 = jarManager.createJar("Actor2 Jar", amount2 * 2);
        vm.prank(actor2);
        jarManager.deposit(jar2, amount2);

        // Verify independent accounting
        JarManager.Jar memory jarData1 = jarManager.getJar(actor1, jar1);
        JarManager.Jar memory jarData2 = jarManager.getJar(actor2, jar2);

        assertEq(jarData1.principalDeposited, amount1, "Actor1 principal mismatch");
        assertEq(jarData2.principalDeposited, amount2, "Actor2 principal mismatch");
        assertEq(jarManager.totalPrincipal(), uint256(amount1) + uint256(amount2), "Total principal mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Withdraw_ValidAmounts(uint96 depositAmount, uint96 withdrawAmount, uint256 actorSeed) public {
        // Bound inputs
        depositAmount = uint96(bound(depositAmount, 100, MAX_SUPPLY));
        withdrawAmount = uint96(bound(withdrawAmount, 1, depositAmount));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        uint256 jarId = jarManager.createJar("Withdraw Test", depositAmount * 2);
        jarManager.deposit(jarId, depositAmount);

        uint256 balanceBefore = usdc.balanceOf(actor);
        jarManager.withdraw(jarId, withdrawAmount);
        uint256 balanceAfter = usdc.balanceOf(actor);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        
        assertEq(jar.principalDeposited, depositAmount - withdrawAmount, "Principal after withdrawal mismatch");
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Balance change mismatch");
    }

    function testFuzz_Withdraw_MultipleWithdrawals(
        uint96 depositAmount,
        uint96 withdraw1,
        uint96 withdraw2,
        uint256 actorSeed
    ) public {
        // Bound inputs
        depositAmount = uint96(bound(depositAmount, 1000, MAX_SUPPLY));
        withdraw1 = uint96(bound(withdraw1, 1, depositAmount / 2));
        withdraw2 = uint96(bound(withdraw2, 1, depositAmount / 2));
        
        // Ensure total withdrawals don't exceed deposit
        vm.assume(uint256(withdraw1) + uint256(withdraw2) <= depositAmount);
        
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        uint256 jarId = jarManager.createJar("Multi Withdraw", depositAmount * 2);
        jarManager.deposit(jarId, depositAmount);

        jarManager.withdraw(jarId, withdraw1);
        jarManager.withdraw(jarId, withdraw2);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        uint256 expectedRemaining = depositAmount - withdraw1 - withdraw2;
        
        assertEq(jar.principalDeposited, expectedRemaining, "Remaining principal mismatch");
    }

    function testFuzz_Withdraw_FullWithdrawal(uint96 amount, uint256 actorSeed) public {
        // Bound inputs
        amount = uint96(bound(amount, 1, MAX_SUPPLY));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        uint256 jarId = jarManager.createJar("Full Withdraw", amount * 2);
        jarManager.deposit(jarId, amount);

        uint256 balanceBefore = usdc.balanceOf(actor);
        jarManager.withdraw(jarId, amount);
        uint256 balanceAfter = usdc.balanceOf(actor);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        
        assertEq(jar.principalDeposited, 0, "Principal should be 0");
        assertEq(jar.shares, 0, "Shares should be 0");
        assertEq(balanceAfter - balanceBefore, amount, "Should receive full amount");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAW SEQUENCE TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositWithdrawSequence(
        uint96 deposit1,
        uint96 withdraw1,
        uint96 deposit2,
        uint256 actorSeed
    ) public {
        // Bound inputs
        deposit1 = uint96(bound(deposit1, 1000, MAX_SUPPLY / 2));
        withdraw1 = uint96(bound(withdraw1, 1, deposit1));
        deposit2 = uint96(bound(deposit2, 1, MAX_SUPPLY / 2));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        uint256 jarId = jarManager.createJar("Sequence Test", MAX_SUPPLY);
        
        // First deposit
        jarManager.deposit(jarId, deposit1);
        
        // Withdraw
        jarManager.withdraw(jarId, withdraw1);
        
        // Second deposit
        jarManager.deposit(jarId, deposit2);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        uint256 expectedPrincipal = deposit1 - withdraw1 + deposit2;
        
        assertEq(jar.principalDeposited, expectedPrincipal, "Principal sequence mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                        SHARES ACCOUNTING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SharesProportional(uint96 amount1, uint96 amount2, uint256 actor1Seed, uint256 actor2Seed) public {
        // Bound inputs
        amount1 = uint96(bound(amount1, 1e6, MAX_SUPPLY / 2)); // Min 1 USDC
        amount2 = uint96(bound(amount2, 1e6, MAX_SUPPLY / 2));
        address actor1 = actors[bound(actor1Seed, 0, actors.length - 1)];
        address actor2 = actors[bound(actor2Seed, 0, actors.length - 1)];

        // First deposit sets share price
        vm.prank(actor1);
        uint256 jar1 = jarManager.createJar("Jar1", amount1 * 2);
        vm.prank(actor1);
        jarManager.deposit(jar1, amount1);

        // Second deposit should get proportional shares
        vm.prank(actor2);
        uint256 jar2 = jarManager.createJar("Jar2", amount2 * 2);
        vm.prank(actor2);
        jarManager.deposit(jar2, amount2);

        JarManager.Jar memory jarData1 = jarManager.getJar(actor1, jar1);
        JarManager.Jar memory jarData2 = jarManager.getJar(actor2, jar2);

        // Shares should be proportional to deposits
        uint256 totalShares = jarData1.shares + jarData2.shares;
        uint256 totalPrincipal = amount1 + amount2;

        // Actor 1's share percentage
        uint256 actor1SharePct = (jarData1.shares * 1e18) / totalShares;
        uint256 actor1PrincipalPct = (uint256(amount1) * 1e18) / totalPrincipal;

        // Allow for small rounding errors (within 0.01%)
        assertApproxEqRel(actor1SharePct, actor1PrincipalPct, 0.0001e18, "Share proportion mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_EmergencyWithdraw(uint96 amount, uint256 actorSeed) public {
        // Bound inputs
        amount = uint96(bound(amount, 1, MAX_SUPPLY));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        uint256 jarId = jarManager.createJar("Emergency Test", amount * 2);
        jarManager.deposit(jarId, amount);

        uint256 balanceBefore = usdc.balanceOf(actor);
        jarManager.emergencyWithdraw(jarId);
        uint256 balanceAfter = usdc.balanceOf(actor);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        
        assertFalse(jar.isActive, "Jar should be inactive");
        assertEq(jar.principalDeposited, 0, "Principal should be 0");
        assertEq(jar.shares, 0, "Shares should be 0");
        assertEq(balanceAfter - balanceBefore, amount, "Should receive full deposit");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MinimumDeposit(uint256 actorSeed) public {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.prank(actor);
        uint256 jarId = jarManager.createJar("Min Deposit", 1000);

        vm.prank(actor);
        jarManager.deposit(jarId, 1);

        JarManager.Jar memory jar = jarManager.getJar(actor, jarId);
        assertEq(jar.principalDeposited, 1, "Should accept minimum deposit");
    }

    function testFuzz_MultipleJarsPerUser(uint8 numJars, uint256 actorSeed) public {
        numJars = uint8(bound(numJars, 1, 10));
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];

        vm.startPrank(actor);
        
        for (uint256 i = 0; i < numJars; i++) {
            jarManager.createJar(string(abi.encodePacked("Jar", i)), 1000 * 1e6);
        }

        vm.stopPrank();

        uint256[] memory jarIds = jarManager.getUserJarIds(actor);
        assertEq(jarIds.length, numJars, "Should create all jars");
    }
}
