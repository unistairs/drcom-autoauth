# Dr.COM Web Portal 认证协议分析（合肥工业大学实测）

## 发现阶段

1. 未认证时，任意 HTTP 请求被接入控制器劫持，返回 200 + 跳转页：
   `<script>location.href="http://172.18.3.3"</script>`
2. **跳转目标才是本楼真正生效的 portal**。校区内可能存在多个 Dr.COM 实例
   （实测 172.18.2.2 / 172.18.3.3 同时在线，账号库共享——在"错误"的实例上
   也能登录成功，但本地控制器不放行，链路依然被劫持）。
3. portal 首页 `Dr.COMWebLoginID_0.htm`（GB2312 编码）内嵌会话参数：
   - `v4serip`：portal 服务器 IP
   - `ss5`：客户端 IP（本机该链路地址）——**会话绑定校验的依据**
   - `portalname`：校区名（如 `合肥工业大学宣城校区`）
   - `portalid`：机构编号（如 `AH0303797_000`）
   - `authsuccess='Dr.COMWebLoginID_3.htm'`：成功页模板名

## 登录阶段

登录页 `0.htm` 引用 `a41.js`，第一行给出编码参数：

```js
ps=1;pid='2';calg='12345678';
```

提交 `POST http://<portal>/0.htm`（application/x-www-form-urlencoded）：

| 字段 | 值 |
|---|---|
| `DDDDD` | 账号 |
| `upass` | 密码编码（见下） |
| `R1` | `0` |
| `R2` | ps=1 时为 `1`，ps=0 时为 `0` |
| `para` | `00` |
| `0MKKey` | `123456` |
| `v6ip` | 空 |

密码编码两种模式（由 `ps` 决定）：

- **ps=1（MD5）**：`upass = MD5_hex(pid + 密码 + calg) + calg + pid`，hex 小写
- **ps=0（Base64）**：`upass = Base64(密码)`

## 结果判定

响应仍是 GB2312 页面，**不要靠页面里有没有"成功"字样判断**——模板里常驻成功字样。
正确做法是解析响应中的 `msga` 字段：

- `msga=''` 或不存在 + 页面含"成功" → 登录成功（成功页文案：`您已经成功登录`）
- `msga='本时段禁止使用'` → 宵禁时段（校园网夜间禁网）
- 其他 `msga` → 各类拒绝原因（账号/密码错误、在线数超限等）

已在线时访问 portal 首页会返回 `Dr.COMWebLoginID_3` 状态页。

## 验证

认证生效后，captive 探针（如 `http://connect.rom.miui.com/generate_204`）应返回 **204**。
