# GHOST v7.3-minimal — Deployed Addresses

**Network:** Sepolia Testnet (Arbitrum + Base)
**Contract version deployed:** v7.2 (v7.3-minimal is local-only, not deployed)
**Date:** 2026-11-10

## Arbitrum Sepolia (chainId: 421614)

| Contract | Address | Etherscan |
|----------|---------|-----------|
| Pool V7 | `0xe82976502DC719ccE71dBfA28490c4138f4EaD6f` | [View](https://sepolia.arbiscan.io/address/0xe82976502DC719ccE71dBfA28490c4138f4EaD6f) |
| Executor V7 | `0xBd8c798B739FB916061e5b714E951c59Ee5A390E` | [View](https://sepolia.arbiscan.io/address/0xBd8c798B739FB916061e5b714E951c59Ee5A390E) |
| USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` | [View](https://sepolia.arbiscan.io/address/0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d) |
| Treasury | `0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487` | [View](https://sepolia.arbiscan.io/address/0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487) |

**Deployment TXs:**
- Pool: (from v7.2 deployment — see handoff)
- Executor: (from v7.2 deployment — see handoff)

## Base Sepolia (chainId: 84532)

| Contract | Address | Basescan |
|----------|---------|----------|
| Pool V7 | `0x95867e7a139dfbe851a564f309dbdaf749145ef2` | [View](https://sepolia.basescan.org/address/0x95867e7a139dfbe851a564f309dbdaf749145ef2) |
| Executor V7 | `0xcd599a245d24585f2b23fafcfdd9ab5c20014692` | [View](https://sepolia.basescan.org/address/0xcd599a245d24585f2b23fafcfdd9ab5c20014692) |
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | [View](https://sepolia.basescan.org/address/0x036CbD53842c5426634e7929541eC2318f3dCF7e) |
| Treasury | `0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487` | [View](https://sepolia.basescan.org/address/0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487) |

**Deployment TXs (Base):**
- Pool deploy: `0x3bef52f06a6f682b4b7ee6cfa61ba44530968dac8572c0831d7399b58e0caa31`
- Executor deploy: `0xdaec509053eac4b125d09d63f5676cb558a97fc0decb20985eb6414d04bd4643`
- Init executor: `0x4dedccc11446cc6a55ff62f3357e1f174eb4c6a189441f95963e2177f63c624c`

## Shared

| Role | Address |
|------|---------|
| TREASURY | `0x08BE0814f08F605d35Aa1352C42Bc5F1b9aBE487` |
| RELAYER (test wallet) | `0xCdfFF5f3f9863Acb2c343A4e53F3Bcc743A6042F` |

## v7.3-minimal (local-only, not deployed)

**Changes from v7.2:**
- Added `error InvalidSignature()` in GhostPoolV7
- Changed `claim()` to use `InvalidSignature()` instead of `InvalidRelayer()`

**Not deployed because:**
- v7.3-minimal = JQ improvement (better error name)
- v7.2 is already deployed, tested (27 E2E runs), and documented
- Deployment would require new addresses + re-testing without functional gain

**Files:**
- `src/GhostPoolV7.sol` — v7.3-minimal
- `src/GhostPoolV7.sol.v73_final` — backup of v7.3-minimal
- `src/GhostPoolV7.sol.v73_minimal_bak` — v7.2 (pre-modification)

## Block Explorers

- **Arbitrum Sepolia:** https://sepolia.arbiscan.io
- **Base Sepolia:** https://sepolia.basescan.org
