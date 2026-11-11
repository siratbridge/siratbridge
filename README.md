# SiratBridge (formerly Ghost v7.3)

[![CI](https://github.com/siratbridge/siratbridge/actions/workflows/test.yml/badge.svg)](https://github.com/siratbridge/siratbridge/actions/workflows/test.yml)
[![Tests](https://img.shields.io/badge/tests-25%2F25-brightgreen)]()
[![E2E](https://img.shields.io/badge/E2E-4.20s-green)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

**The Trustless USDC Bridge**

SiratBridge is the simplest cross-chain USDC bridge between L2s.
Originally built as "Ghost v7.3", now rebranded as "SiratBridge".

## Live Contracts (Sepolia Testnet)

### Arbitrum Sepolia (421614)
- Pool: `0xe82976502DC719ccE71dBfA28490c4138f4EaD6f`
- Executor: `0xBd8c798B739FB916061e5b714E951c59Ee5A390E`

### Base Sepolia (84532)
- Pool: `0x95867e7a139dfbe851a564f309dbdaf749145ef2`
- Executor: `0xcd599a245d24585f2b23fafcfdd9ab5c20014692`

## Features

- 320 lines of Solidity
- Trustless (user signs after receiving USDC)
- Immutable (no admin, no upgrade, no pause)
- No TVL (no LP, no impermanent loss)
- 0.05% fee
- 4.20s median E2E (Sepolia, n=27)
- 25/25 tests passing

## How It Works

1. User calls `signIntent(1.0 USDC -> 0.9995 USDC)`
2. Relayer pays 0.9995 USDC on destination
3. User signs receipt
4. Relayer calls `claim(intentId, sig)`
5. Pool releases 0.9999 USDC to relayer + 0.0001 to Treasury

**Note:** Contract names retain "Ghost" prefix for historical continuity.

## Quick Start

forge build
forge test
# Expected: 25 passed

## Roadmap

- Q1 2027: External audit
- Q2 2027: Mainnet (Arbitrum + Base)
- Q3 2027: Multi-chain

## License

MIT

## Community

- **Twitter:** [@sirat_bridge](https://x.com/sirat_bridge)
- **Discord:** [Join](https://discord.gg/AKBJ3uctU)
- **Website:** [siratbridge.github.io](https://siratbridge.github.io/siratbridge/)

## Medium

- **Article:** [I Spent 3 Weeks Building a USDC Bridge](https://siratbridge.medium.com/i-spent-3-weeks-building-a-usdc-bridge-then-i-found-a-critical-bug-de3087a17b3d)
