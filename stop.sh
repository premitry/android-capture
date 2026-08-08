#!/usr/bin/env bash
# Bersihkan setup capture: matikan proxy HP, lepas CA, stop mitmproxy.
PORT="${PORT:-8080}"
ADB="${ADB:-adb}"
export MSYS_NO_PATHCONV=1

echo "== matikan proxy HP =="
"$ADB" shell settings put global http_proxy :0 2>/dev/null || true
"$ADB" reverse --remove-all 2>/dev/null || true

echo "== lepas CA mitmproxy dari system store =="
"$ADB" shell "su -c 'for i in 1 2 3 4; do umount /system/etc/security/cacerts 2>/dev/null; done; rm -rf /data/local/tmp/cc; echo done'" 2>/dev/null || true

echo "== stop mitmproxy =="
# Windows: mitmdump.exe cuma launcher — proses asli python.exe. Kill by-PORT biar benar2 mati.
if command -v netstat >/dev/null 2>&1 && command -v taskkill >/dev/null 2>&1; then
  for pid in $(netstat -ano 2>/dev/null | grep -i LISTENING | grep ":$PORT " | awk '{print $NF}' | sort -u); do
    taskkill //F //PID "$pid" >/dev/null 2>&1 || true
  done
fi
command -v fuser >/dev/null 2>&1 && fuser -k "$PORT/tcp" >/dev/null 2>&1 || true
command -v pkill >/dev/null 2>&1 && pkill -f "mitmdump" >/dev/null 2>&1 || true

echo "Selesai. HP kembali normal (proxy off, CA MITM dilepas)."
echo "File hasil capture (all.txt/capture.txt) TIDAK dihapus — hapus manual bila mengandung data sensitif."
