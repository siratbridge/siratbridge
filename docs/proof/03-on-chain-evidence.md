# On-Chain Evidence

**All links go to Sepolia explorers. Verify for yourself.**

## 1. v6 Attack (Vulnerable)

- **TX:** https://sepolia.arbiscan.io/tx/0x0d76...
- **What happened:** Attacker called `executeFill` directly.
- **Result:** Attacker gained 400 units. Victim lost 1 USDC.
- **Lesson:** `executeFill` should never transfer USDC.

## 2. v7.2 Fix (Protected)

- **TX:** https://sepolia.arbiscan.io/tx/0x988607b5...
- **What happened:** Attacker replayed the same attack on v7.2.
- **Result:** Attacker gained 0. User unchanged.
- **Lesson:** `executeFill` now only records `filled=true`.

## 3. Successful Fills (42)

### Arbitrum Sepolia

- **Executor:** https://sepolia.arbiscan.io/address/0xBd8c798B739FB916061e5b714E951c59Ee5A390E
- **totalFills:** 41
- **totalVolume:** 41.0 USDC
- **Verify:** Call `getStats()` on the Executor.

### Base Sepolia

- **Executor:** https://sepolia.basescan.org/address/0xcd599a245d24585f2b23fafcfdd9ab5c20014692
- **totalFills:** 1
- **totalVolume:** 1.0 USDC
- **Verify:** Call `getStats()` on the Executor.

## 4. Contracts

### Arbitrum Sepolia (421614)

- **Pool:** https://sepolia.arbiscan.io/address/0xe82976502DC719ccE71dBfA28490c4138f4EaD6f
- **Executor:** https://sepolia.arbiscan.io/address/0xBd8c798B739FB916061e5b714E951c59Ee5A390E
- **USDC:** https://sepolia.arbiscan.io/address/0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
- **Treasury:** https://sepolia.arbiscan.io/address/0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487

### Base Sepolia (84532)

- **Pool:** https://sepolia.basescan.org/address/0x95867e7a139dfbe851a564f309dbdaf749145ef2
- **Executor:** https://sepolia.basescan.org/address/0xcd599a245d24585f2b23fafcfdd9ab5c20014692
- **USDC:** https://sepolia.basescan.org/address/0x036CbD53842c5426634e7929541eC2318f3dCF7e
- **Treasury:** https://sepolia.basescan.org/address/0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487

## 5. How to Verify (Yourself)

### Check No Admin

Run this command:

  cast call 0xe82976502DC719ccE71dBfA28490c4138f4EaD6f "owner()" --rpc-url https://sepolia-rollup.arbitrum.io/rpc

Expected: revert (no owner function).

### Check totalFills (Arb)

  cast call 0xBd8c798B739FB916061e5b714E951c59Ee5A390E "totalFills()(uint256)" --rpc-url https://sepolia-rollup.arbitrum.io/rpc

Expected: 41.

### Check Fee Constants

  cast call 0xe82976502DC719ccE71dBfA28490c4138f4EaD6f "TOTAL_FEE()(uint256)" --rpc-url https://sepolia-rollup.arbitrum.io/rpc

Expected: 50 (0.05%).

  cast call 0xe82976502DC719ccE71dBfA28490c4138f4EaD6f "TREASURY_FEE()(uint256)" --rpc-url https://sepolia-rollup.arbitrum.io/rpc

Expected: 10 (0.01%).

## 6. Links

- GitHub: https://github.com/siratbridge/siratbridge
- Whitepaper: https://github.com/siratbridge/siratbridge/blob/main/docs/WHITEPAPER.md
- Website: https://siratbridge.github.io/siratbridge/
- Twitter: https://x.com/sirat_bridge
- Discord: https://discord.gg/AKBJ3uctU
