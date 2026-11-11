// GhostV20 v4 Relayer Bot — v5 (Cross-Chain + Base Payment)
const { ethers } = require("ethers");
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

const ARB_HTTP = process.env.ARB_SEPOLIA_RPC || "https://sepolia-rollup.arbitrum.io/rpc";
const BASE_HTTP = process.env.BASE_SEPOLIA_RPC || "https://base-sepolia-rpc.publicnode.com";
const PRIVATE_KEY = process.env.RELAYER_PK || process.env.PRIVATE_KEY || process.env.SOLVER_PK;
const POOL = process.env.POOL;
const EXECUTOR = process.env.EXECUTOR;
const USDC_ARB = process.env.USDC;
const USDC_BASE = process.env.USDC_BASE || "0x036CbD53842c5426634e7929541eC2318f3dCF7e";

if (!PRIVATE_KEY || !POOL || !EXECUTOR || !USDC_ARB) {
  console.error("❌ Missing env vars");
  process.exit(1);
}

const ARB_CHAIN = 421614;
const BASE_CHAIN = 84532;

const POOL_ABI = [
  "event IntentSigned(bytes32 indexed intentId, address indexed user, uint256 inputAmount, uint256 outputAmount, uint256 destChainId, uint32 fillDeadline)",
  "function getIntent(bytes32) view returns (tuple(address user, uint256 inputAmount, uint256 outputAmount, uint256 destChainId, uint32 fillDeadline, bool filled, bool refunded))",
];

const EXECUTOR_ABI = [
  "function executeFill(bytes32 intentId) external",
  "function getStats() view returns (uint256, uint256, uint256)",
];

const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address, uint256) returns (bool)",
  "function allowance(address, address) view returns (uint256)",
  "function transfer(address, uint256) returns (bool)",
  "function decimals() view returns (uint8)",
];

const arbProvider = new ethers.JsonRpcProvider(ARB_HTTP);
const baseProvider = new ethers.JsonRpcProvider(BASE_HTTP);
const arbWallet = new ethers.Wallet(PRIVATE_KEY, arbProvider);
const baseWallet = new ethers.Wallet(PRIVATE_KEY, baseProvider);

const poolArb = new ethers.Contract(POOL, POOL_ABI, arbProvider);
const executor = new ethers.Contract(EXECUTOR, EXECUTOR_ABI, arbWallet);
const usdcArb = new ethers.Contract(USDC_ARB, ERC20_ABI, arbWallet);
const usdcBase = new ethers.Contract(USDC_BASE, ERC20_ABI, baseWallet);

const processing = new Set();
const processed = new Set();
let nonce = null;
let txQueue = Promise.resolve();

const MIN_PROFIT_USDC = 0;
const GAS_LIMIT = 500_000;
const POLL_MS = 500;
let inFlight = false;
const DEPLOY_BLOCK = 326724461;

let checks = 0;
let found = 0;
let executed = 0;

async function ensureApprovals() {
  const allowance = await usdcArb.allowance(arbWallet.address, EXECUTOR);
  if (allowance < ethers.parseUnits("1000000", 6)) {
    console.log("📝 Approving USDC on Arbitrum...");
    const tx = await usdcArb.approve(EXECUTOR, ethers.MaxUint256);
    await tx.wait();
    console.log("✅ Approved (Arbitrum)");
  }
}

async function checkBalances() {
  const arbUsdc = await usdcArb.balanceOf(arbWallet.address);
  const baseUsdc = await usdcBase.balanceOf(arbWallet.address);
  const arbEth = await arbProvider.getBalance(arbWallet.address);
  const baseEth = await baseProvider.getBalance(arbWallet.address);
  console.log(`💰 Arbitrum: ${ethers.formatUnits(arbUsdc, 6)} USDC | ${ethers.formatEther(arbEth)} ETH`);
  console.log(`💰 Base:     ${ethers.formatUnits(baseUsdc, 6)} USDC | ${ethers.formatEther(baseEth)} ETH`);
}

async function getNextNonce() {
  if (nonce === null) {
    nonce = await arbProvider.getTransactionCount(arbWallet.address, "pending");
  }
  const n = nonce;
  nonce++;
  return n;
}

async function resetNonce() {
  nonce = await arbProvider.getTransactionCount(arbWallet.address, "pending");
}

async function payOnBase(user, amount) {
  try {
    const baseUsdc = await usdcBase.balanceOf(baseWallet.address);
    if (baseUsdc < amount) {
      console.log(`  ⏭️  Insufficient USDC on Base (need ${ethers.formatUnits(amount, 6)})`);
      return false;
    }
    const baseEth = await baseProvider.getBalance(baseWallet.address);
    if (baseEth < ethers.parseEther("0.0001")) {
      console.log(`  ⏭️  Insufficient ETH on Base for gas`);
      return false;
    }
    console.log(`  💸 Paying ${ethers.formatUnits(amount, 6)} USDC on Base to ${user.slice(0, 10)}...`);
    const baseNonce = await baseProvider.getTransactionCount(baseWallet.address, "pending");
    const feeData = await baseProvider.getFeeData();
    const tx = await usdcBase.transfer(user, amount, {
      gasLimit: 100_000,
      maxFeePerGas: feeData.maxFeePerGas,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
      nonce: baseNonce,
    });
    console.log(`  📤 Base TX: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`  ✅ Base payment confirmed in block ${receipt.blockNumber}`);
    return true;
  } catch (e) {
    console.log(`  ❌ Base payment failed: ${e.shortMessage || e.message}`);
    return false;
  }
}

async function tryFill(intentId) {
  const key = intentId.toLowerCase();
  if (processing.has(key) || processed.has(key)) return;
  processing.add(key);

  try {
    const intent = await poolArb.getIntent(intentId);
    if (intent.filled || intent.refunded) {
      processed.add(key);
      processing.delete(key);
      return;
    }
    const now = Math.floor(Date.now() / 1000);
    if (now > intent.fillDeadline) {
      processed.add(key);
      processing.delete(key);
      return;
    }
    const relayerArbBal = await usdcArb.balanceOf(arbWallet.address);
    if (relayerArbBal < intent.outputAmount) {
      console.log(`  ⏭️  Insufficient USDC on Arbitrum`);
      processed.add(key);
      processing.delete(key);
      return;
    }
    const profit = intent.inputAmount - intent.outputAmount;
    if (profit < MIN_PROFIT_USDC) {
      processed.add(key);
      processing.delete(key);
      return;
    }
    const isCrossChain = intent.destChainId !== BigInt(ARB_CHAIN);
    console.log(`  📋 Intent: input=${ethers.formatUnits(intent.inputAmount, 6)}, output=${ethers.formatUnits(intent.outputAmount, 6)}, dest=${intent.destChainId}, cross-chain=${isCrossChain}`);

    if (isCrossChain) {
      if (intent.destChainId === BigInt(BASE_CHAIN)) {
        const paid = await payOnBase(intent.user, intent.outputAmount);
        if (!paid) {
          processed.add(key);
          processing.delete(key);
          return;
        }
      } else {
        console.log(`  ⏭️  Unsupported dest chain: ${intent.destChainId}`);
        processed.add(key);
        processing.delete(key);
        return;
      }
    }

    console.log(`  ⚡ Executing fill on Arbitrum...`);
    await txQueue;
    txQueue = (async () => {
      try {
        const n = await getNextNonce();
        const feeData = await arbProvider.getFeeData();
        const tx = await executor.executeFill(intentId, {
          gasLimit: GAS_LIMIT,
          maxFeePerGas: feeData.maxFeePerGas,
          maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
          nonce: n,
        });
        console.log(`  📤 Arb TX: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`  ✅ Confirmed in block ${receipt.blockNumber}`);
        console.log(`  💰 Profit: ${ethers.formatUnits(profit, 6)} USDC`);
        executed++;
      } catch (e) {
        console.log(`  ❌ Arb TX failed: ${e.shortMessage || e.message}`);
        await resetNonce();
      }
    })();
    await txQueue;
    processed.add(key);
    processing.delete(key);
  } catch (e) {
    console.log(`  ❌ Error: ${e.message}`);
    processing.delete(key);
  }
}

async function poll() {
  if (inFlight) return;
  inFlight = true;
  try {
  try {
    const currentBlock = await arbProvider.getBlockNumber();
    const fromBlock = checks === 0 ? DEPLOY_BLOCK : currentBlock - 100;
    if (checks === 0) {
      console.log(`🔍 Initial scan: blocks ${fromBlock} → ${currentBlock}\n`);
    }
    const events = await poolArb.queryFilter("IntentSigned", fromBlock, currentBlock);
    for (const evt of events) {
      const iid = evt.args.intentId;
      const key = iid.toLowerCase();
      if (!processed.has(key)) {
        found++;
        console.log(`\n🔔 Intent: ${iid}`);
        console.log(`   User:   ${evt.args.user}`);
        console.log(`   Input:  ${ethers.formatUnits(evt.args.inputAmount, 6)} USDC`);
        console.log(`   Output: ${ethers.formatUnits(evt.args.outputAmount, 6)} USDC`);
        console.log(`   Dest:   ${evt.args.destChainId}`);
        await tryFill(iid);
      }
    }
    checks++;
    if (checks % 10 === 0) {
      const stats = await executor.getStats();
      console.log(`💓 #${checks} — block: ${currentBlock}, fills: ${stats[0]}, events: ${found}, executed: ${executed}`);
    }
  } catch (e) {
    console.log(`⚠️  Poll error: ${e.message}`);
  }
  } finally { inFlight = false; setTimeout(poll, POLL_MS); }
}

async function main() {
  console.log("═══════════════════════════════════════════");
  console.log("🤖 GhostV20 v4 Relayer Bot (v5 — Cross-Chain)");
  console.log("═══════════════════════════════════════════");
  console.log(`Wallet:    ${arbWallet.address}`);
  console.log(`Pool:      ${POOL}`);
  console.log(`Executor:  ${EXECUTOR}`);
  console.log(`Arb RPC:   ${ARB_HTTP}`);
  console.log(`Base RPC:  ${BASE_HTTP}`);
  console.log("");
  await checkBalances();
  await ensureApprovals();
  await resetNonce();
  console.log(`🔢 Starting nonce: ${nonce}`);
  console.log("═══════════════════════════════════════════\n");
  console.log(`👂 Polling every ${POLL_MS/1000}s (from block ${DEPLOY_BLOCK})\n`);
  await poll();
}

process.on("SIGINT", () => {
  console.log("\n👋 Bye");
  process.exit(0);
});

main().catch((e) => {
  console.error("❌ Fatal:", e);
  process.exit(1);
});
