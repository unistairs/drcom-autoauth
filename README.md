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

## 安装

### macOS

```bash
cd macos
bash setup.sh    # 交互式配置(密码入钥匙串)
bash start.sh    # 试跑一轮+看日志
bash install.sh  # 常驻(登录自启)
```

卸载：`bash uninstall.sh`

### Windows

```powershell
cd windows
.\Setup.ps1                 # 交互式配置(密码 DPAPI 加密)
.\Start.ps1                 # 试跑一轮+看日志
.\Register-AutoAuthTask.ps1   # 常驻(登录自启)
```

手动单轮调试：`.\AutoAuth.ps1 -Once`。卸载：`.\Unregister-AutoAuthTask.ps1`

## 工作原理

```
每 20 秒, 对每条活跃链路:
  请求 canary(期望 204)
    ├─ 204  → 已认证, 静默
    ├─ 无响应 → 链路不通, 跳过
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
