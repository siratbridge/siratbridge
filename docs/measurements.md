# GHOST v7.2 — Measured Performance (Sepolia, 2026-11-10)
> All numbers measured on-chain (receipt-based), not estimated.

## Block times
| Chain | Avg block time | Method |
|---|---|---|
| Arbitrum Sepolia | 0.27s (0.261 / 0.279) | cast block over 30s windows |
| Base Sepolia | ~0.20s (154 blk/30s, 153 blk/31s) | cast block over 30s windows |

## Gas (gasUsed from receipts)
| Operation | Arbitrum | Base |
|---|---|---|
| approve | — | 55,437 |
| signIntent | 198,641–215,741 | 232,841 |
| executeFill | 85,464–85,476 | 136,776 |
| claim | 100,663–100,687 | 95,887 |
| BasePay (relayer ERC20 transfer) | — | 45,059 |

**Selling point:** executeFill is the cheapest contract op (v7.2 removed the
transfers from executeFill — funds move only via claim with user signature).

## E2E Benchmark — bot-v3.2 (27 runs, Arb→Base, 1.0 USDC)
Optimizations vs naive bot (-51% E2E): preset gasLimit (no estimateGas),
local deadline (no getBlock calls), fees+nonces prefetched in parallel,
executeFill parallel with BasePay (3-way fork), allowance checked not re-approved.

| Metric | Value |
|---|---|
| p50 | 4,200ms |
| p95 | 5,070ms |
| min / max | 3,350ms / 5,400ms |
| success | 27 clean runs (3 failures: 1 nonce race → fixed with 'pending' blockTag; 2 USDC depletion → testnet budget) |

Segment p50: signIntent 634ms · fork max(BasePay∥executeFill) 686ms · claim 1,023ms.

## Environment
- RPCs: Arb `sepolia-rollup.arbitrum.io` (direct), Base `base-sepolia-rpc.publicnode.com`
- Receipt polling: 200ms; L2 sequencer soft-confirmations → fast receipts
- ⚠️ CONFIRMATIONS policy must be made explicit for mainnet (soft vs finalized)

## Comparison
| Protocol | p50 (est.) | v7.2 advantage |
|----------|-----------|----------------|
| CCTP Fast | ~20s | 4.8× faster |
| Across | ~20s | 4.8× faster |
| Stargate | ~45s | 10.7× faster |
| Hop | ~10min | 143× faster |

## Mainnet projections (honest)
- Base mainnet ~2s blocks raises the floor → expect E2E ~4–6s
- Bottleneck is no longer the chains: it's TX-send RTT + user signing latency
- For production: add RPC fallback to improve p95 to ~4.5s

## Lessons (2026-11-10)
- **Bench loops deplete one-directional balances**: Arb→Base cycles burn 1.0 USDC
  from Arb-side user per run; refunds arrive on Base. Fix: fund user inside wrapper
  or run balanced directions. Diagnostic habit: first suspect state that accumulates
  across runs, not code.
- **Nonce race on load-balanced RPC**: `getTransactionCount` may return stale nonce.
  Fix: use `'pending'` blockTag (implemented in bot-v3.2).
