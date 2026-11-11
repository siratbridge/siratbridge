# GHOST — Changelog

All notable changes to this project.

**Current:** v7.3-minimal (local, not deployed)
**Deployed:** v7.2 (Arb Sepolia + Base Sepolia)

---

## v7.3-minimal — 2026-11-10

**Status:** Local only (not deployed)

### Changed
- `GhostPoolV7.claim()`: `InvalidRelayer()` → `InvalidSignature()` for accurate error naming
- Added `error InvalidSignature()` to `GhostPoolV7`

### Not changed
- API unchanged
- Storage layout unchanged
- Gas usage unchanged
- All 25 tests pass

### Why not deployed
- v7.2 already deployed, tested (27 E2E runs), documented
- v7.3-minimal is a JQ improvement only (clearer error)
- Deployment would require new addresses without functional gain

---

## v7.2 — 2026-11-09

**Status:** Deployed on Arb Sepolia + Base Sepolia

### Changed
- **Critical:** `GhostExecutorV7.executeFill()` no longer transfers USDC. Only records `filled=true`
- USDC release moved exclusively to `claim()` after user signature
- `sweepStuck()` added: after 7 days from deadline, unclaimed USDC → Treasury

### Fixed
- v6 vulnerability: attacker could call executeFill and drain USDC
- Attack replay verified: TX `0x988607b5...` → attacker gains 0

### Added
- Sweep protection (4 tests)
- `MAX_ACTIVE_INTENTS = 10` per user
- `IntentSigned` event includes all intent fields

### Tests
- 25/25 passing (12 + 8 + 1 + 4)
- E2E Arb→Base: 5 TXs verified on-chain
- E2E Base→Arb: 5 TXs verified on-chain

### Measured
- p50 E2E: 4.20s (n=27)
- p95 E2E: 5.07s
- Gas: signIntent 215k, executeFill 85k, claim 100k (Arb)

---

## v7.0 / v7.1 — 2026-11-09 (superseded by v7.2)

### Added
- Intent-based escrow (signIntent, executeIntent)
- User-signed receipt for claim
- Cross-chain design (Arb + Base)

### Fixed
- Various bugs from v6 iteration

### Status
- Superseded by v7.2 (v7.0/v7.1 had issues fixed in v7.2)

---

## v6 — 2026-11-08 (vulnerable, do not use)

**Status:** VULNERABLE — deprecated

### Vulnerability
- `executeFill` transferred USDC immediately to caller
- Attacker could drain pool without user receiving on destination
- Attack TX: `0x0d76...` → attacker +400 units, victim -1 USDC

### Impact
- Critical security issue
- Funds could be stolen

### Fix
- Superseded by v7.2 (executeFill no longer transfers)

---

## v4 / v5 — 2026-11-07 (early prototypes)

### Notes
- Pre-intent model
- Various designs explored
- Not security-reviewed
- Superseded by v6+

---

## Version History

| Version | Date | Status | Notes |
|---------|------|--------|-------|
| v7.3-minimal | 2026-11-10 | Local | InvalidSignature error |
| v7.2 | 2026-11-09 | Deployed | v6 fix, sweep, E2E both dirs |
| v7.1 | 2026-11-09 | Superseded | Minor fixes |
| v7.0 | 2026-11-09 | Superseded | First intent-based |
| v6 | 2026-11-08 | VULNERABLE | executeFill transfer bug |
| v4/v5 | 2026-11-07 | Prototypes | Early designs |

---

## Deployment Status

**Arb Sepolia:**
- v7.2 deployed (Pool + Executor)
- 25/25 tests passing
- 27 E2E runs (p50=4.20s)

**Base Sepolia:**
- v7.2 deployed (Pool + Executor)
- E2E both directions verified

**Mainnet:**
- Not deployed
- Requires: external audit, multi-relayer, 6+ months testnet, bug bounty
