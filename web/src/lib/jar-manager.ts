import { type Address, formatUnits, parseUnits } from "viem";
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

export const JAR_MANAGER_ADDRESS: Address =
  "0x31977ed845F2B76592d6E8687E25828bfDE300a5";
export const USDC_ADDRESS: Address =
  "0x036CbD53842c5426634e7929541eC2318f3dCF7e";

export const JAR_MANAGER_ABI = [
  // View Functions
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "jarId", type: "uint256" },
    ],
    name: "getJar",
    outputs: [
      {
        components: [
          { name: "name", type: "string" },
          { name: "targetAmount", type: "uint256" },
          { name: "shares", type: "uint256" },
          { name: "principalDeposited", type: "uint256" },
          { name: "yieldDebt", type: "uint256" },
          { name: "pendingYieldSnapshot", type: "uint256" },
          { name: "isActive", type: "bool" },
        ],
        name: "jar",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "owner", type: "address" }],
    name: "getUserJarIds",
    outputs: [{ name: "jarIds", type: "uint256[]" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "jarId", type: "uint256" },
    ],
    name: "calculateCurrentYield",
    outputs: [{ name: "currentYield", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "jarId", type: "uint256" },
    ],
    name: "getJarTotalBalance",
    outputs: [{ name: "totalBalance", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalShares",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalPrincipal",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "accYieldPerShare",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalYieldCollected",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },

  // Write Functions
  {
    inputs: [
      { name: "name", type: "string" },
      { name: "targetAmount", type: "uint256" },
    ],
    name: "createJar",
    outputs: [{ name: "jarId", type: "uint256" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "jarId", type: "uint256" },
      { name: "amount", type: "uint256" },
    ],
    name: "deposit",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "jarId", type: "uint256" },
      { name: "amount", type: "uint256" },
    ],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ name: "jarId", type: "uint256" }],
    name: "claimYield",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ name: "jarId", type: "uint256" }],
    name: "emergencyWithdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "updateYield",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },

  // Events
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "jarId", type: "uint256" },
      { indexed: false, name: "name", type: "string" },
      { indexed: false, name: "targetAmount", type: "uint256" },
    ],
    name: "JarCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "jarId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "shares", type: "uint256" },
    ],
    name: "Deposited",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "jarId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "shares", type: "uint256" },
    ],
    name: "Withdrawn",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "jarId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
    name: "YieldClaimed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "owner", type: "address" },
      { indexed: true, name: "jarId", type: "uint256" },
      { indexed: false, name: "amount", type: "uint256" },
    ],
    name: "EmergencyWithdraw",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: "yieldAmount", type: "uint256" },
      { indexed: false, name: "newAccYieldPerShare", type: "uint256" },
    ],
    name: "YieldDistributed",
    type: "event",
  },
] as const;

// ERC20 ABI (for USDC approval)
export const ERC20_ABI = [
  {
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

export function useUserJarIds() {
  const { address } = useAccount();

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: "getUserJarIds",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}

// Read a single jar's data
export function useJar(jarId: bigint | undefined) {
  const { address } = useAccount();

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: "getJar",
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
    },
  });
}

export type Jar = {
  name: string;
  targetAmount: bigint;
  shares: bigint;
  principalDeposited: bigint;
  yieldDebt: bigint;
  pendingYieldSnapshot: bigint;
  isActive: boolean;
};

export interface JarWithId extends Jar {
  id: bigint;
}

export type JarDisplay = {
  id: string;
  name: string;
  targetAmount: string; // Formatted with decimals
  currentBalance: string;
  principalDeposited: string;
  yieldEarned: string;
  progress: number; // 0-100
  isActive: boolean;
};

// Read all jars for the current user
// export function useUserJars() {
//   const { address } = useAccount();
//   const { data: jarIds, isLoading: isLoadingIds } = useUserJarIds();

//   const contracts =
//     jarIds?.map((jarId) => ({
//       address: JAR_MANAGER_ADDRESS,
//       abi: JAR_MANAGER_ABI,
//       functionName: "getJar",
//       // biome-ignore lint/style/noNonNullAssertion: gg
//       args: [address!, jarId],
//     })) || [];

//   const {
//     data: jarsData,
//     isLoading: isLoadingJars,
//     refetch,
//   } = useReadContracts({
//     contracts,
//     query: {
//       enabled: !!address && !!jarIds && jarIds.length > 0,
//     },
//   });

//   const jars: JarWithId[] =
//     jarsData?.map((result, index) => ({
//       // biome-ignore lint/style/noNonNullAssertion: gg
//       id: jarIds![index],
//       ...(result.result as Jar),
//     })) || [];

//   return {
//     jars,
//     jarIds: jarIds || [],
//     isLoading: isLoadingIds || isLoadingJars,
//     refetch,
//   };
// }

// Calculate current yield for a jar
export function useJarYield(jarId: bigint | undefined) {
  const { address } = useAccount();

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: "calculateCurrentYield",
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
      refetchInterval: 10_000, // Refetch every 10 seconds
    },
  });
}

// Get jar total balance (principal + yield)
export function useJarTotalBalance(jarId: bigint | undefined) {
  const { address } = useAccount();

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: "getJarTotalBalance",
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
      refetchInterval: 10_000, // Refetch every 10 seconds
    },
  });
}

// Get USDC balance
export function useUSDCBalance() {
  const { address } = useAccount();

  return useReadContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  });
}

// Get USDC allowance for JarManager
export function useUSDCAllowance() {
  const { address } = useAccount();

  return useReadContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: address ? [address, JAR_MANAGER_ADDRESS] : undefined,
    query: {
      enabled: !!address,
    },
  });
}

export function useFormattedJar(jarId: bigint | undefined): JarDisplay | null {
  const { data: jar } = useJar(jarId);
  const { data: totalBalance } = useJarTotalBalance(jarId);
  const { data: currentYield } = useJarYield(jarId);

  if (!(jar && jarId)) {
    return null;
  }

  const principalDeposited = Number(formatUnits(jar.principalDeposited, 6));
  const target = Number(formatUnits(jar.targetAmount, 6));
  const balance = totalBalance
    ? Number(formatUnits(totalBalance, 6))
    : principalDeposited;
  const yieldEarned = currentYield ? Number(formatUnits(currentYield, 6)) : 0;

  return {
    id: jarId.toString(),
    name: jar.name,
    targetAmount: target.toFixed(2),
    currentBalance: balance.toFixed(2),
    principalDeposited: principalDeposited.toFixed(2),
    yieldEarned: yieldEarned.toFixed(2),
    progress: target > 0 ? Math.min((balance / target) * 100, 100) : 0,
    isActive: jar.isActive,
  };
}

// Approve USDC
export function useApproveUSDC() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const approve = (amount: string) => {
    const amountWei = parseUnits(amount, 6); // USDC has 6 decimals

    writeContract({
      address: USDC_ADDRESS,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [JAR_MANAGER_ADDRESS, amountWei],
    });
  };

  return {
    approve,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

// Create a new jar
export function useCreateJar() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const createJar = (name: string, targetAmount: string) => {
    const targetAmountWei = parseUnits(targetAmount, 6);

    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: "createJar",
      args: [name, targetAmountWei],
    });
  };

  return {
    createJar,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

// Deposit to jar
export function useDeposit() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const deposit = (jarId: bigint, amount: string) => {
    const amountWei = parseUnits(amount, 6);

    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: "deposit",
      args: [jarId, amountWei],
    });
  };

  return {
    deposit,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

// Withdraw from jar
export function useWithdraw() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const withdraw = (jarId: bigint, amount: string) => {
    const amountWei = parseUnits(amount, 6);

    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: "withdraw",
      args: [jarId, amountWei],
    });
  };

  return {
    withdraw,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

// Claim yield
export function useClaimYield() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const claimYield = (jarId: bigint) => {
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: "claimYield",
      args: [jarId],
    });
  };

  return {
    claimYield,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

// Emergency withdraw
export function useEmergencyWithdraw() {
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const emergencyWithdraw = (jarId: bigint) => {
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: "emergencyWithdraw",
      args: [jarId],
    });
  };

  return {
    emergencyWithdraw,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export const CONTRACT_ERRORS = {
  InvalidAmount: "Amount must be greater than 0",
  InvalidJarName: "Jar name must be 1-64 characters",
  JarNotFound: "Jar not found or inactive",
  UnauthorizedAccess: "You do not have access to this jar",
  InsufficientBalance: "Insufficient balance in jar",
  InsufficientYield: "No yield available to claim",
  SlippageExceeded: "Transaction slippage exceeded",
  PoolNotInitialized: "Pool not initialized",
  InvalidPoolKey: "Invalid pool configuration",
} as const;

// biome-ignore lint/suspicious/noExplicitAny: gg
export function parseContractError(error: any): string {
  const errorMessage = error?.message || error?.toString() || "";

  // Check for known contract errors
  for (const [key, message] of Object.entries(CONTRACT_ERRORS)) {
    if (errorMessage.includes(key)) {
      return message;
    }
  }

  // Check for common wagmi/viem errors
  if (errorMessage.includes("User rejected")) {
    return "Transaction was rejected";
  }

  if (errorMessage.includes("insufficient funds")) {
    return "Insufficient ETH for gas fees";
  }

  return "An error occurred. Please try again.";
}
