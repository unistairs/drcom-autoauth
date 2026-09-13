#!/bin/bash
# 安装 autoauth 为 macOS LaunchAgent(每 20 秒一轮, 登录自启)
set -e
cd "$(dirname "$0")"
[ -f config.sh ] || { echo "请先复制 config.example.sh 为 config.sh 并填入账号密码"; exit 1; }
chmod 700 autoauth.sh; chmod 600 config.sh
PLIST="$HOME/Library/LaunchAgents/com.hfut.autoauth.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.hfut.autoauth</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$PWD/autoauth.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>20</integer>
  <key>StandardErrorPath</key>
  <string>$PWD/autoauth.err</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/com.hfut.autoauth" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "安装完成: 每 20 秒自动检测认证, 登录自启。日志: $PWD/autoauth.log"
