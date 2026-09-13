#!/bin/bash
# 卸载 autoauth LaunchAgent
launchctl bootout "gui/$(id -u)/com.hfut.autoauth" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.hfut.autoauth.plist"
echo "已卸载(脚本与配置保留, 可手动删除)"
