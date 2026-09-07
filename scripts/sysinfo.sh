#!/usr/bin/env bash
#
# sysinfo.sh — Cross-platform system info (Linux + macOS)
# Saves output to ~/sysinfo.log
# M1 Max / macOS 26 optimized — covers thermals, power, P/E cores, memory pressure, security, dev stack
#

set -uo pipefail

LOGFILE="$HOME/sysinfo.log"
# Privacy: set ANONYMIZE=0 to include real names/IPs; default is anonymized
ANONYMIZE="${ANONYMIZE:-1}"
REDACTED_USER="redacted-user"
REDACTED_HOST="redacted-host.local"

# --- TTY detection BEFORE exec (so banner can be colored on stderr, log stays plain) ---
_USE_COLOR=0
if [ -t 1 ] || [ -t 2 ]; then
    _USE_COLOR=1
fi
if [ "$_USE_COLOR" = "1" ]; then
    BOLD="\033[1m"
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    CYAN="\033[1;36m"
    YELLOW="\033[1;33m"
    RED="\033[1;31m"
    RESET="\033[0m"
else
    BOLD=""; GREEN=""; BLUE=""; CYAN=""; YELLOW=""; RED=""; RESET=""
fi

echo "${BOLD}Gathering system information... saving to $LOGFILE${RESET}" >&2
[ "$ANONYMIZE" = "1" ] && echo "${YELLOW}(Privacy mode: PII will be redacted)${RESET}" >&2

# Now redirect all stdout to log — force plain text in file (no ANSI)
exec > "$LOGFILE"
# clear colors for file output
BOLD=""; GREEN=""; BLUE=""; CYAN=""; YELLOW=""; RED=""; RESET=""

OS=$(uname -s)
# Capture real values BEFORE redaction for later sed
REAL_USER="${USER:-$(whoami 2>/dev/null || echo unknown)}"
REAL_HOST="$(hostname 2>/dev/null || echo unknown)"
REAL_HOME_RAW="$HOME"
REAL_HOME_ESC=$(printf '%s' "$REAL_HOME_RAW" | sed 's/[\/&|]/\\&/g')

print_header() {
    echo ""
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
}
print_subheader() {
    echo ""
    echo "--- $1 ---"
}

# Report banner (human readable top-matter)
print_header "System Information Report"
echo "Generated : $(date '+%Y-%m-%d %H:%M:%S %Z')"
if [ "$ANONYMIZE" = "1" ]; then
    echo "Hostname  : $REDACTED_HOST"
    echo "User      : $REDACTED_USER"
else
    echo "Hostname  : $REAL_HOST"
    echo "User      : $REAL_USER"
fi
echo "OS        : $OS ($(uname -r) $(uname -m))"

bytes_to_human() {
    local bytes=${1:-0}
    # guard non-numeric / empty
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0.00 B"
        return
    fi
    echo "$bytes" | awk '{
        split("B KB MB GB TB PB", units);
        u=1;
        # 1024 B = 1.00 KB
        while ($1 >= 1024 && u < 6) { $1 /= 1024; u++ }
        printf "%.2f %s\n", $1, units[u]
    }'
}

# ----------------------------------------------------
# 1) HARDWARE SPECIFICATIONS
# ----------------------------------------------------
print_header "1. Hardware Specifications"

print_subheader "CPU Information"
if [ "$OS" = "Linux" ]; then
    if command -v lscpu &>/dev/null; then
        lscpu | grep -E 'Model name|Architecture|CPU\(s\):|Thread\(s\) per core:|Core\(s\) per socket:|CPU max MHz|CPU min MHz'
    elif [ -f /proc/cpuinfo ]; then
        grep -m 1 "model name" /proc/cpuinfo
        echo "Total CPU Cores: $(grep -c "^processor" /proc/cpuinfo)"
    fi
elif [ "$OS" = "Darwin" ]; then
    echo "Model          : $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    echo "Physical Cores : $(sysctl -n hw.physicalcpu 2>/dev/null)"
    echo "Logical Cores  : $(sysctl -n hw.logicalcpu 2>/dev/null)"
    echo "CPU Count      : $(sysctl -n hw.ncpu 2>/dev/null)"
    # Apple Silicon P/E split — critical for M1 Max (8P+2E)
    P_CORES=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "")
    E_CORES=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo "")
    if [ -n "$P_CORES" ] && [ -n "$E_CORES" ]; then
        echo "P-Cores (Perf) : $P_CORES"
        echo "E-Cores (Eff)  : $E_CORES"
        echo "Core Config    : ${P_CORES}P+${E_CORES}E"
    fi
    P_LOGICAL=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null)
    E_LOGICAL=$(sysctl -n hw.perflevel1.logicalcpu 2>/dev/null)
    [ -n "$P_LOGICAL" ] && [ -n "$E_LOGICAL" ] && echo "Logical Split  : ${P_LOGICAL}P+${E_LOGICAL}E"
    # Extra cache / frequency hints
    L2=$(sysctl -n hw.l2cachesize 2>/dev/null); [ -n "$L2" ] && echo "L2 Cache       : $(bytes_to_human "$L2")"
    L3=$(sysctl -n hw.l3cachesize 2>/dev/null); [ -n "$L3" ] && [ "$L3" != "0" ] && echo "L3 Cache       : $(bytes_to_human "$L3")"
    echo "Memory Size    : $(bytes_to_human "$(sysctl -n hw.memsize 2>/dev/null || echo 0)") (Unified Memory on Apple Silicon)"
    # Rosetta 2
    TRANS=$(sysctl -n sysctl.proc_translated 2>/dev/null || echo "")
    if [ "$TRANS" = "1" ]; then
        echo "Rosetta 2      : active (this process translated)"
    elif [ "$TRANS" = "0" ]; then
        echo "Rosetta 2      : native (arm64)"
    fi
    pgrep -q oahd 2>/dev/null && echo "Rosetta Daemon : running (oahd)" || echo "Rosetta Daemon : not running"
else
    echo "OS not recognized for CPU info."
fi

print_subheader "Memory (RAM & Swap) — Detailed"
if [ "$OS" = "Linux" ]; then
    if command -v free &>/dev/null; then
        free -h
    elif [ -f /proc/meminfo ]; then
        grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' /proc/meminfo
    fi
elif [ "$OS" = "Darwin" ]; then
    PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
    # M1 uses 16384; Intel 4096 — detect dynamically above
    VMSTAT=$(vm_stat 2>/dev/null)
    total_mem=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    echo "Total Memory : $(bytes_to_human "$total_mem")"

    if [ -n "$VMSTAT" ]; then
        # Parse all vm_stat fields (strip dots)
        pages_free=$(echo "$VMSTAT" | awk '/Pages free/ {gsub(/\./,""); print $3}')
        pages_active=$(echo "$VMSTAT" | awk '/Pages active/ {gsub(/\./,""); print $3}')
        pages_inactive=$(echo "$VMSTAT" | awk '/Pages inactive/ {gsub(/\./,""); print $3}')
        pages_speculative=$(echo "$VMSTAT" | awk '/Pages speculative/ {gsub(/\./,""); print $3}')
        pages_wired=$(echo "$VMSTAT" | awk '/Pages wired down/ {gsub(/\./,""); print $4}')
        pages_compressed=$(echo "$VMSTAT" | awk '/Pages occupied by compressor/ {gsub(/\./,""); print $5}')
        pages_purgeable=$(echo "$VMSTAT" | awk '/Pages purgeable/ {gsub(/\./,""); print $3}')
        pages_filebacked=$(echo "$VMSTAT" | awk '/File-backed pages/ {gsub(/\./,""); print $3}')
        pages_anonymous=$(echo "$VMSTAT" | awk '/Anonymous pages/ {gsub(/\./,""); print $3}')
        pages_throttled=$(echo "$VMSTAT" | awk '/Pages throttled/ {gsub(/\./,""); print $3}')

        # Default to 0 if empty
        for v in pages_free pages_active pages_inactive pages_speculative pages_wired pages_compressed pages_purgeable pages_filebacked pages_anonymous pages_throttled; do
            eval "[ -z \"\${$v:-}\" ] && $v=0"
        done

        # Correct accounting: macOS wired + active + inactive + speculative + compressed are in use
        # Free is truly free; inactive+speculative are reclaimable but counted as used by old formula
        used_pages=$((pages_active + pages_wired))
        # compressed pages are part of active/inactive but also tracked separately — show both
        reclaimable_pages=$((pages_inactive + pages_speculative + pages_purgeable))
        free_pages=$pages_free
        compressed_pages=$pages_compressed

        echo "  Active       : $(bytes_to_human $((pages_active * PAGE_SIZE))) ($pages_active pages)"
        echo "  Wired        : $(bytes_to_human $((pages_wired * PAGE_SIZE))) ($pages_wired pages)"
        echo "  Inactive     : $(bytes_to_human $((pages_inactive * PAGE_SIZE))) (reclaimable)"
        echo "  Speculative  : $(bytes_to_human $((pages_speculative * PAGE_SIZE))) (reclaimable)"
        echo "  Purgeable    : $(bytes_to_human $((pages_purgeable * PAGE_SIZE)))"
        echo "  Compressed   : $(bytes_to_human $((pages_compressed * PAGE_SIZE))) ($pages_compressed pages)"
        echo "  Free         : $(bytes_to_human $((pages_free * PAGE_SIZE))) ($pages_free pages)"
        [ "$pages_filebacked" != "0" ] && echo "  File-backed  : $(bytes_to_human $((pages_filebacked * PAGE_SIZE)))"
        [ "$pages_anonymous" != "0" ] && echo "  Anonymous    : $(bytes_to_human $((pages_anonymous * PAGE_SIZE)))"
        echo "  Reclaimable  : $(bytes_to_human $((reclaimable_pages * PAGE_SIZE))) (inactive+speculative+purgeable)"

        # Cross-check with top's PhysMem (more user-friendly)
        TOP_MEM=$(top -l 1 -n 0 2>/dev/null | grep -E 'PhysMem')
        [ -n "$TOP_MEM" ] && echo "  top PhysMem  : $TOP_MEM"
    else
        echo "vm_stat not available."
    fi

    # Memory pressure — critical vital for 32GB unified
    if command -v memory_pressure &>/dev/null; then
        echo ""
        echo "Memory Pressure: $(memory_pressure 2>&1 | head -n 5 | tr '\n' ' ')"
        # Also try vm_pressure level via sysctl
        PRESSURE_LEVEL=$(sysctl -n vm.memory_pressure 2>/dev/null || echo "")
        [ -n "$PRESSURE_LEVEL" ] && echo "VM Pressure Level: $PRESSURE_LEVEL"
    fi

    SWAPINFO=$(sysctl -n vm.swapusage 2>/dev/null)
    if [ -n "$SWAPINFO" ]; then
        echo "Swap Info    : $SWAPINFO"
    fi
    COMPRESSOR=$(sysctl -n vm.compressor_mode 2>/dev/null)
    [ -n "$COMPRESSOR" ] && echo "Compressor   : mode $COMPRESSOR"
else
    echo "OS not recognized for memory info."
fi

print_subheader "Disk & Storage Space"
df -h 2>/dev/null | grep -v -E '^(tmpfs|devtmpfs|devfs|map auto_home)' || df -h

if [ "$OS" = "Linux" ] && command -v lsblk &>/dev/null; then
    print_subheader "Block Devices (Disks / Partitions)"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,FSTYPE 2>/dev/null || lsblk
elif [ "$OS" = "Darwin" ] && command -v diskutil &>/dev/null; then
    print_subheader "Disk Layout (diskutil list)"
    diskutil list 2>/dev/null | head -n 30 || echo "diskutil list failed."
    print_subheader "APFS Container"
    diskutil apfs list 2>/dev/null | head -n 40 || echo "diskutil apfs list failed."
    print_subheader "Volume Info (/)"
    diskutil info / 2>/dev/null | grep -E 'Volume Name|File System|APFS|Container|FileVault|Read-Only|Encrypted' | head -n 20
    # SMART if available (via smartctl or diskutil)
    if command -v smartctl &>/dev/null; then
        echo "SMART Status (disk0): $(smartctl -H /dev/disk0 2>/dev/null | grep -E 'SMART|Health' | head -n 2)"
    else
        echo "SMART: $(diskutil info / 2>/dev/null | grep -E 'SMART' | head -n 1 || echo 'smartctl not installed (brew install smartmontools for SSD health)')"
    fi
    # Time Machine
    if command -v tmutil &>/dev/null; then
        print_subheader "Time Machine"
        tmutil status 2>/dev/null | head -n 10 || echo "Time Machine not configured or tmutil failed."
        tmutil destinationinfo 2>/dev/null | head -n 10
    fi
fi

print_subheader "GPU / Display (Unified Memory on Apple Silicon)"
if [ "$OS" = "Linux" ]; then
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    elif command -v lspci &>/dev/null; then
        lspci | grep -i -E 'vga|3d|display' || echo "No dedicated GPU detected via lspci."
    else
        echo "lspci/nvidia-smi not available."
    fi
elif [ "$OS" = "Darwin" ]; then
    if command -v system_profiler &>/dev/null; then
        # timeout 5 to avoid hanging (system_profiler can be slow)
        if command -v timeout &>/dev/null; then
            timeout 5 system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Chipset Model|VRAM|Device ID|Resolution|Displays|Retina|Refresh' | head -n 15 || echo "No GPU info (timeout or no data)"
        else
            system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Chipset Model|VRAM|Device ID|Resolution|Displays|Retina' | head -n 15 || echo "No GPU info available."
        fi
        echo "Note: M1 Max uses Unified Memory — VRAM is shared with system RAM (no dedicated VRAM)"
        # Display resolution
        system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Resolution|Refresh Rate' | head -n 5
    else
        echo "system_profiler not available."
    fi
else
    echo "GPU info not available."
fi

# ----------------------------------------------------
# 2) RESOURCE UTILIZATION & TOP PROCESSES
# ----------------------------------------------------
print_header "2. Resource Utilization & Top Processes"

print_subheader "Top 5 CPU-Consuming Processes (COLUMNS=200, no truncation)"
# Use COLUMNS to prevent ps truncation; generic sort works on both platforms
(COLUMNS=200 ps aux | head -n 1; COLUMNS=200 ps aux | tail -n +2 | sort -k3 -rn | head -n 5) | cut -c 1-200

print_subheader "Top 5 Memory-Consuming Processes"
(COLUMNS=200 ps aux | head -n 1; COLUMNS=200 ps aux | tail -n +2 | sort -k4 -rn | head -n 5) | cut -c 1-200

# Extra: load + process counts
echo ""
echo "Process counts: total $(ps aux | wc -l | tr -d ' ') (incl. header), running $(ps aux | awk '$8 ~ /R/ {c++} END{print c+0}')"
echo "Zombie check  : $(ps aux | awk '$8 ~ /Z/ {print $2, $11}' | head -n 5 || echo 'none')"

print_subheader "Memory Pressure (macOS)"
if [ "$OS" = "Darwin" ]; then
    if command -v memory_pressure &>/dev/null; then
        timeout 3 memory_pressure 2>&1 | head -n 10 || echo "memory_pressure timed out"
    else
        echo "memory_pressure not available"
    fi
    # vm_stat summary line
    vm_stat 2>/dev/null | tail -n 5
else
    echo "Linux: check free -h above"
fi

print_subheader "Disk I/O Statistics"
if command -v iostat &>/dev/null; then
    if [ "$OS" = "Linux" ]; then
        iostat -xz 1 2 2>/dev/null | tail -n +6 | cut -c 1-200 || echo "iostat execution failed."
    elif [ "$OS" = "Darwin" ]; then
        iostat -d -c 2 -w 1 2>/dev/null | cut -c 1-200 || echo "iostat execution failed."
    fi
else
    echo "iostat is not installed."
fi

# CPU usage snapshot via top (more accurate on macOS)
if [ "$OS" = "Darwin" ] && command -v top &>/dev/null; then
    print_subheader "CPU Snapshot (top -l 1)"
    top -l 1 -n 0 2>/dev/null | grep -E 'CPU usage|PhysMem|Load Avg' | head -n 10
fi

# ----------------------------------------------------
# 3) NETWORK STATUS & PORTS
# ----------------------------------------------------
print_header "3. Network Status & Ports"

print_subheader "Network Interfaces & IP Addresses"
if [ "$OS" = "Linux" ] && command -v ip &>/dev/null; then
    ip -brief address show 2>/dev/null || ip addr show
elif command -v ifconfig &>/dev/null; then
    ifconfig
else
    echo "ip/ifconfig not available."
fi

# macOS modern network details
if [ "$OS" = "Darwin" ]; then
    print_subheader "Hardware Ports (networksetup)"
    if command -v networksetup &>/dev/null; then
        networksetup -listallhardwareports 2>/dev/null | head -n 30
    fi
    print_subheader "Wi-Fi Status"
    AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    if [ -x "$AIRPORT" ]; then
        "$AIRPORT" -I 2>/dev/null | grep -E 'SSID|BSSID|MCS|channel|agrCtlRSSI|agrCtlNoise|state|lastTxRate' | head -n 15 || echo "Wi-Fi not connected or airport unavailable"
    else
        echo "airport tool not found"
    fi
    # Bluetooth
    print_subheader "Bluetooth"
    if command -v system_profiler &>/dev/null; then
        if command -v timeout &>/dev/null; then
            timeout 5 system_profiler SPBluetoothDataType 2>/dev/null | head -n 15 || echo "Bluetooth info timeout"
        else
            system_profiler SPBluetoothDataType 2>/dev/null | head -n 15
        fi
    fi
    # VPN check
    print_subheader "VPN / Interfaces (ifconfig brief)"
    ifconfig 2>/dev/null | grep -E '^[a-z0-9]+:|inet |utun|ipsec' | head -n 20
fi

print_subheader "Default Gateway & Routing Table"
if [ "$OS" = "Linux" ] && command -v ip &>/dev/null; then
    ip route show
elif command -v netstat &>/dev/null; then
    netstat -rn 2>/dev/null | head -n 30
else
    echo "ip/netstat not available."
fi

print_subheader "DNS Configuration"
if [ -f /etc/resolv.conf ]; then
    grep "^nameserver" /etc/resolv.conf
    # macOS scutil DNS
    if [ "$OS" = "Darwin" ] && command -v scutil &>/dev/null; then
        echo "--- scutil --dns (first 20 lines) ---"
        scutil --dns 2>/dev/null | head -n 20
    fi
else
    echo "No /etc/resolv.conf found."
fi
# DNS latency quick check
if command -v dig &>/dev/null; then
    echo "DNS lookup (google.com): $(dig +short google.com 2>/dev/null | head -n 1 || echo 'dig failed')"
elif command -v nslookup &>/dev/null; then
    echo "DNS lookup: $(nslookup google.com 2>/dev/null | grep Address | tail -n 1)"
fi

print_subheader "Listening Ports & Services"
if [ "$OS" = "Linux" ]; then
    if command -v ss &>/dev/null; then
        ss -tulpn 2>/dev/null || echo "Unable to retrieve ports (ss failed)."
    elif command -v netstat &>/dev/null; then
        netstat -tulpn 2>/dev/null || echo "Unable to retrieve ports (netstat failed)."
    else
        echo "ss or netstat not available."
    fi
elif [ "$OS" = "Darwin" ]; then
    if command -v lsof &>/dev/null; then
        lsof -i -P -n 2>/dev/null | grep LISTEN | head -n 20 || echo "No listening ports found or lsof requires root."
    elif command -v netstat &>/dev/null; then
        netstat -anv 2>/dev/null | grep LISTEN | head -n 20 || echo "No listening ports found."
    else
        echo "lsof or netstat not available."
    fi
    # Firewall
    print_subheader "Firewall Status"
    FW_BIN="/usr/libexec/ApplicationFirewall/socketfilterfw"
    if [ -x "$FW_BIN" ]; then
        "$FW_BIN" --getglobalstate 2>&1 | head -n 5
        "$FW_BIN" --getblockall 2>&1 | head -n 2
    else
        echo "socketfilterfw not found"
    fi
else
    echo "Platform-specific port lookup not available."
fi

print_subheader "Public IP & Geo Info"
if [ "$ANONYMIZE" = "1" ]; then
    echo "[REDACTED for privacy — set ANONYMIZE=0 to show]"
else
    fetch_ip_json() {
        if command -v curl &>/dev/null; then curl -s --max-time 5 https://ipinfo.io/json 2>/dev/null
        elif command -v wget &>/dev/null; then wget -qO- --timeout=5 https://ipinfo.io/json 2>/dev/null
        else echo ""; fi
    }
    IP_JSON=$(fetch_ip_json)
    if [ -n "$IP_JSON" ]; then
        if command -v jq &>/dev/null; then echo "$IP_JSON" | jq . 2>/dev/null || echo "$IP_JSON"
        elif command -v python3 &>/dev/null; then echo "$IP_JSON" | python3 -m json.tool 2>/dev/null || echo "$IP_JSON"
        else echo "$IP_JSON"; fi
    else
        echo "Unable to fetch public IP (timeout/no connection or curl/wget missing)."
    fi
fi

print_subheader "Internet Connectivity Test"
# ping flags differ: macOS needs -t timeout, Linux -W
if ping -c 2 -W 2 8.8.8.8 &>/dev/null || ping -c 2 -t 2 8.8.8.8 &>/dev/null; then
    echo "[OK] Internet Reachable (ping 8.8.8.8 successful)"
    # latency
    ping -c 3 -W 2 8.8.8.8 2>/dev/null | grep -E 'avg|round-trip' | head -n 1
    ping -c 1 -W 2 1.1.1.1 &>/dev/null && echo "[OK] 1.1.1.1 reachable" || echo "[WARN] 1.1.1.1 ping failed"
else
    echo "[FAIL] Internet Ping Failed"
fi

# ----------------------------------------------------
# 4) SERVICES & ERROR LOGS
# ----------------------------------------------------
print_header "4. Services & Logs"

print_subheader "Failed / Non-Zero Exit Services"
if [ "$OS" = "Linux" ] && command -v systemctl &>/dev/null; then
    systemctl --failed --type=service 2>/dev/null || echo "No failed services or systemctl query failed."
elif [ "$OS" = "Darwin" ] && command -v launchctl &>/dev/null; then
    echo "Non-zero exit services (launchctl):"
    launchctl list 2>/dev/null | awk 'NR>1 && $2 != 0 && $2 != "-" {print}' | head -n 10
    if [ "$(launchctl list 2>/dev/null | awk 'NR>1 && $2 != 0 && $2 != "-" {c++} END{print c+0}')" = "0" ]; then
        echo "No failed services (all exit 0)"
    fi
    # brew services — critical for dev stack (postgres, etc.)
    if command -v brew &>/dev/null; then
        print_subheader "Homebrew Services"
        brew services list 2>/dev/null | head -n 20 || echo "brew services not available"
    fi
else
    echo "systemctl/launchctl not available."
fi

print_subheader "Recent System Error Logs"
if [ "$OS" = "Linux" ] && command -v journalctl &>/dev/null; then
    journalctl -p 3 -xb --no-pager 2>/dev/null | tail -n 10 || echo "No recent error logs or permission denied."
elif [ "$OS" = "Darwin" ] && command -v log &>/dev/null; then
    # Use predicate + timeout to avoid 10s hang and DCP spam
    echo "Unified log (last 5m, errors only, timeout 6s):"
    if command -v timeout &>/dev/null; then
        timeout 6 log show --predicate 'messageType == error' --last 5m --style compact 2>/dev/null | head -n 15 || echo "log show timed out or no errors"
    else
        # fallback: log show with grep but limited
        log show --last 5m --style compact 2>/dev/null | grep -iE 'error|fail|crash|panic' | grep -v -E 'DCP|AirPlayXPCHelper' | head -n 10 || echo "No recent errors in unified log."
    fi
    # Also check diagnostic reports
    if [ -d "$HOME/Library/Logs/DiagnosticReports" ]; then
        echo "--- Recent Crash Reports (last 5) ---"
        ls -lt "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | head -n 6
    fi
else
    echo "journalctl/log not available."
fi

# ----------------------------------------------------
# 5) USER SESSIONS & LOGINS
# ----------------------------------------------------
print_header "5. User Sessions & Logins"

print_subheader "Currently Logged-in Users"
if [ "$ANONYMIZE" = "1" ]; then
    w 2>/dev/null | sed -E "s/$REAL_USER/$REDACTED_USER/g; s/$REAL_HOST/$REDACTED_HOST/g; s/192\.168\.[0-9]+\.[0-9]+/192.168.XXX.XXX/g" || who 2>/dev/null | sed -E "s/$REAL_USER/$REDACTED_USER/g" || echo "Unable to get logged-in users."
else
    w 2>/dev/null || who 2>/dev/null || echo "Unable to get logged-in users."
fi

print_subheader "Recent Login History"
LAST_OUT=$(last -n 5 2>/dev/null | sed -E "s/$REAL_USER/$REDACTED_USER/g; s/192\.168\.[0-9]+\.[0-9]+/192.168.XXX.XXX/g")
if [ -n "$LAST_OUT" ]; then
    if [ "$ANONYMIZE" = "1" ]; then
        echo "$LAST_OUT" | sed -E "s/$REAL_USER/$REDACTED_USER/g"
    else
        echo "$LAST_OUT"
    fi
else
    echo "No recent login history available (last command returned empty)."
fi

# ----------------------------------------------------
# 6) OS SPECIFICATIONS
# ----------------------------------------------------
print_header "6. OS Specifications"

print_subheader "Operating System & Distribution"
if [ "$OS" = "Linux" ]; then
    if [ -f /etc/os-release ]; then
        grep -E '^(PRETTY_NAME|NAME|VERSION|ID)=' /etc/os-release | tr -d '"'
    elif command -v lsb_release &>/dev/null; then
        lsb_release -a
    fi
elif [ "$OS" = "Darwin" ]; then
    if command -v sw_vers &>/dev/null; then
        sw_vers
    fi
else
    uname -s
fi

print_subheader "Kernel & Architecture"
echo "Kernel Release: $(uname -r)"
echo "Architecture  : $(uname -m)"
echo "Full Kernel   : $(uname -v)"
if [ "$OS" = "Darwin" ]; then
    echo "Xcode CLT     : $(xcode-select -p 2>&1)"
    xcrun --show-sdk-path 2>/dev/null && echo "SDK Path      : $(xcrun --show-sdk-path 2>/dev/null)"
    echo "Rosetta Check : sysctl.proc_translated=$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 'n/a')"
fi

print_subheader "Hostname & Uptime"
if [ "$ANONYMIZE" = "1" ]; then
    echo "Hostname      : $REDACTED_HOST"
    echo "Current User  : $REDACTED_USER"
else
    echo "Hostname      : $(hostname)"
    echo "Current User  : ${USER:-$(whoami)}"
fi
echo "System Uptime : $(uptime -p 2>/dev/null || uptime | sed -E "s/$REAL_USER/$REDACTED_USER/g; s/$REAL_HOST/$REDACTED_HOST/g")"
uptime 2>/dev/null | sed -E "s/$REAL_USER/$REDACTED_USER/g; s/$REAL_HOST/$REDACTED_HOST/g"

print_subheader "Load Average"
if [ "$OS" = "Linux" ] && [ -f /proc/loadavg ]; then
    echo "Load Average  : $(cut -d' ' -f1-3 /proc/loadavg)"
elif [ "$OS" = "Darwin" ]; then
    echo "Load Average  : $(sysctl -n vm.loadavg 2>/dev/null | sed 's/[{}]//g')"
else
    echo "Load Average  : $(uptime | awk -F'load average[s]*:' '{ print $2 }' | xargs)"
fi

print_subheader "Security Posture"
if [ "$OS" = "Darwin" ]; then
    echo "FileVault     : $(fdesetup status 2>&1 | head -n 1)"
    echo "SIP           : $(csrutil status 2>&1 | head -n 1)"
    echo "Gatekeeper    : $(spctl --status 2>&1 | head -n 1)"
    FW_BIN="/usr/libexec/ApplicationFirewall/socketfilterfw"
    if [ -x "$FW_BIN" ]; then
        echo "Firewall      : $("$FW_BIN" --getglobalstate 2>&1 | head -n 1)"
    fi
    # XProtect / MRT
    system_profiler SPSoftwareDataType 2>/dev/null | grep -E 'System Integrity|Secure Virtual Memory' | head -n 3
elif [ "$OS" = "Linux" ]; then
    echo "SELinux/AppArmor: $(getenforce 2>/dev/null || aa-status 2>/dev/null | head -n 1 || echo 'not detected')"
fi

# ----------------------------------------------------
# 7) APPLE SILICON & POWER (Darwin)
# ----------------------------------------------------
if [ "$OS" = "Darwin" ]; then
    print_header "7. Apple Silicon & Power"

    print_subheader "Battery & Power"
    if command -v pmset &>/dev/null; then
        echo "--- pmset -g batt ---"
        pmset -g batt 2>&1 | head -n 10
        echo "--- pmset -g therm ---"
        pmset -g therm 2>&1 | head -n 10
        echo "--- pmset -g assertions (no sleep) ---"
        pmset -g assertions 2>&1 | grep -E 'NoIdleSleepAssertion|PreventUserIdleSystemSleep|BackgroundTask' | head -n 10 || echo "No blocking assertions"
        echo "--- pmset -g (power settings) ---"
        pmset -g 2>&1 | grep -E 'sleep|displaysleep|disksleep|powermode|highpowermode|lowpowermode' | head -n 10
    fi
    print_subheader "Power Data (system_profiler SPPowerDataType)"
    if command -v system_profiler &>/dev/null; then
        if command -v timeout &>/dev/null; then
            timeout 5 system_profiler SPPowerDataType 2>/dev/null | grep -E 'Battery Health|Cycle Count|Condition|Capacity|Amperage|Voltage|Wattage|Charging' | head -n 15 || echo "No power data (timeout)"
        else
            system_profiler SPPowerDataType 2>/dev/null | grep -E 'Battery Health|Cycle Count|Condition|Capacity|Amperage|Voltage' | head -n 15
        fi
        # Also try ioreg for battery (faster)
        if command -v ioreg &>/dev/null; then
            echo "--- ioreg Battery ---"
            ioreg -r -k BatteryHealth 2>/dev/null | grep -E 'Capacity|Health|CycleCount|Temperature' | head -n 10 || true
            ioreg -r -c AppleSmartBattery 2>/dev/null | grep -E '"CycleCount"|"Condition"|"BatteryHealth"' | head -n 5 || true
        fi
    fi

    print_subheader "Thermal & Sensors"
    # Try powermetrics without sudo (limited) — timeout quickly
    if command -v powermetrics &>/dev/null; then
        echo "powermetrics (SMC, 1 sample, timeout 4s):"
        if command -v timeout &>/dev/null; then
            if sudo -n powermetrics --samplers smc -n 1 2>&1 | head -n 30; then
                timeout 4 sudo -n powermetrics --samplers smc -n 1 2>&1 | head -n 30 || echo "powermetrics requires sudo (skipped)"
            else
                timeout 4 powermetrics --samplers smc -n 1 2>&1 | head -n 20 || echo "powermetrics requires sudo/password (skipped — run: sudo powermetrics --samplers smc -n 1)"
            fi
        else
            echo "powermetrics available — run manually: sudo powermetrics --samplers smc -n 1"
        fi
    else
        echo "powermetrics not found"
    fi
    # Thermal level sysctl (if exists)
    THERM_LEVEL=$(sysctl -n machdep.xcpm.thermal_level 2>/dev/null || sysctl -n kern.thermal_level 2>/dev/null || echo "")
    [ -n "$THERM_LEVEL" ] && echo "Thermal Level : $THERM_LEVEL"

    print_subheader "Display & Power Mode"
    if command -v system_profiler &>/dev/null; then
        if command -v timeout &>/dev/null; then
            timeout 5 system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Resolution|Refresh|Main Display|Connection Type' | head -n 10
        fi
    fi
    # Low Power Mode
    defaults read /Library/Preferences/com.apple.PowerManagement 2>/dev/null | grep -i lowpowermode | head -n 5 || true
fi

# ----------------------------------------------------
# 8) DEV TOOLCHAIN (per AGENTS.md)
# ----------------------------------------------------
print_header "8. Dev Toolchain"

print_subheader "Homebrew"
if command -v brew &>/dev/null; then
    brew --version 2>&1 | head -n 2
    echo "Brew prefix   : $(brew --prefix 2>&1 | head -n 1)"
    echo "Brew packages : $(brew list 2>/dev/null | wc -l | tr -d ' ') installed"
    # outdated check (quick)
    echo "Outdated      : $(brew outdated 2>/dev/null | head -n 10 | tr '\n' ' ' || echo 'none or check failed')"
else
    echo "Homebrew not installed"
fi

print_subheader "Languages & Runtimes"
command -v java &>/dev/null && java -version 2>&1 | head -n 2 || echo "Java: not found"
command -v clojure &>/dev/null && clojure --version 2>&1 | head -n 2 || echo "Clojure CLI: not found"
command -v lein &>/dev/null && lein --version 2>&1 | head -n 1 || echo "Leiningen: not found"
command -v node &>/dev/null && echo "Node: $(node --version 2>&1)" || echo "Node: not found"
command -v python3 &>/dev/null && echo "Python: $(python3 --version 2>&1)" || echo "Python3: not found"
command -v psql &>/dev/null && psql --version 2>&1 | head -n 1 || echo "PostgreSQL client: not found"
command -v sqlite3 &>/dev/null && sqlite3 --version 2>&1 | head -n 1 | xargs echo "SQLite:" || echo "SQLite: not found"

print_subheader "Containers & AI"
command -v docker &>/dev/null && docker --version 2>&1 | head -n 1 || echo "Docker: not found"
if command -v docker &>/dev/null; then
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>&1 | head -n 10 || echo "docker ps failed (daemon not running?)"
fi
command -v ollama &>/dev/null && ollama list 2>&1 | head -n 15 || echo "Ollama: not found or not running"
command -v colima &>/dev/null && colima status 2>&1 | head -n 10 || true

print_subheader "Emacs / Tooling"
command -v emacs &>/dev/null && emacs --version 2>&1 | head -n 1 || echo "Emacs: not found"
command -v nvim &>/dev/null && nvim --version 2>&1 | head -n 1 || true
command -v git &>/dev/null && git --version 2>&1 | head -n 1 || echo "Git: not found"

print_subheader "Pending Updates (macOS)"
if [ "$OS" = "Darwin" ] && command -v softwareupdate &>/dev/null; then
    echo "Checking softwareupdate -l (timeout 10s)..."
    if command -v timeout &>/dev/null; then
        timeout 10 softwareupdate -l 2>&1 | head -n 20 || echo "softwareupdate timed out or no updates"
    else
        echo "softwareupdate available — run manually: softwareupdate -l"
    fi
fi

print_header "Report Complete"
echo "Finished : $(date '+%Y-%m-%d %H:%M:%S %Z')"
if [ "$ANONYMIZE" = "1" ]; then
    echo "Log saved: \$HOME/sysinfo.log (anonymized)"
else
    echo "Log saved: $LOGFILE"
fi

# --- Final privacy pass: redact any remaining PII leaked via ps/ifconfig/netstat/lsof ---
if [ "$ANONYMIZE" = "1" ]; then
    exec 1>&2
    REAL_USER_ESC=$(printf '%s' "$REAL_USER" | sed 's/[\/&|]/\\&/g')
    REAL_HOST_SHORT=$(printf '%s' "$REAL_HOST" | cut -d. -f1 | sed 's/[\/&|]/\\&/g')
    # Use | as delimiter; HOME already escaped
    if [ "$OS" = "Darwin" ]; then
        sed -i '' \
            -e "s|$REAL_USER_ESC|$REDACTED_USER|g" \
            -e "s|$REAL_HOST|$REDACTED_HOST|g" \
            -e "s|$REAL_HOST_SHORT|$REDACTED_HOST|g" \
            -e 's/[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}/XX:XX:XX:XX:XX:XX/g' \
            -e 's/192\.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.XXX.XXX/g' \
            -e "s|$REAL_HOME_ESC|\$HOME|g" \
            "$LOGFILE" 2>/dev/null || true
    else
        sed -i \
            -e "s|$REAL_USER_ESC|$REDACTED_USER|g" \
            -e "s|$REAL_HOST|$REDACTED_HOST|g" \
            -e "s|$REAL_HOST_SHORT|$REDACTED_HOST|g" \
            -e 's/[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}/XX:XX:XX:XX:XX:XX/g' \
            -e 's/192\.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.XXX.XXX/g' \
            -e "s|$REAL_HOME_ESC|\$HOME|g" \
            "$LOGFILE" 2>/dev/null || true
    fi
    exec >> "$LOGFILE"
    echo ""
    echo "[Privacy] PII redacted (user, hostname, MACs, private IPs). Set ANONYMIZE=0 to disable."
fi
print_header "Execution Finished Successfully"
