#!/bin/bash
# setup.sh —— 交互式配置校园网账号(密码存系统钥匙串, 不落盘)
set -e
cd "$(dirname "$0")"

echo "=== Dr.COM 自动认证 · 账号配置 ==="
read -r -p "校园网账号: " ACC
[ -z "$ACC" ] && { echo "账号不能为空"; exit 1; }
read -r -s -p "校园网密码(输入不显示): " PW; echo
[ -z "$PW" ] && { echo "密码不能为空"; exit 1; }

# 密码存入登录钥匙串(系统加密存储; -U 允许覆盖更新), 钥匙串解锁状态(用户已登录)下读取免确认
security add-generic-password -a "$ACC" -s "drcom-campus-portal" -w "$PW" -U >/dev/null
PW=""

cat > config.sh <<EOF
# 由 setup.sh 生成于 $(date '+%Y-%m-%d %H:%M')
# 密码不在此文件: 存于本机登录钥匙串(服务名 drcom-campus-portal, 账号同名)
ACC="$ACC"

# 只对这些 SSID 的 Wi-Fi 生效(逗号分隔; 有线不受限; 路由器 AP 名可加进来)
WIFI_SSIDS="hfut-wlan"

# portal 候选(真 portal 以劫持页跳转为准, 候选仅兜底)
PORTAL_CANDIDATES="172.18.3.3 172.18.2.2"

# captive 检测探针(期望 204)
CANARY="http://connect.rom.miui.com/generate_204"

# portal 身份校验指纹(按学校实际情况调整)
PORTAL_SCHOOL_NAME="合肥工业大学"
PORTAL_ID_PREFIX="AH"

# 校验严格度: normal=兼容路由器/NAT | strict=ss5 须等于本机 IP(仅直连)
PORTAL_CHECK="normal"
EOF
chmod 600 config.sh
echo
echo "配置完成: 密码已存入系统钥匙串(服务 drcom-campus-portal), config.sh 不含密码"
echo "下一步: bash start.sh 试跑一轮; 没问题后 bash install.sh 常驻。"
