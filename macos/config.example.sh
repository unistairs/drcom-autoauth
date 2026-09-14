# autoauth 配置文件 —— 复制本文件为 config.sh 并填入真实值
# config.sh 已在 .gitignore 中, 永远不会被提交

# 校园网账号(必填); 密码推荐用 setup.sh 生成的 PASS_HASH(不含明文)
ACC="你的校园网账号"
PASS_HASH="运行 setup.sh 自动生成; 或直接用明文 PASS="密码""

# 只对这些 SSID 的 Wi-Fi 生效(逗号分隔, 有线不受限); 用路由器共享校园网时把路由器 AP 名加进来
WIFI_SSIDS="hfut-wlan"

# portal 候选(空格分隔; 真 portal 以劫持页跳转为准, 候选仅兜底)
PORTAL_CANDIDATES="172.18.3.3 172.18.2.2"

# captive 检测探针(期望返回 204)
CANARY="http://connect.rom.miui.com/generate_204"

# portal 身份校验指纹(按学校实际情况调整)
PORTAL_SCHOOL_NAME="合肥工业大学"
PORTAL_ID_PREFIX="AH"
