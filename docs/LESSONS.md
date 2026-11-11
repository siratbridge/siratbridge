# GHOST v7.3-minimal — Lessons Learned

**Date:** 2026-11-10

## Operational Lessons

### 1. Bench loops deplete one-directional balances

Arb→Base cycles burn 1.0 USDC from user's Arb balance per run; refunds arrive on Base.
10-run benchmark failed at run 9/10 with `signIntent REVERTED` — user Arb balance 0.4995 < 1.0.

Fix: pre-fund user before N runs, or alternate directions.

### 2. Nonce race on load-balanced RPC

`getTransactionCount(addr)` may return stale nonce on load-balanced RPC.
Fix: use `'pending'` blockTag.

### 3. Tor latency for Base RPC

Tor adds 500-3000ms per request. Direct publicnode RPC is faster when available.
Result: with direct publicnode, E2E p50 = 4.20s.

### 4. `cast` DOES support Base

False claim from handoff: "cast does not support Base". Verified false on 2026-11-10.
Verify assumptions before designing workarounds.

### 5. Test backup directories break forge

`test/v72-backup/` inside `test/` causes forge compilation error.
Fix: move backups outside `test/` to `archive-tests/`.

### 6. `base-provider-tor.call()` signature mismatch

`BaseProviderTor.call()` accepts object `{to, data}`, but ethers v6 expects `(address, calldata)`.
Not fixed — low priority since publicnode direct works.

## Security Lessons

### 7. v6 vulnerability discovered by attack replay

Attacker gained 400 units; victim lost 1 USDC. Root cause: `executeFill` transferred USDC to caller.
Fix (v7.2): `executeFill` records `filled=true` only. USDC moves only via `claim()` after user signature.
Verified: attack replay TX `0x988607b5...` on v7.2 → Attacker gained 0.

### 8. Anyone-can-submit claim works (and is correct)

No `msg.sender == user` guard. Signature is the gate — any wallet can submit claim if signature is from user.
Why correct: user signs after seeing USDC in wallet; whoever submits (relayer, stranger) gets nothing except registered relayer payment.
Fixed (v7.3-minimal): `InvalidRelayer` → `InvalidSignature()` for clearer error.

### 9. Double-prefix protection (EIP-191) works

Current: `keccak256("\x19Ethereum Signed Message:\n32" + keccak256(abi.encode(...)))`
Works but EIP-712 would be clearer (MetaMask shows fields).
Deferred to v7.4 — UX only, no security issue.

### 10. Receipt `gasUsed` is exact; `cast tx` shows `gasLimit`

Used `cast tx | grep gas` → got gasLimit (higher). Correct: `cast receipt | grep gasUsed`.
Impact: 5-15% difference. Documentation corrected.

### 11. L2 sequencer soft-confirmations = fast receipts

Measured: Arb Sepolia 0.27s/block, Base Sepolia 0.20s/block (vs nominal 2s).
Cause: sequencer gives receipts before L1 batch finality.
Mainnet caution: Base mainnet still ~2s — expect E2E ~4-6s not 4.2s.

### 12. p95 varies with RPC node

Runs 1-4 fast (3.7-3.9s), runs 5-8 slower (4.7-5.4s).
Cause: publicnode load balancer routes to different nodes.
Fix: RPC fallback for production — improves p95 to ~4.5s.

## Process Lessons

### 13. Don't build on assumptions

Before modification: read code, measure state, verify on-chain.
Example: `MAX_FILL_DEADLINE` — thought private; already `public constant`.

### 14. "Cheapest in the world" claims are unprovable

Alternatives:
- "Lowest among USDC bridges in [specific class]" — provable
- "~465k gas for full transfer" — provable
- "Cheapest in the world" — needs 5+ mainnet measurements

Policy: stick to provable claims.

### 15. v7.3-minimal > v7.4-gas for current stage

v7.3-minimal: 2 lines, 25/25 tests, no API break.
v7.4-gas: ~60k gas saving, breaks API, needs re-audit.
Decision: ship v7.3-minimal, defer v7.4-gas.

## What We'd Do Differently

1. Fuzz tests from day 1
2. Formal verification (Certora/Halmos)
3. Multi-relayer from start
4. Balance pre-checks in bot
5. Test backup outside `test/`
6. RPC fallback for p95
