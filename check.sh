#!/bin/bash

log() {
    echo "[*] $1"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID,,}" # chuyển thành chữ thường
        case "$DISTRO_ID" in
            ubuntu|debian|kali)
                OS="debian"
                PKG_MGR="apt"
                FIREWALL="ufw"
                ;;
            almalinux|rocky|centos|rhel|cloudlinux|fedora)
                OS="rhel"
                PKG_MGR=$(command -v dnf >/dev/null 2>&1 && echo "dnf" || echo "yum")
                FIREWALL="firewalld"
                ;;
            opensuse*|suse)
                OS="suse"
                PKG_MGR="zypper"
                FIREWALL="firewalld"
                ;;
            alpine)
                OS="alpine"
                PKG_MGR="apk"
                FIREWALL="none"
                ;;
            arch)
                OS="arch"
                PKG_MGR="pacman"
                FIREWALL="none"
                ;;
            *)
                echo "[!] Unsupported OS: $DISTRO_ID"
                exit 1
                ;;
        esac
    else
        echo "[!] Cannot detect OS."
        exit 1
    fi
}

install_dependencies() {
    log "Detected OS: $DISTRO_ID ($OS)"
    log "Installing: net-tools, jq, lsof, curl"

    case "$PKG_MGR" in
        apt)
            sudo apt update -y && sudo apt install -y net-tools jq lsof curl >/dev/null
            ;;
        dnf|yum)
            sudo $PKG_MGR install -y epel-release >/dev/null 2>&1
            sudo $PKG_MGR install -y net-tools jq lsof curl >/dev/null
            ;;
        apk)
            sudo apk update && sudo apk add net-tools jq lsof curl >/dev/null
            ;;
        pacman)
            sudo pacman -Sy --noconfirm net-tools jq lsof curl >/dev/null
            ;;
        zypper)
            sudo zypper refresh && sudo zypper install -y net-tools jq lsof curl >/dev/null
            ;;
        *)
            echo "[!] Unsupported package manager: $PKG_MGR"
            exit 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        log "Dependencies installed successfully."
    else
        echo "[!] Failed to install packages."
        exit 1
    fi
}

detect_os
install_dependencies

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
