#!/bin/bash
# start.sh —— 手动跑一轮认证巡逻并显示日志
cd "$(dirname "$0")"
[ -f config.sh ] || { echo "未配置, 请先运行: bash setup.sh"; exit 1; }
bash autoauth.sh
echo "--- 最近日志 ---"
tail -5 autoauth.log 2>/dev/null || echo "(无日志: 各链路健康, 无需认证)"
