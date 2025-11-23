// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {JarManager} from "../../src/JarManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @title JarManagerHandler
/// @notice Handler contract for invariant testing with bounded random actions
contract JarManagerHandler is Test {
    JarManager public jarManager;
    MockERC20 public usdc;

    // Ghost variables for tracking aggregate state
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalYieldClaimed;
    uint256 public ghost_depositCount;
    uint256 public ghost_withdrawCount;
    uint256 public ghost_jarCount;

    // Actor management
    address[] public actors;
    address internal currentActor;

    // Track jars per actor
    mapping(address => uint256[]) public actorJars;
    mapping(address => uint256) public actorDepositedAmount;

    uint256 constant MAX_AMOUNT = 100_000 * 1e6; // 100k USDC
    uint256 constant MIN_AMOUNT = 1e6; // 1 USDC

    constructor(JarManager _jarManager, MockERC20 _usdc, address[] memory _actors) {
        jarManager = _jarManager;
        usdc = _usdc;
        actors = _actors;

        // Mint USDC to all actors and approve
        for (uint256 i = 0; i < actors.length; i++) {
            usdc.mint(actors[i], 1_000_000 * 1e6); // 1M USDC each
            
            vm.prank(actors[i]);
            usdc.approve(address(jarManager), type(uint256).max);
        }
    }

    modifier useActor(uint256 actorSeed) {
        currentActor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        HANDLER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new jar for a random actor
    function createJar(uint256 actorSeed, uint256 targetAmount) external useActor(actorSeed) {
        targetAmount = bound(targetAmount, MIN_AMOUNT, MAX_AMOUNT * 10);

        try jarManager.createJar("Invariant Test Jar", targetAmount) returns (uint256 jarId) {
            actorJars[currentActor].push(jarId);
            ghost_jarCount++;
        } catch {
            // Ignore failures
        }
    }

    /// @notice Deposit into a random jar
    function deposit(uint256 actorSeed, uint256 jarIndexSeed, uint256 amount) external useActor(actorSeed) {
        if (actorJars[currentActor].length == 0) {
            // Create a jar first
            try jarManager.createJar("Auto Created Jar", MAX_AMOUNT) returns (uint256 jarId) {
                actorJars[currentActor].push(jarId);
                ghost_jarCount++;
            } catch {
                return;
            }
        }

        uint256 jarIndex = bound(jarIndexSeed, 0, actorJars[currentActor].length - 1);
        uint256 jarId = actorJars[currentActor][jarIndex];

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        // Ensure actor has enough balance
        uint256 balance = usdc.balanceOf(currentActor);
        if (balance < amount) {
            amount = balance;
        }

        if (amount == 0) return;

        try jarManager.deposit(jarId, amount) {
            ghost_totalDeposited += amount;
            ghost_depositCount++;
            actorDepositedAmount[currentActor] += amount;
        } catch {
            // Ignore deposit failures
        }
    }

    /// @notice Withdraw from a random jar
    function withdraw(uint256 actorSeed, uint256 jarIndexSeed, uint256 amount) external useActor(actorSeed) {
        if (actorJars[currentActor].length == 0) return;

        uint256 jarIndex = bound(jarIndexSeed, 0, actorJars[currentActor].length - 1);
        uint256 jarId = actorJars[currentActor][jarIndex];

        JarManager.Jar memory jar = jarManager.getJar(currentActor, jarId);
        
        if (!jar.isActive || jar.principalDeposited == 0) return;

        amount = bound(amount, MIN_AMOUNT, jar.principalDeposited);

        try jarManager.withdraw(jarId, amount) {
            ghost_totalWithdrawn += amount;
            ghost_withdrawCount++;
            actorDepositedAmount[currentActor] -= amount;
        } catch {
            // Ignore withdrawal failures
        }
    }

    /// @notice Claim yield from a random jar
    function claimYield(uint256 actorSeed, uint256 jarIndexSeed) external useActor(actorSeed) {
        if (actorJars[currentActor].length == 0) return;

        uint256 jarIndex = bound(jarIndexSeed, 0, actorJars[currentActor].length - 1);
        uint256 jarId = actorJars[currentActor][jarIndex];

        JarManager.Jar memory jar = jarManager.getJar(currentActor, jarId);
        
        if (!jar.isActive) return;

        // Calculate pending yield using accYieldPerShare pattern
        uint256 pendingYield = jarManager.calculateCurrentYield(currentActor, jarId);
        if (pendingYield == 0) return;

        try jarManager.claimYield(jarId) {
            ghost_totalYieldClaimed += pendingYield;
        } catch {
            // Ignore claim failures
        }
    }

    /// @notice Emergency withdraw from a random jar
    function emergencyWithdraw(uint256 actorSeed, uint256 jarIndexSeed) external useActor(actorSeed) {
        if (actorJars[currentActor].length == 0) return;

        uint256 jarIndex = bound(jarIndexSeed, 0, actorJars[currentActor].length - 1);
        uint256 jarId = actorJars[currentActor][jarIndex];

        JarManager.Jar memory jar = jarManager.getJar(currentActor, jarId);
        
        if (!jar.isActive) return;

        uint256 pendingYield = jarManager.calculateCurrentYield(currentActor, jarId);
        uint256 totalAmount = jar.principalDeposited + pendingYield;
        
        if (totalAmount == 0) return;

        try jarManager.emergencyWithdraw(jarId) {
            ghost_totalWithdrawn += jar.principalDeposited;
            ghost_totalYieldClaimed += pendingYield;
            actorDepositedAmount[currentActor] -= jar.principalDeposited;
        } catch {
            // Ignore emergency withdraw failures
        }
    }

    /// @notice Multiple deposits from the same actor
    function multiDeposit(uint256 actorSeed, uint256 jarIndexSeed, uint8 count) external useActor(actorSeed) {
        count = uint8(bound(count, 1, 5));

        if (actorJars[currentActor].length == 0) {
            try jarManager.createJar("Multi Deposit Jar", MAX_AMOUNT) returns (uint256 jarId) {
                actorJars[currentActor].push(jarId);
                ghost_jarCount++;
            } catch {
                return;
            }
        }

        uint256 jarIndex = bound(jarIndexSeed, 0, actorJars[currentActor].length - 1);
        uint256 jarId = actorJars[currentActor][jarIndex];

        for (uint256 i = 0; i < count; i++) {
            uint256 amount = bound(uint256(keccak256(abi.encode(i, jarId))), MIN_AMOUNT, MAX_AMOUNT / 10);
            
            uint256 balance = usdc.balanceOf(currentActor);
            if (balance < amount) break;

            try jarManager.deposit(jarId, amount) {
                ghost_totalDeposited += amount;
                ghost_depositCount++;
                actorDepositedAmount[currentActor] += amount;
            } catch {
                break;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all jar IDs for an actor
    /// @param actor The address of the actor
    /// @return Array of jar IDs owned by the actor
    function getActorJars(address actor) external view returns (uint256[] memory) {
        return actorJars[actor];
    }

    /// @notice Get total number of active jars across all actors
    function getTotalActiveJars() external view returns (uint256 count) {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = actorJars[actors[i]];
            for (uint256 j = 0; j < jars.length; j++) {
                JarManager.Jar memory jar = jarManager.getJar(actors[i], jars[j]);
                if (jar.isActive) count++;
            }
        }
    }

    /// @notice Calculate sum of all jar balances
    function getSumOfAllJarBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = actorJars[actors[i]];
            for (uint256 j = 0; j < jars.length; j++) {
                JarManager.Jar memory jar = jarManager.getJar(actors[i], jars[j]);
                sum += jar.principalDeposited;
            }
        }
    }

    /// @notice Calculate sum of all jar shares
    function getSumOfAllJarShares() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = actorJars[actors[i]];
            for (uint256 j = 0; j < jars.length; j++) {
                JarManager.Jar memory jar = jarManager.getJar(actors[i], jars[j]);
                sum += jar.shares;
            }
        }
    }

    /// @notice Calculate sum of all pending jar yield using accYieldPerShare
    function getSumOfAllPendingYield() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory jars = actorJars[actors[i]];
            for (uint256 j = 0; j < jars.length; j++) {
                sum += jarManager.calculateCurrentYield(actors[i], jars[j]);
            }
        }
    }
}
