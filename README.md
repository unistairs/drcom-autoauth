校园网自动认证

用于合肥工业大学宣城校园网自动认证，掉线后自动尝试重新登录。支持 Windows 和 macOS，适用于 Dr.COM 认证系统。

## Windows

1. 到 [最新版本](https://github.com/unistairs/drcom-autoauth/releases/latest) 下载 ZIP，完整解压。
2. 连接校园网，双击 **Windows一键启动.bat**。
3. 按提示配置账号、密码和 Wi-Fi 名称，完成后会启动后台，并设置登录 Windows 后自动运行。

- 首次使用需要填写账号和密码；已有配置直接回车即可保留。
- Wi-Fi 名称逐个追加，重复名称不会重复加入；回车结束，始终保留 `hfut-wlan` 和原有名单。
- 后台被关闭后，再次双击并回车保留配置即可恢复运行。
- 配置完成后请保留文件夹位置，联网结果可查看 `windows/autoauth.log`。

取消自启动：在 `windows` 目录打开终端，执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Unregister-AutoAuthTask.ps1
```

## macOS

在 `macos` 目录打开终端，依次执行：

```bash
bash setup.sh
bash start.sh
bash install.sh
```

卸载：`bash uninstall.sh`。

## 技术细节

技术细节请自行查看 [Windows 脚本](windows/)、[macOS 脚本](macos/) 和 [协议说明](docs/protocol.md)。
