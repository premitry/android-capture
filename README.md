# android-capture

Tool ringkas buat **menyadap & mendekripsi traffic HTTPS aplikasi Android** (HP rooted) pakai
**mitmproxy** — dengan **2 mode**: capture **semua app** atau **filter 1 domain/app** (mis. cuma Flip).
Cocok buat reverse-engineering API aplikasi (endpoint, header, body).

> ⚠️ Untuk **perangkat & akun milikmu sendiri** / riset yang kamu berhak. Patuhi hukum & ToS aplikasi.

---

## Yang dibutuhkan

1. **HP Android di-root** + **USB debugging** aktif (colok ke PC).
2. **adb** (Android platform-tools).
3. **mitmproxy**: `pip install mitmproxy`.
4. **openssl** (biasanya sudah ada; di Windows ikut Git for Windows).
5. Untuk app dengan **SSL pinning / anti-tamper** (mis. bank/e-wallet seperti **Flip**):
   - **LSPosed** (via Magisk + Zygisk), + modul **TrustMe** (matikan SSL pinning) di-scope ke app target, lalu reboot.
   - Kenapa LSPosed, bukan Frida? App finance sering **deteksi Frida** dan langsung tertutup. LSPosed
     (level Zygote) lebih siluman.

---

## Cara pakai

```bash
# 1) capture SEMUA app
./run.sh

# 2) filter: cuma detail request ke domain tertentu (mis. Flip)
./run.sh flip.id

# 3) filter + auto-buka app-nya
./run.sh flip.id id.flip
```

Lalu **buka app di HP & lakukan aksinya** (mis. cek rekening / login). Hasil:

- **`capture.txt`** — DETAIL request + response (header + body) sesuai filter.
- **`all.txt`** — daftar ringkas **semua** request (host/path) — buat lihat endpoint apa aja yang jalan.

Lihat live:
```bash
tail -f all.txt        # semua endpoint yang lewat
tail -f capture.txt    # detail yang cocok filter
```

Selesai? **bersihkan** (matikan proxy HP, lepas CA, stop mitmproxy):
```bash
./stop.sh
```

### Beda "capture all" vs "filter"
- `all.txt` **selalu** mencatat SEMUA request (biar kamu tau app manggil domain apa aja).
- `capture.txt` cuma mencatat **detail** untuk request yang **cocok `FILTER`**. Kalau `FILTER=all`,
  semua di-detail (bisa besar). Kalau `FILTER=flip.id`, cuma flip.id yang di-detail → rapi & fokus.

---

## Konfigurasi (env, opsional)

| Env | Default | Fungsi |
|---|---|---|
| `ADB` | `adb` | path adb (mis. `/c/Users/kamu/platform-tools/adb.exe`) |
| `MITMDUMP` | `mitmdump` | path mitmdump (kalau tidak di PATH) |
| `PORT` | `8080` | port proxy |
| `CAP_MAXBODY` | `3000` | maksimal char body yang dicatat |

Contoh (Windows/Git-Bash, adb bukan di PATH):
```bash
ADB=/c/Users/kamu/adbtool/platform-tools/adb.exe MITMDUMP=/c/Users/kamu/AppData/.../Scripts/mitmdump.exe ./run.sh flip.id id.flip
```

---

## Cara kerja (yang di-otomatiskan `run.sh`)

1. Start `mitmdump` + addon [`capture.py`](capture.py) (baca env `CAP_FILTER`).
2. Bikin CA mitmproxy → pasang ke **system trust store** Android via **bind-mount**
   (`/system/etc/security/cacerts`, nama file = `openssl x509 -subject_hash_old`).
3. `adb reverse tcp:8080 tcp:8080` + `settings put global http_proxy localhost:8080`
   → semua traffic app lewat mitmproxy (via USB).
4. Addon tulis request/response ke file sesuai filter.

`stop.sh` mengembalikan semuanya (proxy off, umount CA, kill mitmproxy).

---

## Troubleshoot

- **App "koneksi tidak stabil" / gagal konek** → app pakai **cert pinning**. Pasang **TrustMe (LSPosed)**
  + scope ke app, reboot. (Kalau app deteksi Frida, jangan pakai Frida — pakai LSPosed.)
- **`adb` "device unauthorized"** → tap **Allow USB debugging** di HP.
- **`adb` nge-hang / "device offline"** → `taskkill /F /IM adb.exe` (Windows) lalu `adb devices` lagi
  (kadang perlu colok ulang USB).
- **openssl "No such file"** di Windows → pastikan pakai path yang benar; script sudah handle via `cygpath`.
- **HP "no internet" saat proxy nyala** → normal selama tunnel (adb reverse) + mitmproxy jalan; app tetap tembus.
- **Screenshot hitam** → app pasang `FLAG_SECURE`. Navigasi manual di HP (tidak bisa di-drive dari PC).

## Lisensi
MIT. Gunakan bertanggung jawab.
