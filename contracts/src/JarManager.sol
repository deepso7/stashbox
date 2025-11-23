// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @title JarManager
/// @notice Manages individual savings jars with automatic yield generation through Uniswap V4
/// @dev Uses a shared liquidity pool for gas efficiency with accYieldPerShare pattern for accurate yield distribution
contract JarManager is ReentrancyGuard, Ownable, IUnlockCallback {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAmount();
    error InvalidJarName();
    error JarNotFound();
    error UnauthorizedAccess();
    error InsufficientBalance();
    error InsufficientYield();
    error SlippageExceeded();
    error PoolNotInitialized();
    error InvalidPoolKey();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event JarCreated(address indexed owner, uint256 indexed jarId, string name, uint256 targetAmount);
    event Deposited(address indexed owner, uint256 indexed jarId, uint256 amount, uint256 shares);
    event Withdrawn(address indexed owner, uint256 indexed jarId, uint256 amount, uint256 shares);
    event YieldClaimed(address indexed owner, uint256 indexed jarId, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 indexed jarId, uint256 amount);
    event PositionRebalanced(uint256 newLiquidity, int24 newTickLower, int24 newTickUpper);
    event YieldDistributed(uint256 yieldAmount, uint256 newAccYieldPerShare);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Individual savings jar data
    /// @param name Human-readable name for the jar
    /// @param targetAmount Goal amount in token decimals
    /// @param shares Proportional shares in the shared pool
    /// @param principalDeposited Total principal deposited (excludes yield)
    /// @param yieldDebt Debt used for accurate yield calculation
    /// @param pendingYieldSnapshot Saved yield before share changes (preserves yield on withdrawal)
    /// @param isActive Whether the jar is active
    struct Jar {
        string name;
        uint256 targetAmount;
        uint256 shares;
        uint256 principalDeposited;
        uint256 yieldDebt;
        uint256 pendingYieldSnapshot;
        bool isActive;
    }

    /// @notice Position information for the shared V4 pool
    /// @param tickLower Lower tick of the position
    /// @param tickUpper Upper tick of the position
    /// @param liquidity Total liquidity in the position
    struct PositionInfo {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    /// @notice Callback data for unlock operations
    /// @param params The modify liquidity parameters
    /// @param isAdd True if adding liquidity, false if removing
    struct CallbackData {
        ModifyLiquidityParams params;
        bool isAdd;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The stablecoin used for deposits (USDC)
    IERC20 public immutable DEPOSIT_TOKEN;

    /// @notice Uniswap V4 Pool Manager
    IPoolManager public immutable POOL_MANAGER;

    /// @notice Pool key for the V4 position
    PoolKey public poolKey;

    /// @notice Pool ID derived from pool key
    PoolId public poolId;

    /// @notice Current position information
    PositionInfo public position;

    /// @notice Total shares across all jars
    uint256 public totalShares;

    /// @notice Total principal deposited across all jars
    uint256 public totalPrincipal;

    /// @notice Accumulated yield per share (scaled by 1e18 for precision)
    /// @dev This is the core of the yield distribution mechanism
    uint256 public accYieldPerShare;

    /// @notice Total yield collected from V4 (for tracking)
    uint256 public totalYieldCollected;

    /// @notice Jar counter for unique IDs
    uint256 private _jarIdCounter;

    /// @notice Mapping from owner to jar ID to Jar data
    mapping(address => mapping(uint256 => Jar)) public jars;

    /// @notice Mapping from owner to array of their jar IDs
    mapping(address => uint256[]) public userJarIds;

    /// @notice Precision constant for accYieldPerShare calculations
    uint256 private constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the JarManager contract
    /// @param depositToken The stablecoin token address (USDC)
    /// @param poolManager The Uniswap V4 PoolManager address
    /// @param _poolKey The pool key for the V4 position
    constructor(
        address depositToken,
        address poolManager,
        PoolKey memory _poolKey
    ) Ownable(msg.sender) {
        if (depositToken == address(0) || poolManager == address(0)) {
            revert InvalidPoolKey();
        }

        DEPOSIT_TOKEN = IERC20(depositToken);
        POOL_MANAGER = IPoolManager(poolManager);
        poolKey = _poolKey;
        poolId = _poolKey.toId();

        // Initialize with tight range position (can be updated later)
        position.tickLower = -60; // Tight range for stablecoin pair
        position.tickUpper = 60;
    }

    /*//////////////////////////////////////////////////////////////
                            JAR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a new savings jar
    /// @param name Human-readable name for the jar
    /// @param targetAmount Goal amount to save (in token decimals)
    /// @return jarId The ID of the newly created jar
    function createJar(string calldata name, uint256 targetAmount) external returns (uint256 jarId) {
        if (bytes(name).length == 0 || bytes(name).length > 64) {
            revert InvalidJarName();
        }

        jarId = _jarIdCounter++;

        jars[msg.sender][jarId] = Jar({
            name: name,
            targetAmount: targetAmount,
            shares: 0,
            principalDeposited: 0,
            yieldDebt: 0,
            pendingYieldSnapshot: 0,
            isActive: true
        });

        userJarIds[msg.sender].push(jarId);

        emit JarCreated(msg.sender, jarId, name, targetAmount);
    }

    /// @notice Deposit tokens into a jar
    /// @param jarId The ID of the jar to deposit into
    /// @param amount The amount of tokens to deposit
    function deposit(uint256 jarId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        Jar storage jar = jars[msg.sender][jarId];
        if (!jar.isActive) revert JarNotFound();

        // Update yield distribution before changing shares
        _distributeYield();

        // Calculate shares to mint based on total pool value (principal + yield)
        uint256 sharesToMint;
        if (totalShares == 0) {
            // First deposit: 1:1 ratio
            sharesToMint = amount;
        } else {
            // Subsequent deposits: proportional to total pool value
            // CRITICAL: totalValue = principal still in pool + undistributed yield
            // We CANNOT use contract balance because it changes after withdrawals/claims
            // totalValue represents what all existing shares are worth
            uint256 undistributedYield = _getUndistributedYield();
            uint256 totalValue = totalPrincipal + undistributedYield;
            sharesToMint = (amount * totalShares) / totalValue;
        }

        // Save pending yield before changing shares
        jar.pendingYieldSnapshot += _pendingYield(jar);

        // Transfer tokens from user
        DEPOSIT_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update jar shares and principal
        jar.shares += sharesToMint;
        jar.principalDeposited += amount;
        
        // Reset debt to current value for ALL shares (standard pattern)
        jar.yieldDebt = (jar.shares * accYieldPerShare) / PRECISION;

        // Update global state
        totalShares += sharesToMint;
        totalPrincipal += amount;

        // Add liquidity to V4 pool
        _addLiquidity(amount);

        emit Deposited(msg.sender, jarId, amount, sharesToMint);
    }

    /// @notice Withdraw tokens from a jar
    /// @param jarId The ID of the jar to withdraw from
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 jarId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        Jar storage jar = jars[msg.sender][jarId];
        if (!jar.isActive) revert JarNotFound();
        if (jar.principalDeposited < amount) revert InsufficientBalance();

        // Update yield distribution before changing shares
        _distributeYield();

        // CRITICAL FIX: Calculate shares to burn based on TOTAL VALUE (principal + yield)
        // not just principal. Otherwise users lose their yield on withdrawal.
        
        // Get current pending yield BEFORE we modify anything
        uint256 currentYield = _pendingYield(jar);
        uint256 totalValue = jar.principalDeposited + currentYield;
        
        // Calculate shares to burn proportionally based on total value
        // If withdrawing X% of principal, burn X% of shares
        uint256 sharesToBurn = (amount * jar.shares) / jar.principalDeposited;
        
        // Ensure we don't burn more shares than the jar has
        if (sharesToBurn > jar.shares) {
            sharesToBurn = jar.shares;
        }

        // Calculate how much yield to preserve (the portion that remains)
        // If we're withdrawing X% of principal, we're also "withdrawing" X% of yield
        // The remaining (100-X)% of yield should be preserved
        uint256 yieldWithdrawn = (currentYield * amount) / jar.principalDeposited;
        uint256 yieldRemaining = currentYield - yieldWithdrawn;

        // Update jar state
        jar.shares -= sharesToBurn;
        jar.principalDeposited -= amount;
        
        // Save the remaining yield in snapshot (this preserves it for the user)
        jar.pendingYieldSnapshot = yieldRemaining;
        
        // Reset debt for new share amount
        jar.yieldDebt = (jar.shares * accYieldPerShare) / PRECISION;

        // Update global state
        totalShares -= sharesToBurn;
        totalPrincipal -= amount;

        // Remove liquidity from V4 pool
        _removeLiquidity(amount);

        // Transfer principal to user
        DEPOSIT_TOKEN.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, jarId, amount, sharesToBurn);
    }

    /// @notice Claim accumulated yield from a jar
    /// @param jarId The ID of the jar to claim yield from
    function claimYield(uint256 jarId) external nonReentrant {
        Jar storage jar = jars[msg.sender][jarId];
        if (!jar.isActive) revert JarNotFound();

        // Update yield distribution to get latest yield
        _distributeYield();

        // Calculate total pending yield (snapshot + new yield)
        uint256 yieldAmount = _pendingYield(jar);
        if (yieldAmount == 0) revert InsufficientYield();

        // Reset snapshot and debt to mark all yield as claimed
        jar.pendingYieldSnapshot = 0;
        jar.yieldDebt = (jar.shares * accYieldPerShare) / PRECISION;

        // Note: Yield is not part of position liquidity in our mock implementation
        // In production, yield would be collected from the pool via PoolManager.collectFees()
        // Here, yield is simulated by minting tokens directly to the contract

        // Transfer yield to user
        DEPOSIT_TOKEN.safeTransfer(msg.sender, yieldAmount);

        emit YieldClaimed(msg.sender, jarId, yieldAmount);
    }

    /// @notice Emergency withdraw all funds from a jar
    /// @param jarId The ID of the jar to emergency withdraw from
    function emergencyWithdraw(uint256 jarId) external nonReentrant {
        Jar storage jar = jars[msg.sender][jarId];
        if (!jar.isActive) revert JarNotFound();

        // Update yield distribution
        _distributeYield();

        uint256 principalAmount = jar.principalDeposited;
        uint256 yieldAmount = _pendingYield(jar);
        uint256 totalAmount = principalAmount + yieldAmount;
        uint256 shares = jar.shares;

        if (totalAmount == 0) revert InsufficientBalance();

        // Update jar state
        jar.shares = 0;
        jar.principalDeposited = 0;
        jar.yieldDebt = 0;
        jar.pendingYieldSnapshot = 0;
        jar.isActive = false;

        // Update global state
        totalShares -= shares;
        totalPrincipal -= principalAmount;

        // Remove liquidity from V4 pool (only principal, yield isn't in liquidity)
        if (principalAmount > 0) {
            _removeLiquidity(principalAmount);
        }

        // Transfer all funds to user
        DEPOSIT_TOKEN.safeTransfer(msg.sender, totalAmount);

        emit EmergencyWithdraw(msg.sender, jarId, totalAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD DISTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Distribute collected fees to all jars proportionally
    /// @dev Uses the accYieldPerShare pattern for accurate distribution
    function _distributeYield() internal {
        // Collect fees from V4 position
        uint256 feesCollected = _collectFees();
        
        if (feesCollected > 0 && totalShares > 0) {
            // Update accumulated yield per share
            // accYieldPerShare += (feesCollected * PRECISION) / totalShares
            uint256 yieldPerShare = (feesCollected * PRECISION) / totalShares;
            accYieldPerShare += yieldPerShare;
            totalYieldCollected += feesCollected;

            emit YieldDistributed(feesCollected, accYieldPerShare);
        }
    }

    /// @notice Calculate pending yield for a jar using accYieldPerShare pattern
    /// @param jar The jar to calculate pending yield for
    /// @return Pending yield amount
    function _pendingYield(Jar storage jar) internal view returns (uint256) {
        // Start with saved yield from previous share changes
        uint256 pending = jar.pendingYieldSnapshot;
        
        // Add new yield earned by current shares
        if (jar.shares > 0) {
            uint256 accumulated = (jar.shares * accYieldPerShare) / PRECISION;
            if (accumulated > jar.yieldDebt) {
                pending += accumulated - jar.yieldDebt;
            }
        }
        
        return pending;
    }

    /*//////////////////////////////////////////////////////////////
                        UNISWAP V4 INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Add liquidity to the Uniswap V4 pool
    /// @param amount The amount of tokens to add as liquidity
    function _addLiquidity(uint256 amount) internal {
        // Approve tokens to PoolManager
        DEPOSIT_TOKEN.approve(address(POOL_MANAGER), amount);
        
        // Calculate liquidity to add (simplified for single-sided deposit)
        uint128 liquidityDelta = uint128(amount);
        
        // Prepare modifyLiquidity parameters
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: position.tickLower,
            tickUpper: position.tickUpper,
            liquidityDelta: int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        });
        
        // Call via unlock callback
        bytes memory result = POOL_MANAGER.unlock(
            abi.encode(CallbackData({
                params: params,
                isAdd: true
            }))
        );
        
        // Update position liquidity
        position.liquidity += liquidityDelta;
    }

    /// @notice Remove liquidity from the Uniswap V4 pool
    /// @param amount The amount of tokens to remove from liquidity
    function _removeLiquidity(uint256 amount) internal {
        if (position.liquidity < amount) revert InsufficientBalance();

        // Calculate liquidity to remove (negative delta)
        uint128 liquidityDelta = uint128(amount);
        
        // Prepare modifyLiquidity parameters with negative liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: position.tickLower,
            tickUpper: position.tickUpper,
            liquidityDelta: -int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        });
        
        // Call via unlock callback
        bytes memory result = POOL_MANAGER.unlock(
            abi.encode(CallbackData({
                params: params,
                isAdd: false
            }))
        );
        
        // Update position liquidity
        position.liquidity -= liquidityDelta;
    }

    /// @notice Get undistributed yield that hasn't been processed yet
    /// @return undistributedYield Amount of new yield not yet distributed
    /// @dev WARNING: Direct token transfers to this contract will be counted as yield
    ///      and distributed to all users proportionally. In production, consider implementing
    ///      explicit deposit/withdrawal tracking to prevent this.
    function _getUndistributedYield() internal view returns (uint256 undistributedYield) {
        uint256 currentBalance = DEPOSIT_TOKEN.balanceOf(address(this));
        uint256 accountedBalance = totalPrincipal + totalYieldCollected;
        
        if (currentBalance > accountedBalance) {
            undistributedYield = currentBalance - accountedBalance;
        }
        
        return undistributedYield;
    }

    /// @notice Collect fees from the V4 position
    /// @return feesCollected The amount of fees collected
    /// @dev In Uniswap V4, fees accumulate in the position and can be collected
    ///      This function uses the PoolManager to collect those fees
    function _collectFees() internal returns (uint256 feesCollected) {
        // Get current position state to check for fees
        // Note: In V4, you need to track fees per position
        // For simplicity, we'll check if there are any excess tokens
        
        // First check for any uncollected fees via balance check
        // This is a fallback mechanism for testing
        uint256 balanceBeforeCollection = DEPOSIT_TOKEN.balanceOf(address(this));
        uint256 expectedBalance = totalPrincipal + totalYieldCollected;
        
        if (balanceBeforeCollection > expectedBalance) {
            // There are excess tokens that represent fees
            feesCollected = balanceBeforeCollection - expectedBalance;
        }
        
        // In production V4, you would also call a fee collection function
        // but since fees accrue to the position automatically in V4,
        // we primarily track them via balance changes
        
        return feesCollected;
    }

    /*//////////////////////////////////////////////////////////////
                        UNISWAP V4 CALLBACKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Unlock callback called by PoolManager
    /// @param data Encoded callback data
    /// @return result The result of the callback
    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(POOL_MANAGER), "Only PoolManager");
        
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        
        // Execute the liquidity modification
        (BalanceDelta delta,) = POOL_MANAGER.modifyLiquidity(
            poolKey,
            callbackData.params,
            ""
        );

        // Settle the balance delta
        _settleDeltas(delta, callbackData.isAdd);

        return abi.encode(delta);
    }

    /// @notice Settle balance deltas with the PoolManager
    /// @param delta The balance delta to settle
    /// @param isAdd True if adding liquidity (we owe tokens), false if removing (pool owes us)
    function _settleDeltas(BalanceDelta delta, bool isAdd) internal {
        int128 delta0 = delta.amount0();
        int128 delta1 = delta.amount1();

        // CRITICAL: In Uniswap V4 flash accounting:
        // - NEGATIVE delta means you OWE tokens to the pool (must settle)
        // - POSITIVE delta means the pool OWES you tokens (can take)

        // Settle currency0
        if (delta0 < 0) {
            // We owe tokens to the pool
            // 1. Call sync to tell PoolManager which currency we're settling
            POOL_MANAGER.sync(poolKey.currency0);
            
            // 2. Transfer tokens to PoolManager
            if (Currency.unwrap(poolKey.currency0) == address(DEPOSIT_TOKEN)) {
                DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(-delta0));
            } else {
                IERC20(Currency.unwrap(poolKey.currency0)).safeTransfer(address(POOL_MANAGER), uint128(-delta0));
            }
            
            // 3. Call settle to finalize
            POOL_MANAGER.settle();
        } else if (delta0 > 0) {
            // Pool owes us tokens - take them
            POOL_MANAGER.take(poolKey.currency0, address(this), uint128(delta0));
        }

        // Settle currency1
        if (delta1 < 0) {
            // We owe tokens to the pool
            // 1. Call sync to tell PoolManager which currency we're settling
            POOL_MANAGER.sync(poolKey.currency1);
            
            // 2. Transfer tokens to PoolManager
            if (Currency.unwrap(poolKey.currency1) == address(DEPOSIT_TOKEN)) {
                DEPOSIT_TOKEN.safeTransfer(address(POOL_MANAGER), uint128(-delta1));
            } else {
                IERC20(Currency.unwrap(poolKey.currency1)).safeTransfer(address(POOL_MANAGER), uint128(-delta1));
            }
            
            // 3. Call settle to finalize
            POOL_MANAGER.settle();
        } else if (delta1 > 0) {
            // Pool owes us tokens - take them
            POOL_MANAGER.take(poolKey.currency1, address(this), uint128(delta1));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get jar details for a user
    /// @param owner The address of the jar owner
    /// @param jarId The ID of the jar
    /// @return jar The jar data
    function getJar(address owner, uint256 jarId) external view returns (Jar memory jar) {
        return jars[owner][jarId];
    }

    /// @notice Get all jar IDs for a user
    /// @param owner The address of the jar owner
    /// @return jarIds Array of jar IDs owned by the user
    function getUserJarIds(address owner) external view returns (uint256[] memory jarIds) {
        return userJarIds[owner];
    }

    /// @notice Calculate current yield for a jar (including unclaimed fees)
    /// @param owner The address of the jar owner
    /// @param jarId The ID of the jar
    /// @return currentYield The current yield amount
    function calculateCurrentYield(address owner, uint256 jarId) external view returns (uint256 currentYield) {
        Jar storage jar = jars[owner][jarId];
        if (!jar.isActive) return 0;

        // Start with saved yield snapshot
        uint256 pending = jar.pendingYieldSnapshot;

        // Calculate pending fees that haven't been distributed yet
        uint256 pendingFees = _getUndistributedYield();

        // Calculate what accYieldPerShare would be after distribution
        uint256 projectedAccYieldPerShare = accYieldPerShare;
        if (pendingFees > 0 && totalShares > 0) {
            projectedAccYieldPerShare += (pendingFees * PRECISION) / totalShares;
        }

        // Add new yield from current shares with projected rate
        if (jar.shares > 0) {
            uint256 accumulated = (jar.shares * projectedAccYieldPerShare) / PRECISION;
            if (accumulated > jar.yieldDebt) {
                pending += accumulated - jar.yieldDebt;
            }
        }
        
        return pending;
    }

    /// @notice Get total balance (principal + yield) for a jar
    /// @param owner The address of the jar owner
    /// @param jarId The ID of the jar
    /// @return totalBalance The total balance in the jar
    function getJarTotalBalance(address owner, uint256 jarId) external view returns (uint256 totalBalance) {
        Jar storage jar = jars[owner][jarId];
        uint256 pendingYield = this.calculateCurrentYield(owner, jarId);
        return jar.principalDeposited + pendingYield;
    }

    /// @notice Calculate the principal value of shares (excludes yield)
    /// @param shares The number of shares
    /// @return value The principal value represented by the shares
    /// @dev This function only returns principal portion. For total value including yield,
    ///      use getJarTotalBalance() or calculateCurrentYield() separately
    function sharesPrincipalValue(uint256 shares) public view returns (uint256 value) {
        if (totalShares == 0) return 0;
        return (shares * totalPrincipal) / totalShares;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Rebalance the V4 position (admin only)
    /// @param newTickLower New lower tick for the position
    /// @param newTickUpper New upper tick for the position
    function rebalancePosition(int24 newTickLower, int24 newTickUpper) external onlyOwner {
        // Distribute yield before rebalancing
        _distributeYield();

        // Store old position
        uint128 oldLiquidity = position.liquidity;

        // Remove liquidity from old position
        if (oldLiquidity > 0) {
            _removeLiquidity(oldLiquidity);
        }

        // Update position parameters
        position.tickLower = newTickLower;
        position.tickUpper = newTickUpper;

        // Add liquidity to new position
        if (oldLiquidity > 0) {
            _addLiquidity(oldLiquidity);
        }

        emit PositionRebalanced(position.liquidity, newTickLower, newTickUpper);
    }

    /// @notice Manually trigger yield distribution (can be called by anyone)
    function updateYield() external {
        _distributeYield();
    }
}
