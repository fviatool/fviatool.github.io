#!/bin/bash

# Cập nhật & cài đặt các công cụ cần thiết
echo "[*] Installing required tools: net-tools, jq, lsof, curl..."
sudo apt update -y >/dev/null
sudo apt install -y net-tools jq lsof curl >/dev/null || {
  echo "[!] Failed to install dependencies."
  exit 1
}

echo "[*] Scanning open ports..."

# Thu thập toàn bộ cổng đang mở (LISTEN)
ports=$(
  (netstat -tuln 2>/dev/null | awk '/LISTEN/{print $4}' | grep -oE '[0-9]+$') \
  || (lsof -i -P -n 2>/dev/null | grep LISTEN | awk '{print $9}' | grep -oE '[0-9]+$')
)

# Loại trùng và sắp xếp
echo "$ports" | sort -nu | \
xargs -I{} -P200 bash -c '
port="{}"

get_ip() {
  for svc in https://api64.ipify.org https://httpbin.org/ip https://ifconfig.me http://ipecho.net/plain; do
    ip=$(curl -s --max-time 10 --proxy http://localhost:$port "$svc" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
    [[ -n "$ip" ]] && echo "$ip" && return
  done
  echo ""
}

get_country() {
  local ip="$1"
  local apis=( "http://ip-api.com/json/$ip" "https://ipinfo.io/$ip/json" "https://ipwhois.app/json/$ip" )
  for api in "${apis[@]}"; do
    country=$(curl -s --max-time 10 "$api" | jq -r ".country")
    [[ "$country" != "null" && -n "$country" ]] && echo "$country" && return
  done
  echo "Không xác định"
}

get_speed() {
  curl -s --max-time 15 --proxy http://localhost:$port http://speedtest.tele2.net/100MB.zip -o /dev/null -w "%{speed_download}" | \
  awk "{printf \"%.2f Mbps\", \$1/1024/1024}"
}

get_facebook_speed() {
  curl -s --max-time 15 --proxy http://localhost:$port -o /dev/null -w "%{time_total}" https://www.facebook.com | \
  awk "{printf \"%.2f s\", \$1}"
}

ip=$(get_ip)
if [[ -n "$ip" ]]; then
  country=$(get_country "$ip")
  speed=$(get_speed)
  fb_speed=$(get_facebook_speed)
  echo "✅ Port $port | IP: $ip | Quốc gia: $country | Speed: $speed | FB Load: $fb_speed" | tee -a live_proxy.txt
else
  echo "❌ Port $port failed" | tee -a die_proxy.txt
fi
' | tee proxy_results.log
