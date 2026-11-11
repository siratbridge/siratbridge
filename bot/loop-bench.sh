#!/data/data/com.termux/files/usr/bin/bash
# loop-bench.sh — N runs + p50/p95 from TIMING_JSON
N=${1:-10}
OUT=~/ghost-v4/bot/bench-results.log
> "$OUT"
for i in $(seq 1 $N); do
  echo "── run $i/$N ──"
  node ~/ghost-v4/bot/bot-v3.2.js 2>&1 | tee -a "$OUT" | grep -E "E2E wall|FATAL|REVERTED"
  sleep 2
done
echo ""
echo "══════ STATS (from TIMING_JSON) ══════"
grep TIMING_JSON "$OUT" | sed 's/TIMING_JSON: //' | node -e "
let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
  const rows=d.trim().split('\n').filter(Boolean).map(l=>{try{return JSON.parse(l)}catch{return null}}).filter(Boolean);
  if(rows.length===0){console.log('NO DATA');return}
  const pct=(a,p)=>{const s=[...a].sort((x,y)=>x-y);return s[Math.ceil(p/100*s.length)-1]};
  for (const k of ['sign','fork','claim','e2e']) {
    const v=rows.map(r=>r[k]);
    console.log(k.padEnd(6)+' p50='+pct(v,50)+'ms  p95='+pct(v,95)+'ms  min='+Math.min(...v)+'  max='+Math.max(...v));
  }
  console.log('n='+rows.length);
});"
