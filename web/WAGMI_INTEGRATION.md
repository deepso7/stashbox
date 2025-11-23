# JarManager Contract Integration with Wagmi

Complete guide for integrating the JarManager smart contract with wagmi in your React application.

## Table of Contents

1. [Contract Information](#contract-information)
2. [Setup](#setup)
3. [Contract ABI](#contract-abi)
4. [React Hooks](#react-hooks)
5. [Usage Examples](#usage-examples)
6. [TypeScript Types](#typescript-types)
7. [Error Handling](#error-handling)

---

## Contract Information

**Network:** Base Sepolia (Chain ID: 84532)  
**Contract Address:** `0x31977ed845F2B76592d6E8687E25828bfDE300a5`  
**Verified:** https://sepolia.basescan.org/address/0x31977ed845f2b76592d6e8687e25828bfde300a5

**Deposit Token (USDC):** `0x036CbD53842c5426634e7929541eC2318f3dCF7e`  
**Pool Manager:** `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`

---

## Setup

### 1. Install Dependencies

```bash
npm install wagmi viem @tanstack/react-query
# or
pnpm add wagmi viem @tanstack/react-query
# or
bun add wagmi viem @tanstack/react-query
```

### 2. Configure Wagmi

```typescript
// src/lib/wagmi-config.ts
import { createConfig, http } from 'wagmi'
import { baseSepolia } from 'wagmi/chains'
import { coinbaseWallet, injected, walletConnect } from 'wagmi/connectors'

export const config = createConfig({
  chains: [baseSepolia],
  connectors: [
    injected(),
    coinbaseWallet({ appName: 'StashBox' }),
    walletConnect({ projectId: 'YOUR_PROJECT_ID' }),
  ],
  transports: {
    [baseSepolia.id]: http(),
  },
})
```

### 3. Setup Wagmi Provider

```typescript
// src/App.tsx or src/main.tsx
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './lib/wagmi-config'

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {/* Your app */}
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

---

## Contract ABI

Create a file for the contract ABI and constants:

```typescript
// src/lib/contracts/jar-manager.ts
import { Address } from 'viem'

export const JAR_MANAGER_ADDRESS: Address = '0x31977ed845F2B76592d6E8687E25828bfDE300a5'
export const USDC_ADDRESS: Address = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'

export const JAR_MANAGER_ABI = [
  // View Functions
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'jarId', type: 'uint256' }
    ],
    name: 'getJar',
    outputs: [
      {
        components: [
          { name: 'name', type: 'string' },
          { name: 'targetAmount', type: 'uint256' },
          { name: 'shares', type: 'uint256' },
          { name: 'principalDeposited', type: 'uint256' },
          { name: 'yieldDebt', type: 'uint256' },
          { name: 'pendingYieldSnapshot', type: 'uint256' },
          { name: 'isActive', type: 'bool' }
        ],
        name: 'jar',
        type: 'tuple'
      }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ name: 'owner', type: 'address' }],
    name: 'getUserJarIds',
    outputs: [{ name: 'jarIds', type: 'uint256[]' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'jarId', type: 'uint256' }
    ],
    name: 'calculateCurrentYield',
    outputs: [{ name: 'currentYield', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'jarId', type: 'uint256' }
    ],
    name: 'getJarTotalBalance',
    outputs: [{ name: 'totalBalance', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'totalShares',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'totalPrincipal',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'accYieldPerShare',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'totalYieldCollected',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },

  // Write Functions
  {
    inputs: [
      { name: 'name', type: 'string' },
      { name: 'targetAmount', type: 'uint256' }
    ],
    name: 'createJar',
    outputs: [{ name: 'jarId', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { name: 'jarId', type: 'uint256' },
      { name: 'amount', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { name: 'jarId', type: 'uint256' },
      { name: 'amount', type: 'uint256' }
    ],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ name: 'jarId', type: 'uint256' }],
    name: 'claimYield',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ name: 'jarId', type: 'uint256' }],
    name: 'emergencyWithdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'updateYield',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },

  // Events
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'jarId', type: 'uint256' },
      { indexed: false, name: 'name', type: 'string' },
      { indexed: false, name: 'targetAmount', type: 'uint256' }
    ],
    name: 'JarCreated',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'jarId', type: 'uint256' },
      { indexed: false, name: 'amount', type: 'uint256' },
      { indexed: false, name: 'shares', type: 'uint256' }
    ],
    name: 'Deposited',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'jarId', type: 'uint256' },
      { indexed: false, name: 'amount', type: 'uint256' },
      { indexed: false, name: 'shares', type: 'uint256' }
    ],
    name: 'Withdrawn',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'jarId', type: 'uint256' },
      { indexed: false, name: 'amount', type: 'uint256' }
    ],
    name: 'YieldClaimed',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'owner', type: 'address' },
      { indexed: true, name: 'jarId', type: 'uint256' },
      { indexed: false, name: 'amount', type: 'uint256' }
    ],
    name: 'EmergencyWithdraw',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, name: 'yieldAmount', type: 'uint256' },
      { indexed: false, name: 'newAccYieldPerShare', type: 'uint256' }
    ],
    name: 'YieldDistributed',
    type: 'event'
  }
] as const

// ERC20 ABI (for USDC approval)
export const ERC20_ABI = [
  {
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' }
    ],
    name: 'approve',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' }
    ],
    name: 'allowance',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function'
  }
] as const
```

---

## TypeScript Types

```typescript
// src/types/jar.ts
export interface Jar {
  name: string
  targetAmount: bigint
  shares: bigint
  principalDeposited: bigint
  yieldDebt: bigint
  pendingYieldSnapshot: bigint
  isActive: boolean
}

export interface JarWithId extends Jar {
  id: bigint
}

export interface JarDisplay {
  id: string
  name: string
  targetAmount: string // Formatted with decimals
  currentBalance: string
  principalDeposited: string
  yieldEarned: string
  progress: number // 0-100
  isActive: boolean
}
```

---

## React Hooks

### Custom Hooks for JarManager

```typescript
// src/hooks/use-jar-manager.ts
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { JAR_MANAGER_ADDRESS, JAR_MANAGER_ABI, USDC_ADDRESS, ERC20_ABI } from '@/lib/contracts/jar-manager'
import type { Jar, JarWithId, JarDisplay } from '@/types/jar'

// Read user's jar IDs
export function useUserJarIds() {
  const { address } = useAccount()

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: 'getUserJarIds',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })
}

// Read a single jar's data
export function useJar(jarId: bigint | undefined) {
  const { address } = useAccount()

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: 'getJar',
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
    },
  })
}

// Read all jars for the current user
export function useUserJars() {
  const { address } = useAccount()
  const { data: jarIds, isLoading: isLoadingIds } = useUserJarIds()

  const contracts = jarIds?.map((jarId) => ({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: 'getJar',
    args: [address!, jarId],
  })) || []

  const { data: jarsData, isLoading: isLoadingJars, refetch } = useReadContracts({
    contracts,
    query: {
      enabled: !!address && !!jarIds && jarIds.length > 0,
    },
  })

  const jars: JarWithId[] = jarsData?.map((result, index) => ({
    id: jarIds![index],
    ...(result.result as Jar),
  })) || []

  return {
    jars,
    jarIds: jarIds || [],
    isLoading: isLoadingIds || isLoadingJars,
    refetch,
  }
}

// Calculate current yield for a jar
export function useJarYield(jarId: bigint | undefined) {
  const { address } = useAccount()

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: 'calculateCurrentYield',
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
      refetchInterval: 10000, // Refetch every 10 seconds
    },
  })
}

// Get jar total balance (principal + yield)
export function useJarTotalBalance(jarId: bigint | undefined) {
  const { address } = useAccount()

  return useReadContract({
    address: JAR_MANAGER_ADDRESS,
    abi: JAR_MANAGER_ABI,
    functionName: 'getJarTotalBalance',
    args: address && jarId !== undefined ? [address, jarId] : undefined,
    query: {
      enabled: !!address && jarId !== undefined,
      refetchInterval: 10000, // Refetch every 10 seconds
    },
  })
}

// Get USDC balance
export function useUSDCBalance() {
  const { address } = useAccount()

  return useReadContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })
}

// Get USDC allowance for JarManager
export function useUSDCAllowance() {
  const { address } = useAccount()

  return useReadContract({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, JAR_MANAGER_ADDRESS] : undefined,
    query: {
      enabled: !!address,
    },
  })
}

// Format jar data for display
export function useFormattedJar(jarId: bigint | undefined): JarDisplay | null {
  const { data: jar } = useJar(jarId)
  const { data: totalBalance } = useJarTotalBalance(jarId)
  const { data: currentYield } = useJarYield(jarId)

  if (!jar || !jarId) return null

  const principalDeposited = Number(formatUnits(jar.principalDeposited, 6))
  const target = Number(formatUnits(jar.targetAmount, 6))
  const balance = totalBalance ? Number(formatUnits(totalBalance, 6)) : principalDeposited
  const yieldEarned = currentYield ? Number(formatUnits(currentYield, 6)) : 0

  return {
    id: jarId.toString(),
    name: jar.name,
    targetAmount: target.toFixed(2),
    currentBalance: balance.toFixed(2),
    principalDeposited: principalDeposited.toFixed(2),
    yieldEarned: yieldEarned.toFixed(2),
    progress: target > 0 ? Math.min((balance / target) * 100, 100) : 0,
    isActive: jar.isActive,
  }
}

// Get contract stats
export function useContractStats() {
  const { data } = useReadContracts({
    contracts: [
      {
        address: JAR_MANAGER_ADDRESS,
        abi: JAR_MANAGER_ABI,
        functionName: 'totalShares',
      },
      {
        address: JAR_MANAGER_ADDRESS,
        abi: JAR_MANAGER_ABI,
        functionName: 'totalPrincipal',
      },
      {
        address: JAR_MANAGER_ADDRESS,
        abi: JAR_MANAGER_ABI,
        functionName: 'totalYieldCollected',
      },
    ],
  })

  return {
    totalShares: data?.[0]?.result as bigint | undefined,
    totalPrincipal: data?.[1]?.result as bigint | undefined,
    totalYieldCollected: data?.[2]?.result as bigint | undefined,
  }
}
```

### Write Hooks

```typescript
// src/hooks/use-jar-actions.ts
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { JAR_MANAGER_ADDRESS, JAR_MANAGER_ABI, USDC_ADDRESS, ERC20_ABI } from '@/lib/contracts/jar-manager'

// Approve USDC
export function useApproveUSDC() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const approve = (amount: string) => {
    const amountWei = parseUnits(amount, 6) // USDC has 6 decimals
    
    writeContract({
      address: USDC_ADDRESS,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [JAR_MANAGER_ADDRESS, amountWei],
    })
  }

  return {
    approve,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Create a new jar
export function useCreateJar() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const createJar = (name: string, targetAmount: string) => {
    const targetAmountWei = parseUnits(targetAmount, 6)
    
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: 'createJar',
      args: [name, targetAmountWei],
    })
  }

  return {
    createJar,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Deposit to jar
export function useDeposit() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const deposit = (jarId: bigint, amount: string) => {
    const amountWei = parseUnits(amount, 6)
    
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: 'deposit',
      args: [jarId, amountWei],
    })
  }

  return {
    deposit,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Withdraw from jar
export function useWithdraw() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const withdraw = (jarId: bigint, amount: string) => {
    const amountWei = parseUnits(amount, 6)
    
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: 'withdraw',
      args: [jarId, amountWei],
    })
  }

  return {
    withdraw,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Claim yield
export function useClaimYield() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const claimYield = (jarId: bigint) => {
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: 'claimYield',
      args: [jarId],
    })
  }

  return {
    claimYield,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

// Emergency withdraw
export function useEmergencyWithdraw() {
  const { data: hash, writeContract, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const emergencyWithdraw = (jarId: bigint) => {
    writeContract({
      address: JAR_MANAGER_ADDRESS,
      abi: JAR_MANAGER_ABI,
      functionName: 'emergencyWithdraw',
      args: [jarId],
    })
  }

  return {
    emergencyWithdraw,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}
```

---

## Usage Examples

### 1. Connect Wallet

```typescript
// components/ConnectButton.tsx
import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Button } from '@/components/ui/button'

export function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <Button onClick={() => disconnect()}>
        {address?.slice(0, 6)}...{address?.slice(-4)}
      </Button>
    )
  }

  return (
    <Button onClick={() => connect({ connector: connectors[0] })}>
      Connect Wallet
    </Button>
  )
}
```

### 2. Create a Jar

```typescript
// components/CreateJarForm.tsx
import { useState } from 'react'
import { useCreateJar } from '@/hooks/use-jar-actions'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { toast } from 'sonner'

export function CreateJarForm() {
  const [name, setName] = useState('')
  const [target, setTarget] = useState('')
  const { createJar, isPending, isConfirming, isSuccess } = useCreateJar()

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!name || !target) {
      toast.error('Please fill in all fields')
      return
    }

    createJar(name, target)
  }

  if (isSuccess) {
    toast.success('Jar created successfully!')
    setName('')
    setTarget('')
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <Input
        placeholder="Jar Name (e.g., Vacation Fund)"
        value={name}
        onChange={(e) => setName(e.target.value)}
        maxLength={64}
      />
      <Input
        type="number"
        placeholder="Target Amount (USDC)"
        value={target}
        onChange={(e) => setTarget(e.target.value)}
        step="0.01"
        min="0"
      />
      <Button 
        type="submit" 
        disabled={isPending || isConfirming}
      >
        {isPending || isConfirming ? 'Creating...' : 'Create Jar'}
      </Button>
    </form>
  )
}
```

### 3. Display User's Jars

```typescript
// components/JarList.tsx
import { useUserJars } from '@/hooks/use-jar-manager'
import { Card } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { formatUnits } from 'viem'

export function JarList() {
  const { jars, isLoading } = useUserJars()

  if (isLoading) {
    return <div>Loading jars...</div>
  }

  if (jars.length === 0) {
    return <div>No jars yet. Create your first jar!</div>
  }

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {jars.map((jar) => {
        const principal = Number(formatUnits(jar.principalDeposited, 6))
        const target = Number(formatUnits(jar.targetAmount, 6))
        const progress = target > 0 ? (principal / target) * 100 : 0

        return (
          <Card key={jar.id.toString()} className="p-4">
            <h3 className="font-semibold text-lg mb-2">{jar.name}</h3>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span>Balance:</span>
                <span className="font-medium">${principal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span>Target:</span>
                <span>${target.toFixed(2)}</span>
              </div>
              <Progress value={progress} className="h-2" />
              <div className="text-xs text-muted-foreground">
                {progress.toFixed(1)}% complete
              </div>
            </div>
          </Card>
        )
      })}
    </div>
  )
}
```

### 4. Deposit to Jar

```typescript
// components/DepositForm.tsx
import { useState, useEffect } from 'react'
import { parseUnits } from 'viem'
import { useApproveUSDC, useDeposit } from '@/hooks/use-jar-actions'
import { useUSDCAllowance, useUSDCBalance } from '@/hooks/use-jar-manager'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { toast } from 'sonner'

interface DepositFormProps {
  jarId: bigint
}

export function DepositForm({ jarId }: DepositFormProps) {
  const [amount, setAmount] = useState('')
  const { data: allowance, refetch: refetchAllowance } = useUSDCAllowance()
  const { data: balance } = useUSDCBalance()
  
  const { 
    approve, 
    isPending: isApproving, 
    isSuccess: approveSuccess 
  } = useApproveUSDC()
  
  const { 
    deposit, 
    isPending: isDepositing, 
    isSuccess: depositSuccess 
  } = useDeposit()

  const needsApproval = amount && allowance 
    ? parseUnits(amount, 6) > allowance 
    : true

  useEffect(() => {
    if (approveSuccess) {
      refetchAllowance()
      toast.success('USDC approved!')
    }
  }, [approveSuccess, refetchAllowance])

  useEffect(() => {
    if (depositSuccess) {
      toast.success('Deposit successful!')
      setAmount('')
    }
  }, [depositSuccess])

  const handleApprove = () => {
    if (!amount) return
    approve(amount)
  }

  const handleDeposit = () => {
    if (!amount) return
    deposit(jarId, amount)
  }

  const maxBalance = balance ? Number(formatUnits(balance, 6)) : 0

  return (
    <div className="space-y-4">
      <div>
        <Input
          type="number"
          placeholder="Amount (USDC)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          step="0.01"
          min="0"
          max={maxBalance}
        />
        <div className="text-xs text-muted-foreground mt-1">
          Balance: ${maxBalance.toFixed(2)} USDC
        </div>
      </div>

      {needsApproval ? (
        <Button 
          onClick={handleApprove} 
          disabled={isApproving || !amount}
          className="w-full"
        >
          {isApproving ? 'Approving...' : 'Approve USDC'}
        </Button>
      ) : (
        <Button 
          onClick={handleDeposit} 
          disabled={isDepositing || !amount}
          className="w-full"
        >
          {isDepositing ? 'Depositing...' : 'Deposit'}
        </Button>
      )}
    </div>
  )
}
```

### 5. Claim Yield

```typescript
// components/ClaimYieldButton.tsx
import { useClaimYield } from '@/hooks/use-jar-actions'
import { useJarYield } from '@/hooks/use-jar-manager'
import { Button } from '@/components/ui/button'
import { formatUnits } from 'viem'
import { toast } from 'sonner'
import { useEffect } from 'react'

interface ClaimYieldButtonProps {
  jarId: bigint
}

export function ClaimYieldButton({ jarId }: ClaimYieldButtonProps) {
  const { data: yieldAmount } = useJarYield(jarId)
  const { claimYield, isPending, isConfirming, isSuccess } = useClaimYield()

  useEffect(() => {
    if (isSuccess) {
      toast.success('Yield claimed successfully!')
    }
  }, [isSuccess])

  const hasYield = yieldAmount && yieldAmount > 0n
  const yieldUSDC = yieldAmount ? formatUnits(yieldAmount, 6) : '0'

  return (
    <Button
      onClick={() => claimYield(jarId)}
      disabled={!hasYield || isPending || isConfirming}
      variant="outline"
    >
      {isPending || isConfirming 
        ? 'Claiming...' 
        : `Claim ${yieldUSDC} USDC`}
    </Button>
  )
}
```

### 6. Withdraw from Jar

```typescript
// components/WithdrawForm.tsx
import { useState, useEffect } from 'react'
import { formatUnits } from 'viem'
import { useWithdraw } from '@/hooks/use-jar-actions'
import { useJar } from '@/hooks/use-jar-manager'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { toast } from 'sonner'

interface WithdrawFormProps {
  jarId: bigint
}

export function WithdrawForm({ jarId }: WithdrawFormProps) {
  const [amount, setAmount] = useState('')
  const { data: jar } = useJar(jarId)
  const { withdraw, isPending, isSuccess } = useWithdraw()

  useEffect(() => {
    if (isSuccess) {
      toast.success('Withdrawal successful!')
      setAmount('')
    }
  }, [isSuccess])

  const maxWithdraw = jar 
    ? Number(formatUnits(jar.principalDeposited, 6)) 
    : 0

  const handleWithdraw = () => {
    if (!amount) return
    withdraw(jarId, amount)
  }

  return (
    <div className="space-y-4">
      <div>
        <Input
          type="number"
          placeholder="Amount to withdraw (USDC)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          step="0.01"
          min="0"
          max={maxWithdraw}
        />
        <div className="text-xs text-muted-foreground mt-1">
          Available: ${maxWithdraw.toFixed(2)} USDC
        </div>
      </div>

      <Button 
        onClick={handleWithdraw} 
        disabled={isPending || !amount}
        variant="destructive"
        className="w-full"
      >
        {isPending ? 'Withdrawing...' : 'Withdraw'}
      </Button>
    </div>
  )
}
```

---

## Error Handling

### Contract Error Types

```typescript
// src/lib/errors.ts
export const CONTRACT_ERRORS = {
  InvalidAmount: 'Amount must be greater than 0',
  InvalidJarName: 'Jar name must be 1-64 characters',
  JarNotFound: 'Jar not found or inactive',
  UnauthorizedAccess: 'You do not have access to this jar',
  InsufficientBalance: 'Insufficient balance in jar',
  InsufficientYield: 'No yield available to claim',
  SlippageExceeded: 'Transaction slippage exceeded',
  PoolNotInitialized: 'Pool not initialized',
  InvalidPoolKey: 'Invalid pool configuration',
} as const

export function parseContractError(error: any): string {
  const errorMessage = error?.message || error?.toString() || ''
  
  // Check for known contract errors
  for (const [key, message] of Object.entries(CONTRACT_ERRORS)) {
    if (errorMessage.includes(key)) {
      return message
    }
  }
  
  // Check for common wagmi/viem errors
  if (errorMessage.includes('User rejected')) {
    return 'Transaction was rejected'
  }
  
  if (errorMessage.includes('insufficient funds')) {
    return 'Insufficient ETH for gas fees'
  }
  
  return 'An error occurred. Please try again.'
}
```

### Error Display Component

```typescript
// components/ErrorDisplay.tsx
import { Alert, AlertDescription } from '@/components/ui/alert'
import { parseContractError } from '@/lib/errors'

interface ErrorDisplayProps {
  error: any
}

export function ErrorDisplay({ error }: ErrorDisplayProps) {
  if (!error) return null

  return (
    <Alert variant="destructive">
      <AlertDescription>
        {parseContractError(error)}
      </AlertDescription>
    </Alert>
  )
}
```

---

## Best Practices

1. **Always check allowance before deposits**: Users must approve USDC before depositing
2. **Handle loading states**: Show loading indicators during transactions
3. **Refetch data after transactions**: Update UI after successful transactions
4. **Format amounts correctly**: USDC uses 6 decimals, use `parseUnits` and `formatUnits`
5. **Handle errors gracefully**: Parse and display user-friendly error messages
6. **Use toast notifications**: Provide feedback for successful and failed transactions
7. **Poll for updates**: Use `refetchInterval` for real-time yield updates
8. **Validate inputs**: Check minimum/maximum amounts before submitting transactions

---

## Additional Resources

- [Wagmi Documentation](https://wagmi.sh)
- [Viem Documentation](https://viem.sh)
- [Base Sepolia Explorer](https://sepolia.basescan.org)
- [Contract on BaseScan](https://sepolia.basescan.org/address/0x31977ed845f2b76592d6e8687e25828bfde300a5)
