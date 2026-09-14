#!/bin/bash
# Dr.COM 校园网 portal 自动认证看门狗 (macOS)
# 工作机制: 每条活跃链路独立 captive 检测 -> 被劫持则顺劫持跳转找真 portal ->
#   四重指纹校验防钓鱼 -> 读取 ps/pid/calg -> MD5/base64 编码密码 -> POST 登录 -> msga 判定 -> 验证
# 依赖: bash, curl, iconv, networksetup(macOS 自带)。无需 root。
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
LOG="$BASE/autoauth.log"
CONF="$BASE/config.sh"

if [ ! -f "$CONF" ]; then
  echo "$(date '+%m-%d %H:%M:%S') 缺少 $CONF —— 请复制 config.example.sh 为 config.sh 并填入账号密码" >> "$LOG" 2>/dev/null
  exit 1
fi
# shellcheck source=/dev/null
. "$CONF"
: "${ACC:?config.sh 里缺少 ACC(账号)}"
if [ -z "${PASS:-}" ] && [ -z "${PASS_HASH:-}" ]; then
  echo "$(date '+%m-%d %H:%M:%S') config.sh 里缺少 PASS(明文) 或 PASS_HASH(哈希, 推荐)" >> "$LOG" 2>/dev/null
  exit 1
fi
# 逗号分隔的 SSID 白名单(兼容旧版单值 WIFI_SSID_REQUIRED);
# 用路由器/热点共享校园网时, 把路由器的 AP 名也加进来, 如 "hfut-wlan,宿舍路由"
WIFI_SSIDS="${WIFI_SSIDS:-${WIFI_SSID_REQUIRED:-hfut-wlan}}"
PORTAL_CANDIDATES="${PORTAL_CANDIDATES:-172.18.3.3 172.18.2.2}"
CANARY="${CANARY:-http://connect.rom.miui.com/generate_204}"

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

wifi_if() { networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{f=1} f&&/^Device: /{print $2; exit}'; }

# 活跃链路(接口 IP): Wi-Fi(仅指定 SSID) + 所有活跃有线
active_legs() {
  local wif ssid=""
  wif=$(wifi_if)
  for if in $(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port:/{hp=$0}/^Device: /{d=$2; if (hp ~ /(LAN|Ethernet|Wi-Fi)/ && hp !~ /Bridge/) print d}'); do
    ip=$(ipconfig getifaddr "$if" 2>/dev/null)
    [ -z "$ip" ] && continue
    if [ "$if" = "$wif" ]; then
      ssid=$(networksetup -getairportnetwork "$if" 2>/dev/null | sed 's/^Current Wi-Fi Network: //')
      # 逗号分隔白名单匹配(支持含空格的 SSID)
      _allowed=1; _oldifs=$IFS; IFS=','
      for _w in $WIFI_SSIDS; do
        _w=$(echo "$_w" | sed 's/^ *//;s/ *$//')
        [ "$ssid" = "$_w" ] && { _allowed=0; break; }
      done
      IFS=$_oldifs
      [ $_allowed -ne 0 ] && continue
    fi
    echo "$if $ip"
  done
}

# captive 检测: 输出 HTTP 码, 页面存 $2
captive_check() { # $1=源IP $2=输出文件
  curl --noproxy '' -sS --interface "$1" --connect-timeout 4 --max-time 8 \
    "$CANARY" -o "$2" -w '%{http_code}' 2>/dev/null
}

extract_portal_ip() { # $1=页面文件
  grep -oE 'https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null | head -1 | sed -E 's#https?://##'
}

# portal 身份四重指纹校验(全部通过才交凭据):
#  1) Dr.COM 系统标记 2) 校名指纹 3) AH 机构编号 4) ss5 必须等于本机该链路 IP(会话绑定)
# portal 身份指纹校验: 前 3 重是防钓鱼牙齿(系统/校名/机构编号), 第 4 重 ss5 会话绑定
# 在 NAT/路由器后永远失配(portal 看到的是路由器 IP), 故默认 normal 模式只要求 ss5 存在且是 IP;
# 需要最强校验可设 PORTAL_CHECK=strict(要求 ss5 等于本机该链路 IP)。失败原因输出到 stdout 供日志记录。
verify_portal() { # $1=源IP $2=portalIP
  local page
  page=$(curl --noproxy '' -sS --interface "$1" --connect-timeout 3 --max-time 6 "http://$2/" 2>/dev/null | iconv -f GB2312 -t UTF-8 2>/dev/null)
  [ -z "$page" ] && { echo "无法访问/无响应"; return 1; }
  echo "$page" | grep -q "Dr.COMWebLoginID" || { echo "非 Dr.COM 页面(无系统标记)"; return 1; }
  echo "$page" | grep -q -E "Dr.COMWebLoginID_3|已经成功登录" && return 0   # 已在线状态页同样是真 portal 指纹
  echo "$page" | grep -q "portalname='${PORTAL_SCHOOL_NAME:-合肥工业大学}" || { echo "校名不匹配(需 ${PORTAL_SCHOOL_NAME:-合肥工业大学})"; return 1; }
  echo "$page" | grep -qE "portalid='${PORTAL_ID_PREFIX:-AH}[0-9]+" || { echo "portalid 不匹配(需 ${PORTAL_ID_PREFIX:-AH} 开头)"; return 1; }
  if [ "${PORTAL_CHECK:-normal}" = "strict" ]; then
    echo "$page" | grep -q "ss5='$1'" || { echo "ss5 会话绑定不符(strict 模式要求等于本机 IP)"; return 1; }
  else
    echo "$page" | grep -qE "ss5='[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'" || { echo "缺少 ss5 会话字段"; return 1; }
  fi
  return 0
}

# 劫持跳转 hint 只允许指向校园私网段(防公网钓鱼页)
valid_hint_ip() { echo "$1" | grep -qE '^172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+$'; }

do_login() { # $1=源IP $2=portal; 0=成功 1=失败 2=失败且 LOGIN_MSG 有服务端原因
  local src=$1 portal=$2 js pid calg ps upass r2 resp
  LOGIN_MSG=""
  js=$(curl --noproxy '' -sS --interface "$src" --connect-timeout 3 --max-time 6 "http://$portal/a41.js" 2>/dev/null | head -1)
  pid=$(echo "$js" | sed -n "s/.*pid='\([^']*\)'.*/\1/p"); pid=${pid:-2}
  calg=$(echo "$js" | sed -n "s/.*calg='\([^']*\)'.*/\1/p"); calg=${calg:-12345678}
  ps=$(echo "$js" | sed -n 's/.*ps=\([0-9]\).*/\1/p'); ps=${ps:-1}
  if [ "$ps" = "0" ]; then
    # base64 模式必须明文
    if [ -n "${PASS:-}" ]; then upass=$(printf '%s' "$PASS" | base64); r2=0
    else log "该 portal 为 base64(ps=0)模式, 哈希不可用, 请在 config 里改用明文 PASS"; return 1; fi
  else
    if [ -n "${PASS_HASH:-}" ]; then
      # 哈希直接复用: upass = MD5(pid+密码+calg)+calg+pid, 常量不匹配则哈希无效
      if [ "$pid" != "2" ] || [ "$calg" != "12345678" ]; then
        log "portal 参数(pid=$pid,calg=$calg)与存储哈希不匹配, 请用 setup 重新配置或改明文 PASS"; return 1
      fi
      upass="${PASS_HASH}${calg}${pid}"; r2=1
    else
      upass="$(md5 -q -s "${pid}${PASS}${calg}")${calg}${pid}"; r2=1
    fi
  fi
  resp=$(curl --noproxy '' -sS --interface "$src" --connect-timeout 5 --max-time 12 -X POST "http://$portal/0.htm" \
    --data-urlencode "DDDDD=$ACC" --data-urlencode "upass=$upass" \
    --data-urlencode "R1=0" --data-urlencode "R2=$r2" --data-urlencode "para=00" \
    --data-urlencode "0MKKey=123456" --data-urlencode "v6ip=" 2>/dev/null | iconv -f GB2312 -t UTF-8 2>/dev/null)
  # 先解析服务端 msga(失败原因): 非空即失败, 页面模板里的"成功"字样不算数
  LOGIN_MSG=$(echo "$resp" | grep -o "msga='[^']*'" | head -1 | cut -d"'" -f2)
  if [ -n "$LOGIN_MSG" ]; then return 2; fi
  echo "$resp" | grep -q "成功" && return 0
  return 1
}

# 宵禁退避: 发现"本时段禁止"后 30 分钟内不再尝试
curfew_active() {
  local f="$BASE/.curfew_seen" now mtime
  [ -f "$f" ] || return 1
  now=$(date +%s); mtime=$(stat -f %m "$f")
  [ $((now - mtime)) -lt 1800 ]
}

active_legs | while read -r if ip; do
  [ -z "$if" ] && continue
  page="$BASE/.captive.$if.html"
  code=$(captive_check "$ip" "$page")
  case "$code" in
    204) : ;;
    000) log "[$if/$ip] 无响应(链路不通), 跳过" ;;
    *)
      log "[$if/$ip] 检测到 portal 劫持 (HTTP $code), 开始认证"
      hint=$(extract_portal_ip "$page")
      portal=""
      for c in $hint $PORTAL_CANDIDATES; do
        [ -z "$c" ] && continue
        if [ "$c" = "$hint" ] && ! valid_hint_ip "$c"; then
          log "[$if/$ip] 劫持跳转到非校园地址 $c, 可疑, 跳过"
          continue
        fi
        _why=$(verify_portal "$ip" "$c") && { portal=$c; break; }
        log "[$if/$ip] $c 身份校验未通过($_why), 拒交凭据"
      done
      if [ -z "$portal" ]; then log "[$if/$ip] 未找到可信 portal (hint=$hint), 放弃本轮"; continue; fi
      if curfew_active; then continue; fi
      do_login "$ip" "$portal"
      rc=$?
      if [ $rc -eq 0 ]; then
        rm -f "$BASE/.curfew_seen"
        sleep 2
        v=$(captive_check "$ip" "$page")
        if [ "$v" = "204" ]; then log "[$if/$ip] 认证成功(portal=$portal), 链路已通"
        else log "[$if/$ip] 登录响应成功但验证仍为 $v, 下轮重试(portal=$portal)"; fi
      elif [ $rc -eq 2 ]; then
        case "$LOGIN_MSG" in
          *时段*|*禁止*)
            date +%s > "$BASE/.curfew_seen"
            log "[$if/$ip] 校园网宵禁时段($LOGIN_MSG), 30 分钟后再试" ;;
          *)
            log "[$if/$ip] 登录被拒绝(portal=$portal): $LOGIN_MSG" ;;
        esac
      else
        log "[$if/$ip] 登录失败(portal=$portal), 下轮重试"
      fi
      ;;
  esac
done
