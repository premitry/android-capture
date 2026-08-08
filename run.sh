#!/usr/bin/env bash
# Setup capture traffic HP Android (rooted) lewat mitmproxy.
# Pakai:
#   ./run.sh                               # capture SEMUA app
#   ./run.sh nama-domain.com               # filter: cuma detail request ke domain itu
#   ./run.sh nama-domain.com com.nama.app  # filter domain + auto-buka app
#   ./run.sh "" com.nama.app               # AUTO by-app: buka app, tampilkan domainnya (buang noise)
# (atau isi DOMAIN / PKG di target.txt — PKG doang = mode AUTO by-app)
#
# Prasyarat: HP rooted + USB debugging, adb, mitmproxy (pip install mitmproxy), openssl.
# Untuk app ber-SSL-pinning (umum di app bank/e-wallet): pasang modul LSPosed "TrustMe"
# (APK ada di modules/) + scope ke app-nya dulu.
set -e
PORT="${PORT:-8080}"
ADB="${ADB:-adb}"
MITMDUMP="${MITMDUMP:-mitmdump}"
DIR="$(cd "$(dirname "$0")" && pwd)"
export MSYS_NO_PATHCONV=1   # Windows/git-bash: jangan translate path /data/...

# Target: argumen command-line kalau ada; kalau tidak, baca dari target.txt.
FILTER="${1:-}"
PKG="${2:-}"
if [ -z "$FILTER" ] && [ -f "$DIR/target.txt" ]; then
  # ambil DOMAIN= dan PKG= (abaikan komentar/spasi)
  T_DOMAIN="$(grep -E '^[[:space:]]*DOMAIN[[:space:]]*=' "$DIR/target.txt" | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
  T_PKG="$(grep -E '^[[:space:]]*PKG[[:space:]]*=' "$DIR/target.txt" | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
  [ -n "$T_DOMAIN" ] && FILTER="$T_DOMAIN"
  [ -z "$PKG" ] && [ -n "$T_PKG" ] && PKG="$T_PKG"
fi
# Tentukan mode:
#   DOMAIN diisi          -> filter domain itu
#   DOMAIN kosong + PKG    -> "auto": buka app, tampilkan domainnya, buang noise (google/iklan/dll)
#   dua-duanya kosong      -> "all": capture semua app
if [ -z "$FILTER" ]; then
  if [ -n "$PKG" ]; then FILTER="auto"; else FILTER="all"; fi
fi
case "$FILTER" in
  all)  echo "Mode: SEMUA app (capture semua)";;
  auto) echo "Mode: AUTO by-app${PKG:+ ($PKG)} -> tampilkan domain app, buang noise";;
  *)    echo "Mode: filter domain '$FILTER'${PKG:+  (auto-buka: $PKG)}";;
esac

# konversi path ke Windows kalau di git-bash (buat openssl.exe & adb push source)
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

echo "== cek dependency =="
command -v "$ADB" >/dev/null 2>&1 || { echo "❌ adb tidak ditemukan. Install platform-tools, atau set env ADB=/path/ke/adb.exe"; exit 1; }
command -v "$MITMDUMP" >/dev/null 2>&1 || { echo "❌ mitmdump tidak ditemukan. Install: pip install mitmproxy (atau set env MITMDUMP=/path/ke/mitmdump)"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "❌ openssl tidak ditemukan. Di Windows biasanya ikut Git for Windows."; exit 1; }

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
