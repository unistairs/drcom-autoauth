# Dr.COM 校园网 Portal 自动认证（macOS / Windows）

校园网（Dr.COM/城市热点 portal，合肥工业大学实测）掉线自动重新认证的看门狗。
每条网络链路（有线 / 指定 SSID 的 Wi-Fi）独立检测、独立认证，认证前对 portal 做四重指纹校验，拒绝把账号密码交给伪造页面。

## 特性

- **portal 发现自适应**：portal IP 随校区/楼宇变化——脚本不猜 IP，而是读取劫持页里的跳转地址，顺藤摸瓜找到当前位置的真 portal（内置候选 IP 仅作兜底）
- **防钓鱼四重校验**（交出凭据前必须全过）：
  1. Dr.COM 系统标记（`Dr.COMWebLoginID`）
  2. 校名指纹（portalname，可配置）
  3. 机构编号前缀（portalid，可配置）
  4. **会话绑定**：`ss5` 字段必须存在（默认 normal 模式，兼容路由器/NAT——portal 看到的是路由器 IP；直连可设 `PORTAL_CHECK=strict` 要求等于本机 IP）。所有校验失败都带具体原因日志
  - 劫持跳转目标只允许落在校园私网段，跳公网直接拒绝
- **服务端错误可读**：解析 `msga` 字段区分"账号密码错误 / 已达最大在线数 / 本时段禁止使用"等真实拒绝原因，而不是看页面有没有"成功"字样
- **宵禁退避**：识别"本时段禁止使用"（夜间禁网）后退避 30 分钟，不通宵轰炸 portal，解禁自动恢复
- **SSID 白名单门控**：只对名单内的校园 Wi-Fi 生效（支持逗号分隔多个 SSID，用路由器共享校园网时把路由器 AP 名也加进来）；连其他 Wi-Fi 完全静默；有线不受限
- **零依赖**：macOS 仅需自带的 bash/curl；Windows 仅需 Win10 自带的 PowerShell + curl.exe
- **凭据进系统保险箱**：setup 交互配置后密码存入 **macOS 钥匙串 / Windows DPAPI**（用户级加密，仅本机本用户可读），磁盘无明文无自研哈希，不触发杀软启发式

## 使用教程（Windows）

### 1. 下载并解压

打开 [最新版本下载页](https://github.com/unistairs/drcom-autoauth/releases/latest)，在 **Assets（附件）** 中下载 `drcom-autoauth-v1.0.1.zip`。右键选择“全部解压”，放到准备长期保留的目录。不要在 ZIP 压缩包内直接运行，也不要只复制 BAT 文件。

### 2. 一键配置并启动

1. 连接校园网有线网络或 `hfut-wlan` 无线网络。
2. 双击根目录的 **Windows一键启动.bat**，使用平时登录电脑的 Windows 账户，无需管理员权限。
3. 按中文提示输入账号、密码；已有配置可分别回车保留。首次配置必须填写。随后可逐个追加 Wi-Fi 名称，空白回车结束。
4. 程序依次执行“账号配置 → 试跑认证 → 注册并启动后台”。如果某一步报错，保留窗口中的错误信息。
5. 出现设置完成提示后可以关闭窗口，后台会继续工作，下次登录 Windows 自动启动。

**已有账号、密码时，对应输入直接回车即可保留。SSID 输入新名称会去重追加，回车结束，始终保留 `hfut-wlan` 和原有名单；其他已有配置也保留。后台被关闭后，可重新双击并一路回车恢复运行。** 密码由 Windows DPAPI 加密，配置绑定本机当前用户；换电脑或换 Windows 用户时需重新配置。

### 3. 确认是否联网成功

用记事本打开 `windows/autoauth.log`：

- `认证成功(...), 链路已通`：脚本登录后已经回验 HTTP 204。
- `HTTP 204，链路已通，无需认证`：当前已经在线。
- `登录被拒绝`：根据日志中的服务器原因检查账号、在线设备数或使用时段。
- `探测不可达`：可能是网络切换、DNS 或超时；后台会继续检查可信登录页并重试，不代表密码错误。

在线时后台通常不重复写成功日志。“设置完成”只表示启动流程完成，不等于认证成功。

### 4. 无线名称、手动检查与卸载

默认只处理 `hfut-wlan` Wi-Fi。有线不受 SSID 限制。可通过一键启动逐个追加其他校园 SSID 或共享路由器名称。若需手动删除其他 SSID，用记事本编辑 `windows/config.psd1` 的 `WifiSsids`，例如 `@("hfut-wlan", "你的校园路由器名称")`。修改后先卸载后台，再重新注册；也可以再次运行一键启动，回车保留已有配置。

在 `windows` 文件夹空白处右键打开终端，按需执行：

```powershell
# 手动检查一轮，不重新填写账号
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start.ps1

# 取消登录自启动并停止后台，保留账号配置
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Unregister-AutoAuthTask.ps1

# 用现有配置重新注册并启动后台
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Register-AutoAuthTask.ps1
```

移动或删除文件夹前先卸载。更新版本时先停止旧后台，在新目录重新配置并启动。不要分享 `config.psd1`、日志或本地抓取文件。

### 常见问题

- **认证慢：** Windows 会响应网络地址变化，离线短重试、在线低频检查；网络请求超时仍会增加等待时间。
- **证书弹窗：** 本脚本使用命令行 curl，不弹出网页证书对话框。若认证网页提示不受信任或名称不匹配，不要为了消除弹窗直接安装未知根证书；先关闭网页并查看后台认证日志。
- **运行后文件找不到：** 请完整解压，并保留 BAT 与 `windows` 子目录的相对位置。

## 手动安装（macOS / Windows）

### macOS

```bash
cd macos
bash setup.sh    # 交互式配置(密码入钥匙串)
bash start.sh    # 试跑一轮+看日志
bash install.sh  # 常驻(登录自启)
```

卸载：`bash uninstall.sh`

### Windows

**完整解压后双击根目录的「Windows一键启动.bat」。** 按中文提示输入账号和密码，依次完成配置、试跑、注册并启动当前用户登录自启动项，无需管理员权限。已有账号密码可回车保留，SSID 只追加；请保留项目目录的位置。

Windows 后台监听网络地址变化，接入校园网时优先检查可信登录页。离线时每轮结束后等待 5 秒重试，连续六轮失败后改为 30 秒；在线每 60 秒检查，服务端拒绝后至少等待 60 秒。正在执行的网络请求仍需返回或超时。

Fake-IP DNS 环境使用 HTTPS DNS 获取探测域名真实地址，并缓存最后结果；服务不可用且无缓存时可能无法完成公网探测，此时仅对通过身份校验的明确登录页尝试认证。

```powershell
cd windows
.\Setup.ps1                 # 交互式配置(密码 DPAPI 加密)
.\Start.ps1                 # 试跑一轮+看日志
.\Register-AutoAuthTask.ps1   # 常驻(登录自启)
```

手动单轮调试：`.\AutoAuth.ps1 -Once`。卸载：`.\Unregister-AutoAuthTask.ps1`

## 工作原理

```
按平台调度（macOS 每 20 秒；Windows 网络变化触发及自适应间隔），对每条活跃链路:
  请求 canary(期望 204)
    ├─ 204  → 已认证, 静默
    ├─ 无响应 → Windows 检查可信候选登录页；macOS 跳过
    └─ 其他(200/劫持) →
        提取劫持页跳转的 portal IP(限校园私网段)
        → 四重指纹校验
        → 读取 portal 的 ps/pid/calg 参数
        → MD5("pid"+密码+"calg")+"calg"+"pid" 编码(ps=1) 或 base64(ps=0)
        → POST /0.htm 登录
        → 解析 msga(失败原因/宵禁)
        → 回验 canary 是否 204
```

Dr.COM 协议细节见 [docs/protocol.md](docs/protocol.md)。

## 适配其他学校

本脚本在合肥工业大学（翡翠湖/宣城校区 portal 群）实测。其他 Dr.COM 学校通常只需改 `config` 里的：

- `PORTAL_CANDIDATES`：你们学校的 portal IP
- `PORTAL_SCHOOL_NAME` / `PORTAL_ID_PREFIX`：portal 页面里 `portalname='...'` 和 `portalid='...'` 的实际值（劫持状态下浏览器打开 portal IP，查看源码可见）
- `PORTAL_SCHOOL_NAME` 页面是 GB2312 编码，脚本已处理转码

非 Dr.COM 系统（锐捷、深澜 Srun 等）协议不同，欢迎 PR。

## 免责声明

仅供学习研究。使用本工具即表示你确认对所认证的账号拥有合法使用权。作者不对滥用负责。
