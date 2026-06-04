#!/usr/bin/env bash
# Claude Code Status Line - 用 node 解析 JSON，不依赖 jq/bc

input=$(cat)

# 用 node 一次性解析所有字段
eval "$(node -e "
  const d = JSON.parse(process.argv[1] || '{}');
  const w = d.workspace || {};
  const cu = d.context_window || {};
  const u = cu.current_usage || {};
  const fmt = n => (n == null || n === 'null') ? '' : (n > 999 ? (n/1000).toFixed(1)+'k' : ''+n);
  const sessionName = d.session_name || (d.session_id || '').slice(0,8) || 'unnamed';
  console.log('SESSION_NAME=' + JSON.stringify(sessionName));
  console.log('TURN_IN=' + fmt(u.input_tokens));
  console.log('TURN_OUT=' + fmt(u.output_tokens));
  console.log('TOTAL_IN=' + fmt(cu.total_input_tokens));
  console.log('USED_PCT=' + (cu.used_percentage != null ? Math.round(cu.used_percentage) : ''));
  // 自定义费用计算（基于 Kimi 定价，每轮累加存文件）
  const modelId = (d.model && d.model.id) || '';
  const mid = modelId.toLowerCase();
  let priceIn, priceCache, priceOut;
  if (mid.includes('kimi-k2.6')) {
    priceIn = 6.50;      // 输入（缓存未命中）
    priceCache = 1.10;   // 输入（缓存命中）
    priceOut = 27.00;    // 输出
  } else if (mid.includes('kimi-k2.5')) {
    priceIn = 4.00;      // 输入（缓存未命中）
    priceCache = 0.70;   // 输入（缓存命中）
    priceOut = 21.00;    // 输出
  } else if (mid.includes('mimo-v2.5-pro')) {
    priceIn = 3.00;      // 输入（缓存未命中）
    priceCache = 0.025;  // 输入（缓存命中）
    priceOut = 6.00;     // 输出
  } else if (mid.includes('mimo-v2.5')) {
    priceIn = 1.00;      // 输入（缓存未命中）
    priceCache = 0.02;   // 输入（缓存命中）
    priceOut = 2.00;     // 输出
  } else if (mid.includes('deepseek-v4-pro')) {
    priceIn = 3.00;      // 输入（缓存未命中）
    priceCache = 0.025;  // 输入（缓存命中）
    priceOut = 6.00;     // 输出
  } else if (mid.includes('deepseek-v4-flash')) {
    priceIn = 1.00;      // 输入（缓存未命中）
    priceCache = 0.02;   // 输入（缓存命中）
    priceOut = 2.00;     // 输出
  } else {
    // 兜底：未知模型使用 mimo-v2.5 价格
    priceIn = 1.00;
    priceCache = 0.02;
    priceOut = 2.00;
  }
  const turnIn = u.input_tokens || 0;           // 未命中缓存的输入 token
  const turnOut = u.output_tokens || 0;
  const turnCache = u.cache_read_input_tokens || 0; // 命中缓存的输入 token
  const turnCacheCreate = u.cache_creation_input_tokens || 0; // 写入缓存的输入 token
  const turnCost = (turnCache / 1e6 * priceCache) + (turnCacheCreate / 1e6 * priceIn) + (turnIn / 1e6 * priceIn) + (turnOut / 1e6 * priceOut);
  // 单文件管理所有会话费用
  const fs = require('fs');
  const costFile = (process.env.HOME || process.env.USERPROFILE || '') + '/.claude/session-costs.json';
  let allData = {};
  try { allData = JSON.parse(fs.readFileSync(costFile, 'utf8')); } catch(e) {}
  let data = allData[sessionName] || { total: 0, lastIn: 0, totalOut: 0 };
  const totalIn = cu.total_input_tokens || 0;

  // totalIn 变化时累加（避免浮点精度问题，输出成本会略低估 6-12%）
  if (totalIn > data.lastIn) {
    data.total += turnCost;
    data.totalOut = (data.totalOut || 0) + turnOut;
    data.lastIn = totalIn;
    allData[sessionName] = data;
    try { fs.writeFileSync(costFile, JSON.stringify(allData)); } catch(e) {}
  }
  console.log('TURN_COST=' + (turnCost > 0 ? turnCost.toFixed(4) : ''));
  console.log('TOTAL_COST=' + (data.total > 0 ? data.total.toFixed(4) : ''));
  console.log('TOTAL_OUT_ACC=' + fmt(data.totalOut || 0));
  // 余额计算（每个会话独立）
  const balance = data.balance;
  if (balance != null && balance > 0) {
    const remaining = balance - (data.total || 0);
    console.log('BALANCE=' + (remaining > 0 ? remaining.toFixed(2) : '0.00'));
  }
  // 模型短名称
  const modelShort = mid.includes('kimi-k2.6') ? 'k2.6'
    : mid.includes('kimi-k2.5') ? 'k2.5'
    : mid.includes('mimo-v2.5-pro') ? 'mimo-pro'
    : mid.includes('mimo-v2.5') ? 'mimo'
    : mid.includes('deepseek-v4-pro') ? 'ds-v4-pro'
    : mid.includes('deepseek-v4-flash') ? 'ds-v4-flash'
    : modelId.slice(0, 10) || '';
  console.log('MODEL_SHORT=' + JSON.stringify(modelShort));
  // // 调试日志：观察数据变化规律（已禁用）
  // try {
  //   const debugEntry = {
  //     ts: new Date().toISOString(),
  //     session: sessionName,
  //     model: modelId,
  //     turnIn,
  //     turnOut,
  //     turnCache,
  //     totalIn,
  //     usedPct: cu.used_percentage,
  //     turnCost: +turnCost.toFixed(6),
  //     totalCost: +data.total.toFixed(6),
  //     turnKey,
  //     didAccumulate
  //   };
  //   const debugFile = (process.env.HOME || process.env.USERPROFILE || '') + '/.claude/statusline-debug.jsonl';
  //   fs.appendFileSync(debugFile, JSON.stringify(debugEntry) + '\n');
  // } catch(e) {}
" "$input" 2>/dev/null)"

# 颜色定义
C='\033[36m'   # 青色 - 会话名
G='\033[32m'   # 绿色 - 输入 ↑
R='\033[31m'   # 红色 - 输出 ↓
Y='\033[33m'   # 黄色 - 花费 ¥
O='\033[38;5;208m' # 橘红色 - 余额
W='\033[38;5;245m' # 灰色 - 上下文 %
D='\033[2m'    # 暗色 - 分隔符
X='\033[0m'    # 重置

# 组装
parts=()
[ -n "$SESSION_NAME" ] && [ "$SESSION_NAME" != '""' ] && parts+=("${C}${SESSION_NAME//\"/}${X}")

turn_info=""
if [ -n "$TURN_IN" ] && [ "$TURN_IN" != '""' ]; then
  turn_info="本轮 ${G}↑${TURN_IN//\"/}${X} ${R}↓${TURN_OUT//\"/}${X}"
  [ -n "$TURN_COST" ] && [ "$TURN_COST" != '""' ] && turn_info="${turn_info} ${O}¥${TURN_COST//\"/}${X}"
fi
[ -n "$turn_info" ] && parts+=("$turn_info")

session_info=""
if [ -n "$TOTAL_IN" ] && [ "$TOTAL_IN" != '""' ]; then
  session_info="累计 ${G}↑${TOTAL_IN//\"/}${X} ${R}↓${TOTAL_OUT_ACC//\"/}${X}"
  [ -n "$TOTAL_COST" ] && [ "$TOTAL_COST" != '""' ] && session_info="${session_info} ${O}¥${TOTAL_COST//\"/}${X}"
  if [ -n "$USED_PCT" ] && [ "$USED_PCT" != '""' ]; then
    # 上下文颜色分级：<70% 灰色，70-90% 黄色，>90% 红色
    pct="${USED_PCT//\"/}"
    if [ "$pct" -gt 90 ] 2>/dev/null; then
      session_info="${session_info} ${R}(上下文 ${pct}%)${X}"
    elif [ "$pct" -gt 70 ] 2>/dev/null; then
      session_info="${session_info} ${Y}(上下文 ${pct}%)${X}"
    else
      session_info="${session_info} ${W}(上下文 ${pct}%)${X}"
    fi
  fi
  [ -n "$BALANCE" ] && [ "$BALANCE" != '""' ] && session_info="${session_info} ${O}余额¥${BALANCE//\"/}${X}"
fi
[ -n "$session_info" ] && parts+=("$session_info")
[ -n "$MODEL_SHORT" ] && [ "$MODEL_SHORT" != '""' ] && parts+=("${G}${MODEL_SHORT//\"/} ✓${X}")

# 输出
output=""
for i in "${!parts[@]}"; do
  if [ $i -eq 0 ]; then
    output="${parts[$i]}"
  else
    output="${output} ${D}│${X} ${parts[$i]}"
  fi
done

echo -e "$output"
