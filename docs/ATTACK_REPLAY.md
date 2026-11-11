# GHOST - Attack Replay (v6 to v7.2)

Date: 2026-11-10

## The Story

In v6, an attacker could drain USDC from the pool. In v7.2, the same attack gains zero.

## v6 Vulnerability

### Root Cause

In v6, `executeFill()` transferred USDC immediately to the caller.

### Attack Vector

1. Attacker sees an active intent (User locked 1 USDC in Pool)
2. Attacker calls executeFill(intentId) directly
3. USDC transferred to attacker immediately
4. User never receives USDC on destination chain
5. User's 1 USDC is gone

### On-Chain Evidence

Attack TX: 0x0d76... (v6 testnet)
- Attacker: +400 units (test amount)
- Victim: -1 USDC
- Pool: drained
- Result: VULNERABLE

## v7.2 Fix

### Design Change

v7.2 splits fill and transfer:

1. executeFill() records filled=true only (no USDC move)
2. claim() releases USDC only after user signature

### Why It Works

1. Attacker calls executeFill - gains nothing
2. USDC stays in Pool
3. Only User signature triggers claim
4. If User never sees USDC on destination - never signs - funds stuck in Pool
5. After 7 days - sweepStuck - Treasury (not attacker)

### On-Chain Evidence

Attack Replay TX: 0x988607b5... (v7.2 testnet)
- Attacker: 0 (gained nothing)
- User: unchanged
- Pool: retained (1 USDC)
- Attacker lost gas only
- Result: PROTECTED

## Comparison

| Aspect | v6 | v7.2 |
|--------|----|----- |
| executeFill transfers USDC | Yes | No |
| Fill mechanism | Transfer + record | Record only |
| USDC release | On fill | On claim (user sig) |
| Attack success | +400 | 0 |
| User protection | None | Signature required |
| Stuck funds | No mechanism | Sweep after 7 days |

## Test Coverage

- testOriginalAttackFailsOnV7 - replays v6 attack, asserts gains 0
- testAttackerCannotClaim - fake signature reverts
- test8_WrongSigChainContractReverts - wrong chain fails
- test5_CheatingRelayerLosesOnlyGas - malicious relayer loses gas

## Lessons

1. Transfer on fill is dangerous
2. User signature as gate works
3. Sweep prevents stuck funds
4. On-chain evidence > unit tests

## Timeline

- 2026-11-08: v6 vulnerable (TX 0x0d76)
- 2026-11-09: v7.2 deployed with fix
- 2026-11-09: Attack replay (TX 0x988607b5) - attacker gains 0
- 2026-11-10: v7.3-minimal (InvalidSignature error only)
✅ copiedcat

## Comparison

| Aspect | v6 | v7.2 |
|--------|----|----- |
| executeFill transfers USDC | Yes | No |
| Fill mechanism | Transfer + record | Record only |
| USDC release | On fill | On claim (user sig) |
| Attack success | +400 | 0 |
| User protection | None | Signature required |
| Stuck funds | No mechanism | Sweep after 7 days |

## Test Coverage

- testOriginalAttackFailsOnV7 - replays v6 attack, asserts gains 0
- testAttackerCannotClaim - fake signature reverts
- test8_WrongSigChainContractReverts - wrong chain fails
- test5_CheatingRelayerLosesOnlyGas - malicious relayer loses gas

## Lessons

1. Transfer on fill is dangerous
2. User signature as gate works
3. Sweep prevents stuck funds
4. On-chain evidence > unit tests

## Timeline

- 2026-11-08: v6 vulnerable (TX 0x0d76)
- 2026-11-09: v7.2 deployed with fix
- 2026-11-09: Attack replay (TX 0x988607b5) - attacker gains 0
- 2026-11-10: v7.3-minimal (InvalidSignature error only)
