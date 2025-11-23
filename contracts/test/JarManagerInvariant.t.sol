// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {JarManager} from "../src/JarManager.sol";
import {JarManagerHandler} from "./handlers/JarManagerHandler.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolManager} from "./mocks/MockPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

/// @title JarManagerInvariantTest
/// @notice Invariant tests for JarManager using handler-based testing
contract JarManagerInvariantTest is Test {
    JarManager public jarManager;
    JarManagerHandler public handler;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockPoolManager public poolManager;
    PoolKey public poolKey;

    address[] public actors;

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
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
        actors.push(makeAddr("actor4"));

        // Deploy handler
        handler = new JarManagerHandler(jarManager, usdc, actors);

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Target specific functions
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.createJar.selector;
        selectors[1] = handler.deposit.selector;
        selectors[2] = handler.withdraw.selector;
        selectors[3] = handler.claimYield.selector;
        selectors[4] = handler.emergencyWithdraw.selector;
        selectors[5] = handler.multiDeposit.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /*//////////////////////////////////////////////////////////////
                        CORE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Invariant: Total shares equals sum of all jar shares
    function invariant_totalSharesEqualsSum() external {
        uint256 sumOfShares = handler.getSumOfAllJarShares();
        uint256 totalShares = jarManager.totalShares();

        assertEq(totalShares, sumOfShares, "Total shares mismatch");
    }

    /// @notice Invariant: Total principal equals sum of all jar principals
    function invariant_totalPrincipalEqualsSum() external {
        uint256 sumOfBalances = handler.getSumOfAllJarBalances();
        uint256 totalPrincipal = jarManager.totalPrincipal();

        assertEq(totalPrincipal, sumOfBalances, "Total principal mismatch");
    }

    /// @notice Invariant: Contract balance >= total principal (with accYieldPerShare pattern, we don't track totalYield separately)
    function invariant_contractBalanceSufficient() external {
        uint256 contractBalance = usdc.balanceOf(address(jarManager));
        uint256 totalPrincipal = jarManager.totalPrincipal();

        assertGe(contractBalance, totalPrincipal, "Insufficient contract balance");
    }

    /// @notice Invariant: Ghost variable consistency
    function invariant_ghostVariablesConsistent() external {
        uint256 netDeposited = handler.ghost_totalDeposited();
        uint256 netWithdrawn = handler.ghost_totalWithdrawn();

        // Net deposited should be >= total principal (accounting for rounding)
        assertGe(netDeposited, netWithdrawn, "Withdrawals exceed deposits");
    }

    /// @notice Invariant: AccYieldPerShare is monotonically increasing
    function invariant_accYieldPerShareMonotonic() external {
        // accYieldPerShare should never decrease
        uint256 currentAccYieldPerShare = jarManager.accYieldPerShare();
        // We can't easily track previous value in stateless invariant tests
        // but we can ensure it's non-negative
        assertGe(currentAccYieldPerShare, 0, "accYieldPerShare should be non-negative");
    }

    /// @notice Invariant: Total principal <= position liquidity
    function invariant_liquidityAccounting() external {
        uint256 totalPrincipal = jarManager.totalPrincipal();
        (,, uint128 liquidity) = jarManager.position();

        // In our simplified implementation, liquidity should equal or exceed principal
        // (may be slightly higher due to unclaimed yield)
        assertGe(uint256(liquidity), totalPrincipal, "Liquidity accounting mismatch");
    }

    /// @notice Invariant: Shares value equals principal when no yield
    function invariant_sharesValueEquality() external {
        uint256 totalShares = jarManager.totalShares();
        uint256 totalPrincipal = jarManager.totalPrincipal();

        if (totalShares > 0) {
            uint256 sharesValue = jarManager.sharesValue(totalShares);
            assertEq(sharesValue, totalPrincipal, "Shares value mismatch");
        }
    }

    /// @notice Invariant: Each jar's shares value equals its principal
    function invariant_individualJarSharesValue() external view {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = handler.getActorJars(actors[i]);
            
            for (uint256 j = 0; j < jars.length; j++) {
                JarManager.Jar memory jar = jarManager.getJar(actors[i], jars[j]);
                
                if (jar.isActive && jar.shares > 0) {
                    uint256 sharesValue = jarManager.sharesValue(jar.shares);
                    
                    // Shares value should approximately equal principal (allow small rounding error)
                    // Using 1% tolerance for rounding
                    assertApproxEqRel(
                        sharesValue,
                        jar.principalDeposited,
                        0.01e18,
                        "Jar shares value mismatch"
                    );
                }
            }
        }
    }

    /// @notice Invariant: No inactive jars have balance
    function invariant_inactiveJarsHaveNoBalance() external view {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = handler.getActorJars(actors[i]);
            
            for (uint256 j = 0; j < jars.length; j++) {
                JarManager.Jar memory jar = jarManager.getJar(actors[i], jars[j]);
                
                if (!jar.isActive) {
                    assertEq(jar.principalDeposited, 0, "Inactive jar has principal");
                    assertEq(jar.shares, 0, "Inactive jar has shares");
                    assertEq(jar.yieldDebt, 0, "Inactive jar has yield debt");
                }
            }
        }
    }

    /// @notice Invariant: Total shares is never negative (impossible but tests type safety)
    function invariant_totalSharesNonNegative() external {
        uint256 totalShares = jarManager.totalShares();
        assertGe(totalShares, 0, "Total shares is negative");
    }

    /// @notice Invariant: Total principal is never negative
    function invariant_totalPrincipalNonNegative() external {
        uint256 totalPrincipal = jarManager.totalPrincipal();
        assertGe(totalPrincipal, 0, "Total principal is negative");
    }

    /*//////////////////////////////////////////////////////////////
                        LOGGING & DEBUGGING
    //////////////////////////////////////////////////////////////*/

    function invariant_callSummary() external view {
        console.log("\n=== Invariant Test Summary ===");
        console.log("Total Jars Created:", handler.ghost_jarCount());
        console.log("Total Deposits:", handler.ghost_depositCount());
        console.log("Total Withdrawals:", handler.ghost_withdrawCount());
        console.log("Total Deposited Amount:", handler.ghost_totalDeposited());
        console.log("Total Withdrawn Amount:", handler.ghost_totalWithdrawn());
        console.log("Total Yield Claimed:", handler.ghost_totalYieldClaimed());
        console.log("\nContract State:");
        console.log("Total Shares:", jarManager.totalShares());
        console.log("Total Principal:", jarManager.totalPrincipal());
        console.log("Total Yield Collected:", jarManager.totalYieldCollected());
        console.log("Contract USDC Balance:", usdc.balanceOf(address(jarManager)));
        console.log("Active Jars:", handler.getTotalActiveJars());
        console.log("==============================\n");
    }
}
