# Relayer Economics

**How you earn, and what can go wrong.**

## 1. How You Earn

Every fill follows this pattern:

1. User locks 1.0 USDC on Arbitrum.
2. You (relayer) pay 0.9995 USDC on Base.
3. User sees USDC. User signs receipt.
4. You call claim() on Arbitrum.
5. Pool releases 0.9999 USDC to you.

Your profit: 0.9999 - 0.9995 = 0.0004 USDC per 1.0 USDC fill.

That's 0.04% per fill.

## 2. Example: $10,000 Volume

If you process $10,000 in fills per month:

- Relayer revenue: $10,000 * 0.0004 = $4.00
- Treasury fee: $10,000 * 0.0001 = $1.00
- Gas cost (Arb + Base): ~$3-5/month (at current gas prices)
- Net profit: $4.00 - $4.00 = $0.00 (breakeven)

## 3. Example: $1,000,000 Volume

If you process $1,000,000 in fills per month:

- Relayer revenue: $1,000,000 * 0.0004 = $400.00
- Treasury fee: $1,000,000 * 0.0001 = $100.00
- Gas cost: ~$30-50/month
- Net profit: $400 - $40 = $360/month

## 4. Break-Even Volume

To cover $30/month in gas, you need:

- $30 / 0.0004 = $75,000 volume per month.
- Or: 75 fills of $1,000 each per month.
- Or: 150 fills of $500 each per month.

## 5. The Risk (Honest)

### What if the user doesn't sign?

1. You pay 0.9995 USDC on Base.
2. User receives USDC. User doesn't sign receipt.
3. After fillDeadline (1-60 min), user can refund.
4. After 7 days past fillDeadline, the USDC sweeps to Treasury.
5. You (relayer) do NOT get your USDC back.

### How much can you lose?

- Per fill: 0.9995 USDC (the amount you paid).
- If 1 in 250 fills doesn't sign: you lose 0.9995 USDC per 250 fills.
- To cover this: you need 2,500 successful fills to cover 1 non-signing fill.

### Is this acceptable?

For most relayers, yes. Here's why:

- 99%+ of users sign (it's in their interest).
- Users with on-chain history are reliable.
- You can start small ($100 fills) and increase.

### How to mitigate

- **On-chain history:** Only fill intents from users with signed transactions.
- **Small amounts:** Start with $100 fills. Increase gradually.
- **Reputation (future):** v7.4 will add on-chain user reputation.

## 6. Roadmap (v7.4, Post-Mainnet)

### Q3 2027

- **User reputation system** (on-chain).
- **Relayer filters** by reputation.
- **Trustless** (no admin).

### Q4 2027

- **Relayer insurance** (from Treasury fee, if governance approves).
- **Multi-relayer** (redundancy).
- **Monitoring** (Tenderly + Defender).

## 7. What You Should Know

### Before mainnet

- **No audit yet.** Use at your own risk.
- **Single relayer** (no redundancy).
- **Small volume** (testnet only).

### After mainnet

- **Audit complete** (Q1 2027).
- **Reputation system** (Q3 2027).
- **Multi-relayer** (Q4 2027).

### Links

- GitHub: https://github.com/siratbridge/siratbridge
- Whitepaper: https://github.com/siratbridge/siratbridge/blob/main/docs/WHITEPAPER.md
- Attack Replay: https://sepolia.arbiscan.io/tx/0x988607b5...
