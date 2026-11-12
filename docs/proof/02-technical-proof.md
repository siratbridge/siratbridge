# Technical Proof

**How SiratBridge works, with evidence.**

## The Flow (5 Steps)

1. **User calls `signIntent(inputAmount, outputAmount, destChainId, fillDeadline)`**
   - USDC is locked in the Pool on Arbitrum.
   - Event: `IntentSigned(intentId, user, ...)`

2. **Relayer pays USDC on Base**
   - Relayer sends `outputAmount` USDC to User on Base.
   - User sees USDC in their wallet.
   - This is a normal ERC20 transfer.

3. **User signs a receipt (EIP-191)**
   - User signs: `keccak256(intentId, chainId, pool, user, outputAmount)`.
   - No gas. No transaction. Just a signature.

4. **Relayer calls `claim(intentId, signature)` on Arbitrum**
   - Pool verifies signature.
   - Pool releases `inputAmount - treasuryFee` to relayer.
   - Pool releases `treasuryFee` to Treasury.
   - Event: `Claimed(intentId, user, relayer, amount)`

5. **After 7 days (if unsigned) → Treasury**
   - If user never signs (rare), `sweepStuck` sends USDC to Treasury.
   - Event: `Swept(intentId, amount)`

## The Evidence

### 1. Code (329 LOC)

- 85 lines: src/GhostExecutorV7.sol
- 236 lines: src/GhostPoolV7.sol
- 8 lines: src/interfaces/IERC20.sol
- 329 total

Auditable in hours, not weeks.

### 2. Tests (25/25)

- forge test
- Ran 4 test suites: 25 tests passed, 0 failed

### 3. Fills (42 on-chain)

**Arbitrum Sepolia:**
- totalFills = 41
- Explorer: sepolia.arbiscan.io/address/0xBd8c798B739FB916061e5b714E951c59Ee5A390E

**Base Sepolia:**
- totalFills = 1
- Explorer: sepolia.basescan.org/address/0xcd599a245d24585f2b23fafcfdd9ab5c20014692

### 4. CI (passing)

GitHub Actions runs forge build + forge test on every push. Status: success.

### 5. v6 Attack Replay (failed)

- TX (v6 attack): sepolia.arbiscan.io/tx/0x0d76...
- TX (v7.2 replay): sepolia.arbiscan.io/tx/0x988607b5...
- Result: v7.2 attacker gained 0.

## The Contracts

### Arbitrum Sepolia (421614)

- Pool: 0xe82976502DC719ccE71dBfA28490c4138f4EaD6f
- Executor: 0xBd8c798B739FB916061e5b714E951c59Ee5A390E
- USDC: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
- Treasury: 0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487

### Base Sepolia (84532)

- Pool: 0x95867e7a139dfbe851a564f309dbdaf749145ef2
- Executor: 0xcd599a245d24585f2b23fafcfdd9ab5c20014692
- USDC: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
- Treasury: 0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487

## The Fee Model (on-chain)

- TOTAL_FEE = 50 (0.05%)
- TREASURY_FEE = 10 (0.01%)
- FEE_DENOMINATOR = 100,000
- Relayer fee = 0.04% (implicit)
- Treasury fee = 0.01%

## Read It Yourself

- Code: github.com/siratbridge/siratbridge/tree/main/src
- Tests: github.com/siratbridge/siratbridge/tree/main/test
- Whitepaper: github.com/siratbridge/siratbridge/blob/main/docs/WHITEPAPER.md
