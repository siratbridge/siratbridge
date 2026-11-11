# Ghost v7.3-minimal — Cross-Chain USDC

**Status:** Testnet (Sepolia Arb + Base), v7.2 deployed, v7.3-minimal ready locally
**Tests:** 25/25 passing
**E2E:** p50 = 4.20s (n=27 runs)
**License:** MIT

Trustless, immutable, low-gas cross-chain USDC between L2s.
No LP. No TVL. No admin. No upgrade.

## Live Contracts (Sepolia Testnet)

### Arbitrum Sepolia (421614)
- Pool:     `0xe82976502DC719ccE71dBfA28490c4138f4EaD6f`
- Executor: `0xBd8c798B739FB916061e5b714E951c59Ee5A390E`
- USDC:     `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`

### Base Sepolia (84532)
- Pool:     `0x95867e7a139dfbe851a564f309dbdaf749145ef2`
- Executor: `0xcd599a245d24585f2b23fafcfdd9ab5c20014692`
- USDC:     `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

### Shared
- Treasury: `0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487`

## How It Works

1. User calls `signIntent(1.0 USDC -> 0.9995 USDC, destChainId=84532, deadline)` on Arb
   - 1.0 USDC locked in Pool
2. Relayer pays 0.9995 USDC to User on Base
   - User sees USDC in wallet
3. Relayer calls `executeFill(intentId)` on Arb
   - Records filled=true (NO transfer)
4. User signs receipt (off-chain)
5. Relayer calls `claim(intentId, sig)` on Arb
   - Pool releases 0.9999 USDC to relayer + 0.0001 to Treasury

Final:
- User:    Arb -1.0     | Base +0.9995
- Relayer: Arb +0.9999  | Base -0.9995
- Treasury: +0.0001

## Features

- Immutable (no admin, no upgrade, no pause)
- Trustless (User signs only after receiving USDC)
- No TVL (no LP, no impermanent loss)
- No flashLoan
- Sweep after 7 days (unclaimed -> Treasury)
- No double-spend
- Bidirectional (Arb <-> Base)
- 320 lines of Solidity
- 25/25 tests

## Performance (Measured, Sepolia)

| Metric | Value |
|--------|-------|
| E2E p50 | 4.20s (n=27) |
| E2E p95 | 5.07s |
| Gas per E2E | ~465k |
| Arb block | 0.27s |
| Base block | 0.20s |

Comparison (est.):
- CCTP: ~20s, ~800k gas
- Stargate: ~45s, ~520k gas
- Ghost v7.3: 4.2s, ~465k gas

## Limitations

- USDC only
- 2 chains (Arb + Base)
- Testnet only
- Single relayer (test setup)
- No audit yet
- EIP-712 deferred to v7.4

## Quick Start

Build: forge build
Test: forge test

## Documentation

- ADDRESSES.md - deployed contracts
- ATTACK_REPLAY.md - v6 to v7.2 story
- CHANGELOG.md - version history
- HANDOFF.md - current state
- LESSONS.md - operational lessons
- measurements.md - benchmark data

## Disclaimer

Testnet implementation. Do NOT use with real funds on mainnet without:
1. External security audit
2. Multi-relayer infrastructure
3. Bug bounty program
4. Extended testnet operation (6+ months)

License: MIT
