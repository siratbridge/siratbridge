# Security Model

**What can go wrong, and what we did about it.**

## 1. v6 Vulnerability (October 2026)

### What happened

In v6, `executeFill` transferred USDC to the caller immediately:

  function executeFill(bytes32 intentId) external {
      // ... validations ...
      USDC.transfer(msg.sender, intent.inputAmount);  // BUG
  }

An attacker could:
1. See an active intent.
2. Call `executeFill` directly.
3. Receive USDC immediately.

The user would never receive USDC on the destination chain. But their USDC would be gone.

### Evidence

- **TX:** https://sepolia.arbiscan.io/tx/0x0d76...
- **Result:** Attacker +400 units. Victim -1 USDC.

### Status

v6 was vulnerable. We deprecated it.

## 2. v7.2 Fix (November 2026)

### What changed

`executeFill` no longer transfers USDC. It only records `filled=true`:

  function executeFill(bytes32 intentId) external {
      // ... validations ...
      intent.filled = true;
      relayerForIntent[intentId] = msg.sender;
  }

The USDC stays in the Pool. It only moves when:
1. User signs a receipt (claim), OR
2. 7 days pass (sweep to Treasury).

### Evidence

- **TX:** https://sepolia.arbiscan.io/tx/0x988607b5...
- **Result:** Attacker gained 0. User unchanged.

## 3. What's Protected

### User protection

- **If the relayer doesn't pay**, user doesn't sign.
- **After fillDeadline**, user can refund.
- **User's USDC is never at risk.**

### Relayer protection

- **If the user doesn't sign**, relayer doesn't get USDC back (after 7 days, it sweeps to Treasury).
- **This is a known risk.** See Relayer Economics.

### Protocol protection

- **No admin.** No one can change the fee, the treasury, or the rules. Verified in bytecode (no owner, no transferOwnership).
- **No upgrade.** The code is immutable. Verified in bytecode (no proxy, no upgradeTo).
- **No pause.** The protocol cannot be stopped. Verified in bytecode (no pause, no unpause).

### Attack resistance

- **Replay (cross-chain):** prevented (chainId in digest).
- **Double-spend:** prevented (filled, claimed, refunded flags).
- **Self-fill:** prevented (msg.sender != user).
- **Treasury fill:** prevented (relayer != treasury).

## 4. What's NOT Protected

### No audit yet

- The code is tested (25/25), but not audited.
- Audit is planned for Q1 2027.
- Until then, use with caution.

### Single relayer

- The current testnet has one relayer.
- Mainnet will require multiple relayers.
- This is a known risk.

### No formal verification

- The code is tested, but not formally verified.
- Formal verification is planned for Q3 2027.

## 5. Audit Plan

### Q1 2027

- **Firm:** Pashov Audit Group or Code4rena.
- **Cost:** $5,000-$15,000.
- **Duration:** 3-5 weeks.
- **Scope:** GhostPoolV7.sol + GhostExecutorV7.sol.

### Q2 2027

- **Mainnet launch** (after audit).
- **Bug bounty** on Immunefi ($10,000).

### Q3 2027

- **Second audit** (different firm).
- **Formal verification** (Certora).

## 6. What You Can Do

### For users

- Start with small amounts ($100).
- Only use on Sepolia for now.
- Wait for audit before mainnet.

### For relayers

- Only fill intents from users with on-chain history.
- Start with $100.
- Increase after trust is built.

### For auditors

- The code is 329 LOC.
- Read it: github.com/siratbridge/siratbridge/tree/main/src
- Report issues: siratbridge.dev@gmail.com

## 7. Links

- GitHub: https://github.com/siratbridge/siratbridge
- Whitepaper: https://github.com/siratbridge/siratbridge/blob/main/docs/WHITEPAPER.md
- Attack Replay: https://sepolia.arbiscan.io/tx/0x988607b5...
