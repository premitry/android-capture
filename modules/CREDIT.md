# Modul TrustMe (LSPosed) — kredit & asal-usul

File di folder ini: **`TrustMe-v1.2.0.apk`** — modul **LSPosed / Xposed** untuk **mematikan SSL
certificate pinning** di app Android. Disertakan di sini biar kamu nggak perlu build sendiri.

## Kredit

TrustMe **BUKAN** karya kami. Semua kredit ke pembuat aslinya:

- **Penulis asli:** **kirklin** — https://github.com/kirklin/TrustMe
- **Fork yang kami build:** **FighterTunnel/TrustMe** — https://github.com/FighterTunnel/TrustMe

APK di sini adalah hasil build dari source fork tersebut (build debug, ditandatangani debug-key).
Kode sumbernya tersedia penuh di link di atas.

## Catatan lisensi

Repo asal **tidak mencantumkan file LISENSI** eksplisit. APK ini disertakan **hanya untuk kemudahan
riset pribadi**, dengan kredit penuh ke pembuat aslinya. Kalau kamu mau 100% aman secara lisensi,
**hapus file APK ini** dan build/unduh langsung dari repo aslinya di atas.

## Cara pasang (singkat)

1. Pastikan HP sudah **root + Magisk + Zygisk + LSPosed** terpasang.
2. Install APK ini: `adb install modules/TrustMe-v1.2.0.apk`
3. Buka **LSPosed** → **Modules** → aktifkan **TrustMe** → **scope** ke app target.
4. **Reboot** HP.
5. Buka app target — SSL pinning-nya mati, traffic bisa disadap mitmproxy.
