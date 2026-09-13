# 卸载 autoauth 计划任务
Stop-ScheduledTask -TaskName "DrComAutoAuth" -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "DrComAutoAuth" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "已卸载(脚本与配置保留, 可手动删除)"
