#!/usr/bin/env bash
# Setup capture traffic HP Android (rooted) lewat mitmproxy.
# Pakai:
#   ./run.sh                 # capture SEMUA app
#   ./run.sh flip.id         # filter: cuma detail request ke domain flip.id
#   ./run.sh flip.id id.flip # + auto-buka app id.flip
#
# Prasyarat: HP rooted + USB debugging, adb, mitmproxy (pip install mitmproxy), openssl.
# Untuk app ber-SSL-pinning (mis. Flip): pasang modul LSPosed "TrustMe" + scope ke app-nya dulu.
set -e
FILTER="${1:-all}"
PKG="${2:-}"
PORT="${PORT:-8080}"
ADB="${ADB:-adb}"
MITMDUMP="${MITMDUMP:-mitmdump}"
DIR="$(cd "$(dirname "$0")" && pwd)"
export MSYS_NO_PATHCONV=1   # Windows/git-bash: jangan translate path /data/...

# konversi path ke Windows kalau di git-bash (buat openssl.exe & adb push source)
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

echo "== cek device =="
"$ADB" get-state >/dev/null 2>&1 || { echo "HP tidak terhubung / belum authorize adb"; exit 1; }
"$ADB" shell 'su -c id' 2>/dev/null | grep -q 'uid=0' || { echo "HP tidak rooted (butuh su)"; exit 1; }

echo "== start mitmproxy (FILTER=$FILTER) =="
# bunuh yang lama di port ini
if command -v taskkill >/dev/null 2>&1; then taskkill //F //IM mitmdump.exe >/dev/null 2>&1 || true; else pkill -f mitmdump >/dev/null 2>&1 || true; fi
sleep 1
rm -f "$DIR/all.txt" "$DIR/capture.txt"
CAP_FILTER="$FILTER" CAP_OUT="$DIR" "$MITMDUMP" -s "$(winpath "$DIR/capture.py")" --listen-host 0.0.0.0 -p "$PORT" --set block_global=false > "$DIR/mitm.log" 2>&1 &
sleep 4

echo "== install CA mitmproxy ke system store (bind-mount) =="
CERT="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
[ -f "$CERT" ] || { echo "CA belum dibuat, mitmproxy gagal start? cek mitm.log"; exit 1; }
HASH="$(openssl x509 -inform PEM -subject_hash_old -in "$(winpath "$CERT")" -noout)"
cp "$CERT" "$DIR/$HASH.0"
"$ADB" push "$(winpath "$DIR/$HASH.0")" "/data/local/tmp/$HASH.0" >/dev/null
"$ADB" shell "su -c 'for i in 1 2 3; do umount /system/etc/security/cacerts 2>/dev/null; done; rm -rf /data/local/tmp/cc; mkdir -p /data/local/tmp/cc; cp -f /system/etc/security/cacerts/* /data/local/tmp/cc/ 2>/dev/null; cp -f /data/local/tmp/$HASH.0 /data/local/tmp/cc/; chmod 644 /data/local/tmp/cc/*; chcon u:object_r:system_file:s0 /data/local/tmp/cc/* 2>/dev/null; mount --bind /data/local/tmp/cc /system/etc/security/cacerts; ls /system/etc/security/cacerts/$HASH.0 >/dev/null 2>&1 && echo CA_OK || echo CA_FAIL'"

echo "== arahkan traffic HP ke mitmproxy =="
"$ADB" reverse tcp:$PORT tcp:$PORT >/dev/null
"$ADB" shell settings put global http_proxy localhost:$PORT

[ -n "$PKG" ] && { echo "== buka $PKG =="; "$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true; }

echo
echo "SIAP CAPTURE. Buka app di HP & lakukan aksinya."
echo "  detail  -> $DIR/capture.txt   (request/response, filter: $FILTER)"
echo "  semua   -> $DIR/all.txt       (daftar host/path semua request)"
echo "Live: tail -f \"$DIR/all.txt\"    atau    tail -f \"$DIR/capture.txt\""
echo "Selesai? jalankan: ./stop.sh"
