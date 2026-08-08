# android-capture

Tool ringkas buat **menyadap & mendekripsi traffic HTTPS aplikasi Android** (HP rooted) pakai
**mitmproxy** — dengan **2 mode**: capture **semua app** atau **filter 1 domain/app** saja.
Cocok buat reverse-engineering API aplikasi (endpoint, header, body) — mis. app **bank / e-wallet**.

> ⚠️ Untuk **perangkat & akun milikmu sendiri** / riset yang kamu berhak. Patuhi hukum & ToS aplikasi.

---

## Cara pakai (ringkas)

1. **Download tool ini** — `git clone` **atau** tombol hijau *Code → Download ZIP* lalu **extract**.
2. **Buka terminal DI DALAM folder hasil extract**:
   - **Windows** → klik kanan folder → **"Git Bash Here"** (atau *Open in Terminal* → pilih **Git Bash**).
     Ini skrip **bash**, jadi **bukan** `cmd.exe` / PowerShell.
   - **Linux / macOS** → buka Terminal, `cd` ke folder itu.
3. Jalankan salah satu:

```bash
./run.sh                          # 1) capture SEMUA app
./run.sh nama-domain.com          # 2) filter: cuma detail request ke domain itu
./run.sh nama-domain.com com.nama.app   # 3) filter + auto-buka app-nya
```

4. **Buka app di HP & lakukan aksinya** (mis. login / cek rekening).
5. **Hasilnya otomatis tersimpan di folder yang sama** (folder tool ini):
   - **`capture.txt`** — DETAIL request + response (header + body) sesuai filter.
   - **`all.txt`** — daftar ringkas **semua** request (host/path), buat lihat app manggil domain apa aja.
6. Selesai? bersihkan (matikan proxy HP, lepas CA, stop mitmproxy):

```bash
./stop.sh
```

> 📁 **Semua file hasil ada di folder tool ini** — nggak nyebar ke tempat lain, jadi gampang dicari & dihapus.

Lihat live sambil jalan:
```bash
tail -f all.txt        # semua endpoint yang lewat
tail -f capture.txt    # detail yang cocok filter
```

### Beda "capture all" vs "filter"
- `all.txt` **selalu** mencatat SEMUA request (biar kamu tau app manggil domain apa aja).
- `capture.txt` cuma mencatat **detail** untuk request yang **cocok `FILTER`**. Kalau `FILTER=all`,
  semua di-detail (bisa besar). Kalau `FILTER=nama-domain.com`, cuma domain itu yang di-detail → rapi & fokus.

---

## Yang dibutuhkan (sekali pasang)

1. **HP Android di-root** + **USB debugging** aktif (colok ke PC).
2. **adb** (Android platform-tools) — [download](https://developer.android.com/tools/releases/platform-tools).
3. **mitmproxy** → `pip install mitmproxy`.
4. **openssl** (biasanya sudah ada; di Windows ikut Git for Windows).
5. Untuk app dengan **SSL pinning / anti-tamper** (umum di app **bank / e-wallet**):
   - **LSPosed** (via Magisk + Zygisk) + modul **TrustMe** (matikan SSL pinning), di-scope ke app target, lalu **reboot**.
   - **APK TrustMe sudah disertakan** di [`modules/TrustMe-v1.2.0.apk`](modules/) — tinggal
     `adb install modules/TrustMe-v1.2.0.apk`, aktifkan di LSPosed, scope ke app-mu.
     Kredit penuh ke pembuat aslinya (**kirklin/TrustMe**, fork **FighterTunnel/TrustMe**) —
     lihat [`modules/CREDIT.md`](modules/CREDIT.md).
   - Kenapa LSPosed, bukan Frida? App finance sering **deteksi Frida** dan langsung tertutup. LSPosed
     (level Zygote) lebih siluman.

Kalau ada dependency yang belum terpasang, `run.sh` bakal kasih tau + petunjuk install-nya.

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
ADB=/c/Users/kamu/platform-tools/adb.exe ./run.sh nama-domain.com com.nama.app
```

---

## Cara kerja (yang di-otomatiskan `run.sh`)

1. Start `mitmdump` + addon [`capture.py`](capture.py) (baca env `CAP_FILTER`).
2. Bikin CA mitmproxy → pasang ke **system trust store** Android via **bind-mount**
   (`/system/etc/security/cacerts`, nama file = `openssl x509 -subject_hash_old`).
3. `adb reverse tcp:8080 tcp:8080` + `settings put global http_proxy localhost:8080`
   → semua traffic app lewat mitmproxy (via USB).
4. Addon tulis request/response ke file di folder tool sesuai filter.

`stop.sh` mengembalikan semuanya (proxy off, umount CA, kill mitmproxy).

---

## Troubleshoot

- **App "koneksi tidak stabil" / gagal konek** → app pakai **cert pinning**. Pasang
  **TrustMe (LSPosed)** dari [`modules/TrustMe-v1.2.0.apk`](modules/) — scope ke app, reboot.
  (Kalau app deteksi Frida, jangan pakai Frida — pakai LSPosed.)
- **`adb` "device unauthorized"** → tap **Allow USB debugging** di HP.
- **`adb` nge-hang / "device offline"** → `taskkill //F //IM adb.exe` (Windows) lalu `adb devices` lagi
  (kadang perlu colok ulang USB).
- **openssl "No such file"** di Windows → pastikan pakai path yang benar; script sudah handle via `cygpath`.
- **HP "no internet" saat proxy nyala** → normal selama tunnel (adb reverse) + mitmproxy jalan; app tetap tembus.
- **Screenshot hitam** → app pasang `FLAG_SECURE`. Navigasi manual di HP (tidak bisa di-drive dari PC).

## Lisensi
MIT. Gunakan bertanggung jawab.
