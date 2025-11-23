// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {JarManager} from "../src/JarManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title JarManagerTest
/// @notice Comprehensive unit tests for JarManager contract
contract JarManagerTest is Test {
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
            fee: 500, // 0.05%
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
                        JAR CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateJar_Success() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.name, "PS5 Fund", "Jar name mismatch");
        assertEq(jar.targetAmount, 500 * 1e6, "Target amount mismatch");
        assertEq(jar.shares, 0, "Initial shares should be 0");
        assertEq(jar.principalDeposited, 0, "Initial principal should be 0");
        assertEq(jar.yieldDebt, 0, "Initial yield debt should be 0");
        assertTrue(jar.isActive, "Jar should be active");
    }

    function test_CreateJar_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit JarManager.JarCreated(alice, 0, "Vacation Fund", 2000 * 1e6);

        vm.prank(alice);
        jarManager.createJar("Vacation Fund", 2000 * 1e6);
    }

    function test_CreateJar_MultipleJars() public {
        vm.startPrank(alice);
        
        uint256 jar1 = jarManager.createJar("PS5 Fund", 500 * 1e6);
        uint256 jar2 = jarManager.createJar("Vacation Fund", 2000 * 1e6);
        uint256 jar3 = jarManager.createJar("Emergency Fund", 5000 * 1e6);

        vm.stopPrank();

        uint256[] memory jarIds = jarManager.getUserJarIds(alice);
        
        assertEq(jarIds.length, 3, "Should have 3 jars");
        assertEq(jarIds[0], jar1, "First jar ID mismatch");
        assertEq(jarIds[1], jar2, "Second jar ID mismatch");
        assertEq(jarIds[2], jar3, "Third jar ID mismatch");
    }

    function test_RevertWhen_JarNameEmpty() public {
        vm.prank(alice);
        vm.expectRevert(JarManager.InvalidJarName.selector);
        jarManager.createJar("", 500 * 1e6);
    }

    function test_RevertWhen_JarNameTooLong() public {
        string memory longName = "This is a very long jar name that exceeds the maximum allowed length of 64 characters";
        
        vm.prank(alice);
        vm.expectRevert(JarManager.InvalidJarName.selector);
        jarManager.createJar(longName, 500 * 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit_FirstDeposit() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        
        uint256 balanceBefore = usdc.balanceOf(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        uint256 balanceAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.principalDeposited, DEPOSIT_AMOUNT, "Principal mismatch");
        assertEq(jar.shares, DEPOSIT_AMOUNT, "Shares should equal first deposit");
        assertEq(balanceBefore - balanceAfter, DEPOSIT_AMOUNT, "Balance change mismatch");
        assertEq(jarManager.totalShares(), DEPOSIT_AMOUNT, "Total shares mismatch");
        assertEq(jarManager.totalPrincipal(), DEPOSIT_AMOUNT, "Total principal mismatch");
    }

    function test_Deposit_MultipleDeposits() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT / 2);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        uint256 expectedTotal = DEPOSIT_AMOUNT + DEPOSIT_AMOUNT / 2;
        assertEq(jar.principalDeposited, expectedTotal, "Principal should sum deposits");
    }

    function test_Deposit_MultipleUsers() public {
        // Alice deposits
        vm.prank(alice);
        uint256 aliceJarId = jarManager.createJar("Alice's Jar", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJarId, DEPOSIT_AMOUNT);

        // Bob deposits
        vm.prank(bob);
        uint256 bobJarId = jarManager.createJar("Bob's Jar", 1000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJarId, DEPOSIT_AMOUNT * 2);

        JarManager.Jar memory aliceJar = jarManager.getJar(alice, aliceJarId);
        JarManager.Jar memory bobJar = jarManager.getJar(bob, bobJarId);

        assertEq(aliceJar.principalDeposited, DEPOSIT_AMOUNT, "Alice principal mismatch");
        assertEq(bobJar.principalDeposited, DEPOSIT_AMOUNT * 2, "Bob principal mismatch");
        assertEq(jarManager.totalPrincipal(), DEPOSIT_AMOUNT * 3, "Total principal mismatch");
    }

    function test_Deposit_EmitsEvent() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);

        vm.expectEmit(true, true, false, true);
        emit JarManager.Deposited(alice, jarId, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);

        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);

        vm.prank(alice);
        vm.expectRevert(JarManager.InvalidAmount.selector);
        jarManager.deposit(jarId, 0);
    }

    function test_RevertWhen_DepositToInactiveJar() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        jarManager.emergencyWithdraw(jarId);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(JarManager.JarNotFound.selector);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw_PartialWithdrawal() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 balanceBefore = usdc.balanceOf(alice);
        
        jarManager.withdraw(jarId, withdrawAmount);
        
        uint256 balanceAfter = usdc.balanceOf(alice);
        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.principalDeposited, DEPOSIT_AMOUNT - withdrawAmount, "Principal after withdrawal mismatch");
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Balance change mismatch");
    }

    function test_Withdraw_FullWithdrawal() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);
        
        jarManager.withdraw(jarId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.principalDeposited, 0, "Principal should be 0 after full withdrawal");
        assertEq(jar.shares, 0, "Shares should be 0 after full withdrawal");
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, false, false);
        emit JarManager.Withdrawn(alice, jarId, DEPOSIT_AMOUNT / 2, 0);

        vm.prank(alice);
        jarManager.withdraw(jarId, DEPOSIT_AMOUNT / 2);
    }

    function test_RevertWhen_WithdrawZeroAmount() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        vm.prank(alice);
        vm.expectRevert(JarManager.InvalidAmount.selector);
        jarManager.withdraw(jarId, 0);
    }

    function test_RevertWhen_WithdrawExceedsPrincipal() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        vm.prank(alice);
        vm.expectRevert(JarManager.InsufficientBalance.selector);
        jarManager.withdraw(jarId, DEPOSIT_AMOUNT + 1);
    }

    function test_RevertWhen_UnauthorizedWithdrawal() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        // Bob tries to withdraw from Alice's jar
        vm.prank(bob);
        vm.expectRevert(JarManager.JarNotFound.selector);
        jarManager.withdraw(jarId, DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EmergencyWithdraw_Success() public {
        vm.startPrank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        uint256 balanceBefore = usdc.balanceOf(alice);
        jarManager.emergencyWithdraw(jarId);
        uint256 balanceAfter = usdc.balanceOf(alice);

        vm.stopPrank();

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.principalDeposited, 0, "Principal should be 0");
        assertEq(jar.shares, 0, "Shares should be 0");
        assertFalse(jar.isActive, "Jar should be inactive");
        assertEq(balanceAfter - balanceBefore, DEPOSIT_AMOUNT, "Should receive all funds");
    }

    function test_EmergencyWithdraw_EmitsEvent() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit JarManager.EmergencyWithdraw(alice, jarId, DEPOSIT_AMOUNT);

        vm.prank(alice);
        jarManager.emergencyWithdraw(jarId);
    }

    function test_RevertWhen_EmergencyWithdrawEmptyJar() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);

        vm.prank(alice);
        vm.expectRevert(JarManager.InsufficientBalance.selector);
        jarManager.emergencyWithdraw(jarId);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetJar_ReturnsCorrectData() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        
        assertEq(jar.name, "PS5 Fund");
        assertEq(jar.targetAmount, 500 * 1e6);
        assertEq(jar.principalDeposited, DEPOSIT_AMOUNT);
    }

    function test_GetUserJarIds_ReturnsAllJars() public {
        vm.startPrank(alice);
        jarManager.createJar("Jar 1", 100 * 1e6);
        jarManager.createJar("Jar 2", 200 * 1e6);
        jarManager.createJar("Jar 3", 300 * 1e6);
        vm.stopPrank();

        uint256[] memory jarIds = jarManager.getUserJarIds(alice);
        
        assertEq(jarIds.length, 3, "Should have 3 jars");
    }

    function test_GetJarTotalBalance_CorrectCalculation() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        uint256 totalBalance = jarManager.getJarTotalBalance(alice, jarId);
        
        assertEq(totalBalance, DEPOSIT_AMOUNT, "Total balance should equal deposit");
    }

    function test_SharesValue_CorrectCalculation() public {
        vm.prank(alice);
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        vm.prank(alice);
        jarManager.deposit(jarId, DEPOSIT_AMOUNT);

        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        uint256 value = jarManager.sharesPrincipalValue(jar.shares);
        
        assertEq(value, DEPOSIT_AMOUNT, "Shares value should equal deposit");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_CompleteUserJourney() public {
        vm.startPrank(alice);
        
        // Create jar
        uint256 jarId = jarManager.createJar("PS5 Fund", 500 * 1e6);
        
        // Make deposits
        jarManager.deposit(jarId, 200 * 1e6);
        jarManager.deposit(jarId, 150 * 1e6);
        jarManager.deposit(jarId, 150 * 1e6);
        
        // Check balance
        JarManager.Jar memory jar = jarManager.getJar(alice, jarId);
        assertEq(jar.principalDeposited, 500 * 1e6, "Should have full target amount");
        
        // Partial withdrawal
        jarManager.withdraw(jarId, 100 * 1e6);
        
        jar = jarManager.getJar(alice, jarId);
        assertEq(jar.principalDeposited, 400 * 1e6, "Should have 400 USDC remaining");
        
        vm.stopPrank();
    }

    function test_Integration_MultipleUsersInteraction() public {
        // Alice creates and deposits
        vm.prank(alice);
        uint256 aliceJar = jarManager.createJar("Alice Jar", 1000 * 1e6);
        vm.prank(alice);
        jarManager.deposit(aliceJar, 500 * 1e6);

        // Bob creates and deposits
        vm.prank(bob);
        uint256 bobJar = jarManager.createJar("Bob Jar", 2000 * 1e6);
        vm.prank(bob);
        jarManager.deposit(bobJar, 1000 * 1e6);

        // Charlie creates and deposits
        vm.prank(charlie);
        uint256 charlieJar = jarManager.createJar("Charlie Jar", 500 * 1e6);
        vm.prank(charlie);
        jarManager.deposit(charlieJar, 250 * 1e6);

        // Verify totals
        assertEq(jarManager.totalPrincipal(), 1750 * 1e6, "Total principal mismatch");
        
        // Alice withdraws
        vm.prank(alice);
        jarManager.withdraw(aliceJar, 200 * 1e6);
        
        assertEq(jarManager.totalPrincipal(), 1550 * 1e6, "Total principal after withdrawal mismatch");
    }
}
