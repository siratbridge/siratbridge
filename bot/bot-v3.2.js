// bot-v3.2.js — nonce prefetch + executeFill parallel with BasePay
const { ethers } = require('ethers');
require('dotenv').config({ path: '../.env' });
require('dotenv').config({ path: require('os').homedir() + '/ghost-wallet.env' });
require('dotenv').config({ path: require('os').homedir() + '/ghost-v4/.tmp/test_wallets.env' });

const POLL_MS = 200;
const POOL = process.env.POOL_V7;
const EXECUTOR = process.env.EXECUTOR_V7;
const USDC = process.env.USDC;
const USDC_BASE = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
const USER = process.env.USER_ADDR, USER_PK = process.env.USER_PK;
const RELAYER = process.env.RELAYER_ADDR, RELAYER_PK = process.env.RELAYER_PK;

const arbProvider = new ethers.JsonRpcProvider(process.env.ARB_SEPOLIA_RPC, {chainId:421614,name:'arb'}, {staticNetwork:true});
const baseProvider = new ethers.JsonRpcProvider(process.env.BASE_SEPOLIA_RPC, {chainId:84532,name:'base'}, {staticNetwork:true});

async function waitReceipt(provider, hash, label) {
  const t0 = Date.now();
  for (let i = 0; i < 300; i++) {
    const r = await provider.getTransactionReceipt(hash);
    if (r) {
      if (r.status !== 1) throw new Error(`${label} REVERTED`);
      return { receipt: r, elapsed: Date.now() - t0 };
    }
    await new Promise(r => setTimeout(r, POLL_MS));
  }
  throw new Error(`${label} TIMEOUT`);
}

async function ensureAllowance(tok, ownerW, spender, min) {
  const c = new ethers.Contract(tok, ['function allowance(address,address) view returns (uint256)','function approve(address,uint256) returns (bool)'], ownerW);
  const cur = await c.allowance(await ownerW.getAddress(), spender);
  if (cur >= min) return { skipped: true };
  const tx = await c.approve(spender, 10_000_000_000, { gasLimit: 100_000 });
  const r = await waitReceipt(ownerW.provider, tx.hash, 'approve');
  return { skipped: false, hash: tx.hash, elapsed: r.elapsed };
}

(async () => {
  console.log('══════ GHOST v7.2 — E2E benchmark v3.2 (prefetch + 3-way fork) ══════');
  const T = {}; const stamp = k => { T[k] = Date.now(); };

  const userW = new ethers.Wallet(USER_PK, arbProvider);
  const relW = new ethers.Wallet(RELAYER_PK, arbProvider);
  const relBaseW = new ethers.Wallet(RELAYER_PK, baseProvider);

  // CUT 5: fees + nonces في نداءات متوازية — مرة واحدة فقط
  const [feeArb, feeBase, userN0, relN0, baseN0] = await Promise.all([
    arbProvider.getFeeData(),
    baseProvider.getFeeData(),
    arbProvider.getTransactionCount(userW.address, 'pending'),
    arbProvider.getTransactionCount(relW.address, 'pending'),
    baseProvider.getTransactionCount(relBaseW.address, 'pending')
  ]);
  let userN = userN0, relN = relN0, baseN = baseN0;
  const gasArb = () => ({ maxFeePerGas: feeArb.maxFeePerGas, maxPriorityFeePerGas: feeArb.maxPriorityFeePerGas, nonce: userN++ });
  const gasArbRel = () => ({ maxFeePerGas: feeArb.maxFeePerGas, maxPriorityFeePerGas: feeArb.maxPriorityFeePerGas, nonce: relN++ });
  const gasBase = () => ({ maxFeePerGas: feeBase.maxFeePerGas, maxPriorityFeePerGas: feeBase.maxPriorityFeePerGas, nonce: baseN++ });

  stamp('t_start');
  const a1 = await ensureAllowance(USDC, userW, POOL, 1_000_000);
  const a2 = await ensureAllowance(USDC, relW, EXECUTOR, 1_000_000);
  stamp('t_approve_end');
  console.log(`  approve: ${a1.skipped && a2.skipped ? 'skipped (both)' : 'executed'}`);

  const dl = Math.floor(Date.now() / 1000) + 1800;
  const pool = new ethers.Contract(POOL, ['function signIntent(uint256,uint256,uint256,uint32) returns (bytes32)','event IntentSigned(bytes32 indexed intentId, address indexed user, uint256 inputAmount, uint256 outputAmount, uint256 destChainId, uint32 fillDeadline)'], userW);
  const exec = new ethers.Contract(EXECUTOR, ['function executeFill(bytes32)'], relW);
  const poolRel = new ethers.Contract(POOL, ['function claim(bytes32,bytes)'], relW);
  const usdcB = new ethers.Contract(USDC_BASE, ['function transfer(address,uint256) returns (bool)'], relBaseW);

  stamp('t_sign_begin');
  const signTx = await pool.signIntent(1_000_000, 999_500, 84532, dl, { ...gasArb(), gasLimit: 250_000 });
  const signR = await waitReceipt(arbProvider, signTx.hash, 'signIntent');
  const intentId = signR.receipt.logs.map(l => { try { return pool.interface.parseLog(l); } catch { return null; } }).filter(Boolean).find(p => p.fragment.name === 'IntentSigned')?.args.intentId;
  stamp('t_sign');
  console.log(`  signIntent: ${signR.elapsed}ms (block ${signR.receipt.blockNumber}, gas ${signR.receipt.gasUsed})`);
  console.log(`  intentId: ${intentId}`);

  // CUT 6: fork ثلاثي — BasePay ∥ claimSig ∥ executeFill
  stamp('t_fork');
  const [bp, claimSig, fr] = await Promise.all([
    (async () => {
      const tx = await usdcB.transfer(USER, 999_500, { ...gasBase(), gasLimit: 80_000 });
      const r = await waitReceipt(baseProvider, tx.hash, 'BasePay');
      return { hash: tx.hash, elapsed: r.elapsed, receipt: r.receipt };
    })(),
    (async () => {
      const digest = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['bytes32','uint256','address','address','uint256'],[intentId, 421614, POOL, USER, 999_500]));
      return new ethers.Wallet(USER_PK).signMessage(ethers.getBytes(digest));
    })(),
    (async () => {
      const tx = await exec.executeFill(intentId, { ...gasArbRel(), gasLimit: 120_000 });
      const r = await waitReceipt(arbProvider, tx.hash, 'executeFill');
      return { hash: tx.hash, elapsed: r.elapsed, receipt: r.receipt };
    })()
  ]);
  stamp('t_join');
  console.log(`  BasePay: ${bp.elapsed}ms (block ${bp.receipt.blockNumber}, gas ${bp.receipt.gasUsed})`);
  console.log(`  executeFill: ${fr.elapsed}ms (block ${fr.receipt.blockNumber}, gas ${fr.receipt.gasUsed}) — parallel`);

  const claimTx = await poolRel.claim(intentId, claimSig, { ...gasArbRel(), gasLimit: 150_000 });
  const claimR = await waitReceipt(arbProvider, claimTx.hash, 'claim');
  stamp('t_claim');
  console.log(`  claim: ${claimR.elapsed}ms (block ${claimR.receipt.blockNumber}, gas ${claimR.receipt.gasUsed})`);

  const e2e = T.t_claim - T.t_start;
  const overhead = e2e - (signR.elapsed + Math.max(bp.elapsed, fr.elapsed) + claimR.elapsed);
  console.log(`
══════ TIMING v3.2 ══════
  signIntent:    ${signR.elapsed}ms
  fork(max):     ${Math.max(bp.elapsed, fr.elapsed)}ms  ← BasePay ∥ fill
  claim:         ${claimR.elapsed}ms
  chain total:   ${signR.elapsed + Math.max(bp.elapsed, fr.elapsed) + claimR.elapsed}ms
  ━━━ E2E wall: ${e2e}ms (${(e2e/1000).toFixed(2)}s) ━━━
  overhead (RTT+poll): ~${overhead}ms`);

  console.log(`\nTXs: sign=${signTx.hash}\n     basepay=${bp.hash}\n     fill=${fr.hash}\n     claim=${claimTx.hash}`);
  console.log(`\nTIMING_JSON: ${JSON.stringify({sign:signR.elapsed,fork:Math.max(bp.elapsed,fr.elapsed),claim:claimR.elapsed,e2e,overhead,ts:Date.now()})}`);
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
