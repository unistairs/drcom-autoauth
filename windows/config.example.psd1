@{
    # autoauth 配置文件 —— 复制本文件为 config.psd1 并填入真实值
    # config.psd1 已在 .gitignore 中, 永远不会被提交

    # 校园网账号(必填)
    # 密码不用写在这里: 运行 .\Setup.ps1 时会提示输入, 并用 DPAPI 加密存储(仅本机本用户可解)
    Acc  = "你的校园网账号"

    # 只对这些 SSID 的 Wi-Fi 生效(数组, 有线不受限); 用路由器共享校园网时把路由器 AP 名加进来
    WifiSsids = @("hfut-wlan")

    # portal 候选(真 portal 以劫持页跳转为准, 候选仅兜底)
    PortalCandidates = @("172.18.3.3", "172.18.2.2")

    # captive 检测探针(期望返回 204)
    Canary = "http://connect.rom.miui.com/generate_204"

    # portal 身份校验指纹(按学校实际情况调整)
    PortalSchoolName = "合肥工业大学"
    PortalIdPrefix   = "AH"

    # 校验严格度: normal=前3重指纹+ss5存在即可(兼容路由器/NAT)
    #             strict=追加要求 ss5 等于本机 IP(仅直连校园网时适用)
    PortalCheck = "normal"
}
