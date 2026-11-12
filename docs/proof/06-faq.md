# FAQ

**Honest answers. No marketing.**

## General

### Q: What is SiratBridge?

A trustless, immutable USDC bridge between EVM networks.
- 329 lines of Solidity.
- 0.05% fee.
- 4.20s median transfer (measured on Sepolia).

### Q: Is it safe?

Partially. Here's the truth:
- 25/25 tests passing.
- v6 attack replay failed on v7.2 (attacker gained 0).
- No admin, no upgrade, no pause.
- No external audit yet (Q1 2027).
- Use with caution.

### Q: Where is it deployed?

- Arbitrum Sepolia (testnet).
- Base Sepolia (testnet).
- Mainnet: Q2 2027 (after audit).

## Fees

### Q: How much does it cost?

0.05% per transfer.
- 0.01% to Treasury (multisig).
- 0.04% to relayer.

### Q: Why 0.05%?

Lower than Across (0.06%), Stargate (0.06%), Hop (0.10%).
Higher than CCTP (0%).

### Q: Who pays the fee?

The user. It's built into the outputAmount.

Example: user sends 1.0 USDC, receives 0.9995. The 0.0005 difference is the fee.

## Speed

### Q: How fast is it?

4.20s median end-to-end (measured on Sepolia, n=27 runs).
- p50: 4.20s.
- p95: 5.07s.
- min: 3.35s.
- max: 5.40s.

### Q: Why 4.20s?

Because Arb block time = 0.27s, Base block time = 0.20s.
The 4.20s is mostly RPC latency + user signing.

### Q: Can it be faster?

Yes, with:
- Dedicated RPC (not public).
- WebSocket (not polling).
- Parallel signing.

But 4.20s is good enough for most users.

## Risk

### Q: What if the relayer doesn't pay?

User doesn't sign. After fillDeadline, user can refund. User's USDC is safe.

### Q: What if the user doesn't sign?

Relayer loses their USDC (after 7 days, it sweeps to Treasury).
This is a known risk. See Relayer Economics.

### Q: What if the relayer is malicious?

Relayer can't steal USDC.
- executeFill doesn't transfer USDC.
- Only claim transfers USDC (after user signs).

### Q: What if the code has a bug?

25/25 tests passing. No audit yet.
If you're concerned, wait for audit (Q1 2027).

## Development

### Q: Who built this?

One developer. Solo founder.
- 3+ years Solidity experience.
- Built v6, v7.0, v7.1, v7.2, v7.3.
- Self-funded.

### Q: Is it open source?

Yes. MIT license.
- Code: github.com/siratbridge/siratbridge
- Tests: github.com/siratbridge/siratbridge/tree/main/test

### Q: Can I contribute?

Yes.
- Report bugs: siratbridge.dev@gmail.com
- Fork the repo.
- Submit PRs.

## Next Steps

### Q: When mainnet?

Q2 2027 (after audit).

### Q: When audit?

Q1 2027. Pashov Audit Group or Code4rena. $5,000-$15,000.

### Q: Will there be a token?

No current plan. SiratBridge is a non-tokenized protocol.
If a token is ever needed (Q3 2027+), it will be for relayer staking, not speculation.

### Q: How can I help?

- Try testnet: siratbridge.github.io/siratbridge
- Follow: @sirat_bridge
- Join Discord: discord.gg/AKBJ3uctU
- Report issues: siratbridge.dev@gmail.com

## Links

- GitHub: https://github.com/siratbridge/siratbridge
- Whitepaper: https://github.com/siratbridge/siratbridge/blob/main/docs/WHITEPAPER.md
- Website: https://siratbridge.github.io/siratbridge/
- Twitter: https://x.com/sirat_bridge
- Discord: https://discord.gg/AKBJ3uctU
