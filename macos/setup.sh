#!/bin/bash
# setup.sh —— 交互式配置校园网账号(密码只存 MD5 派生哈希, 不落明文)
set -e
cd "$(dirname "$0")"

echo "=== Dr.COM 自动认证 · 账号配置 ==="
read -r -p "校园网账号: " ACC
[ -z "$ACC" ] && { echo "账号不能为空"; exit 1; }
read -r -s -p "校园网密码(输入不显示): " PW; echo
[ -z "$PW" ] && { echo "密码不能为空"; exit 1; }

# Dr.COM 上传的就是 MD5(pid+密码+calg)+calg+pid, pid=2/calg=12345678 是 portal 公开常量
HASH=$(md5 -q -s "2${PW}12345678")
PW=""   # 立即丢弃明文

cat > config.sh <<EOF
# 由 setup.sh 生成于 $(date '+%Y-%m-%d %H:%M')
# 密码只存 MD5 派生值(认证等价物, 但不含明文); 如需改用明文, 换成 PASS="..." 即可
ACC="$ACC"
PASS_HASH="$HASH"

# 只对这些 SSID 的 Wi-Fi 生效(逗号分隔; 有线不受限; 路由器 AP 名可加进来)
WIFI_SSIDS="hfut-wlan"

# portal 候选(真 portal 以劫持页跳转为准, 候选仅兜底)
PORTAL_CANDIDATES="172.18.3.3 172.18.2.2"

# captive 检测探针(期望 204)
CANARY="http://connect.rom.miui.com/generate_204"

# portal 身份校验指纹(按学校实际情况调整)
PORTAL_SCHOOL_NAME="合肥工业大学"
PORTAL_ID_PREFIX="AH"
EOF
chmod 600 config.sh
echo
echo "配置完成: config.sh 已生成(权限 600, 仅本人可读)"
echo "提示: 哈希仅对本校 portal 参数有效; 它是认证等价物, 不要分享。"
echo "下一步: bash start.sh 试跑一轮; 没问题后 bash install.sh 常驻。"
