# GHOST v7.3-minimal — Handoff

**Date:** 2026-11-10
**Current version (local):** v7.3-minimal
**Deployed version:** v7.2 (Arb Sepolia + Base Sepolia)

## Where We Are

- v7.2 deployed, tested (27 E2E runs, 25 tests)
- v7.3-minimal ready locally (2-line change, JQ improvement)
- Docs complete
- Mainnet not yet ready (needs audit + multi-relayer + fuzz)

## Live Deployments

### Arbitrum Sepolia (421614)
- Pool V7:     `0xe82976502DC719ccE71dBfA28490c4138f4EaD6f`
- Executor V7: `0xBd8c798B739FB916061e5b714E951c59Ee5A390E`
- USDC:        `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

### Base Sepolia (84532)
- Pool V7:     `0x95867e7a139dfbe851a564f309dbdaf749145ef2`
- Executor V7: `0xcd599a245d24585f2b23fafcfdd9ab5c20014692`
- USDC:        `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

### Shared
- Treasury: `0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487`

## What Works

### Tests
- 25/25 forge tests pass
- Coverage: happy path, attack replay, sweep, refund, double-spend, fee validation

### E2E
- Arb → Base: 5 TXs verified on-chain
- Base → Arb: 5 TXs verified on-chain
- p50 = 4.20s (n=27 runs)
- p95 = 5.07s

### Security
- v6 attack replay fails on v7.2 (TX `0x988607b5...`, attacker gains 0)
- Anyone-can-submit claim (signature is the gate)
- Sweep protection (unclaimed → Treasury after 7 days)

### Measurements
- Arb block time: 0.27s
- Base block time: 0.20s
- Gas (Arb): signIntent 215k, executeFill 85k, claim 100k
- Gas (Base): signIntent 233k, executeFill 137k, claim 96k

## v7.3-minimal (local only)

**Diff from v7.2:**
- Added `error InvalidSignature()` in GhostPoolV7
- `claim()`: `InvalidRelayer()` → `InvalidSignature()`

**Why not deployed:**
- JQ improvement only
- v7.2 already deployed + tested + documented
- New deployment would need new addresses without functional gain

## What's Missing (Before Mainnet)

### Critical
- [ ] External security audit (Spearbit/Pashov/Trail of Bits)
- [ ] Fuzz tests (1000+ random cases)
- [ ] Invariant tests (5+ invariants)
- [ ] Multi-relayer infrastructure
- [ ] 6+ months testnet operation
- [ ] Bug bounty program

### Important
- [ ] RPC fallback (improve p95 to ~4.5s)
- [ ] Monitoring + alerts
- [ ] forge verify on Arbiscan + BaseScan
- [ ] Separate addresses (User ≠ Treasury ≠ Relayer)

### Nice to have
- [ ] EIP-712 typed signing (v7.4)
- [ ] Frontend UI (React + wallet connect)
- [ ] Relayer API service
- [ ] Multi-chain deployment (OP, Polygon, zkSync)

## Known Limitations

- **USDC only** — no other tokens
- **2 chains** — Arb + Base only
- **Single relayer** — point of failure
- **No monitoring** — no alerts if bot stops
- **No formal verification** — relies on tests
- **Testnet only** — no mainnet deployment

## Pending (Sweep)

- Intent `0x5935...` on Arb (Treasury's own intent, filled, unclaimed)
- `fillDeadline = 1,794,233,853`
- `sweepStuck` available after: `+ 604800 = 1,794,838,653`
- **Date:** 2026-11-17 ~06:17 UTC

## Rules (STRICT)

1. No changes before on-chain diagnosis
2. No guessing — cast/forge/grep/curl only
3. One step at a time
4. 100% honesty — no "probably" without flag
5. On failure — diagnose with evidence (TX hash, revert data)

## Backup Locations

- `~/ghost-v4-v7.3-minimal-2026-11-10_22-22.tar.gz` (12MB)
- `~/ghost-clean-2026-11-09_23-03/` (17 files + lib)
- `~/ghost-v4/src/GhostPoolV7.sol.v73_final` (v7.3-minimal)
- `~/ghost-v4/src/GhostPoolV7.sol.v73_minimal_bak` (v7.2)
