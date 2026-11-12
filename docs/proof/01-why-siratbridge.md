# Why SiratBridge?

**The Trustless USDC Bridge Between EVM Networks.**

## The Problem

Cross-chain USDC is:
- **Slow** (20s-10min on average)
- **Expensive** (0.06-0.10% per transfer)
- **Trusted** (relies on validators, multisigs, or oracles)
- **Complex** (2,000-10,000 lines of code)

## The Solution

SiratBridge is different:
- **4.20s median** end-to-end on Sepolia (n=27). Mainnet may differ.
- **0.05% fee** (lowest in class among fee-charging bridges)
- **Trustless** (user signs only after receiving USDC)
- **329 lines of Solidity** (auditable in hours, not weeks)

## What's Different

| Aspect | SiratBridge | Competitors |
|--------|-------------|-------------|
| **Trust** | Trustless (user signs) | Trusted (validators, oracles) |
| **TVL** | 0 (no liquidity providers) | $100M-$500M+ |
| **LOC** | 329 | 2,000-10,000 |
| **Admin** | None | Multisig, upgradeable |
| **Speed** | 4.20s (measured) | 20s-10min |
| **Fee** | 0.05% | 0.06-0.10% |

## Current Status

- **Live on Sepolia** (Arbitrum + Base)
- **42 successful fills** (41 Arb + 1 Base, verified on-chain)
- **25/25 tests** passing
- **CI passing** on every push

## What's NOT There Yet

- **No mainnet deployment** (audit pending)
- **No external audit** (Q1 2027)
- **No real users** (testnet only)

We're honest about where we are. No promises. Just code.

## Links

- **GitHub:** github.com/siratbridge/siratbridge
- **Website:** siratbridge.github.io/siratbridge
- **Twitter:** @sirat_bridge
- **Discord:** discord.gg/AKBJ3uctU
