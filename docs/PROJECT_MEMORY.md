# 🧠 Project Memory & Context: TO-DO-IN Indonesia (todoin.id)
**Terakhir Diperbarui:** 17 November 2026  
**Status Proyek:** Siap Produksi & Terhubung ke VPS Contabo

---

## 1. Arsitektur & Infrastruktur Server (VPS Contabo)

* **Base URL Backend (PocketBase):** `https://pb-dev.todoin.id`
* **Health Check Endpoint:** `https://pb-dev.todoin.id/api/health` (HTTP 200)
* **Dashboard Admin:** `https://pb-dev.todoin.id/_/`
* **Keamanan Jaringan:** Cloudflare Tunnel / Caddy Reverse Proxy dengan SSL Let's Encrypt (Auto-Renew).
* **6 Koleksi Database Aktif:**
  1. `users` (auth, profile, contact privacy WhatsApp & Instagram, verified host badge)
  2. `posts` (cerita perjalanan, foto kompresi, to-do rekomendasi, Live GPS)
  3. `listings` (rental kendaraan, open trip, homestay oleh verified host)
  4. `user_todos` (rencana perjalanan & catatan pribadi offline-first)
  5. `social_actions` (likes, komentar, bookmark)
  6. `kyc_requests` (dokumen pengajuan host terverifikasi)

---

## 2. Aplikasi Mobile (`flutter_app`)

### A. Fitur & UI/UX
* **Modern Floating Navpill:**
  * File: `lib/core/navigation/main_scaffold.dart`
  * Desain: Floating pill capsule (`borderRadius: 32`), frosted glass (`BackdropFilter` blur 16), elevated dual-shadow.
  * Adaptive Dark/Light Mode.
  * Tombol Aksi Tengah: Circular Action Button (+) berdiameter 44px dengan gradien emerald (`Color(0xFF0F766E)` ke `Color(0xFF14B8A6)`), bebas risiko *RenderFlex overflow*.
* **Kompresi Gambar Otomatis:**
  * File: `lib/features/feed/create_post_screen.dart`
  * Format WebP/JPEG < 450 KB (kualitas 75, max width 1280px) sebelum dikirim ke VPS untuk efisiensi penyimpanan SSD.
* **Live GPS & Geocoding:**
  * Validasi koordinat GPS langsung di lokasi dan reverse geocoding kota/provinsi otomatis.
* **My To-Do & Offline Support:**
  * File: `lib/features/todo/todo_screen.dart`
  * Caching lokal menggunakan `SharedPreferences` saat offline, serta dialog catatan pribadi.
* **Edit Layanan Host & RBAC Guest Guard:**
  * File: `lib/features/marketplace/create_listing_screen.dart` & `lib/features/profile/user_profile_screen.dart`.
* **Deep Linking:**
  * Skema terdaftar: `todoin://` di AndroidManifest dan iOS Info.plist.

### B. Konfigurasi Endpoint Backend
* File: `lib/core/constants/app_constants.dart`
* Default URL: `https://pb-dev.todoin.id`
* Flag override saat build: `--dart-define=PB_URL=...`

---

## 3. CI/CD & Build Pipeline (GitHub Actions)

### Workflow iOS IPA:
* File: `.github/workflows/build_app.yml`
* **Runner:** `macos-latest` (runner `macos-13` dan `macos-14` sudah dipensiunkan oleh GitHub).
* **Versi Flutter:** Dikunci ke `flutter-version: '3.24.5'` untuk menjaga kompatibilitas dengan dependensi `pubspec.lock` dan menghindari breaking changes pada Flutter 3.50+ (`CardThemeData`, `google_fonts`).
* **Bypass Code Signing untuk Sideloading:**
  * Di `ios/Runner.xcodeproj/project.pbxproj`: Diberi `DEVELOPMENT_TEAM = TOD01NID01;` untuk meloloskan pra-pemeriksaan Flutter CLI.
  * Di `ios/Flutter/Release.xcconfig` & `ios/Podfile`: Diberi `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGNING_REQUIRED = NO`, dan `CODE_SIGN_STYLE = Manual`.
* **Pengemasan IPA:**
  * Menggunakan `zip -r -y -q todoin-release.ipa Payload` (flag `-y` wajib untuk menjaga integritas symlink framework iOS).
  * Output: Artifact `todoin-ios-ipa` dapat langsung diunduh dari halaman GitHub Actions dan di-sideload via Sideloadly / AltStore.

### Konfigurasi Android:
* `android/settings.gradle`: Android Gradle Plugin `8.5.2`, Kotlin `2.1.0`.
* `android/gradle/wrapper/gradle-wrapper.properties`: Gradle `8.9-all`.
* `android/app/build.gradle`: Kompatibel Java 17 (`JavaVersion.VERSION_17`, `jvmTarget = '17'`).

---

## 4. Web SEO & SSR (`web_seo`)

* Framework: Next.js 14 SSR.
* File Environment: `web_seo/.env.local` terhubung ke `https://pb-dev.todoin.id`.
* Konfigurasi Image Optimization: `pb-dev.todoin.id` telah didaftarkan pada `remotePatterns` di `web_seo/next.config.js`.
* Halaman Publik: `/p/[slug]` (cerita), `/u/[username]` (profil), `/listing/[id]` (sewa/trip), dan `sitemap.xml`.

---

## 5. Ringkasan Perintah Penting

```bash
# 1. Menjalankan Flutter lokal (otomatis mengarah ke VPS)
cd flutter_app && flutter run

# 2. Build APK Android Release lokal
cd flutter_app && flutter build apk --release

# 3. Test & Analisis Kode Flutter
cd flutter_app && flutter test && flutter analyze

# 4. Trigger Build iOS IPA di Cloud
# Buka tab Actions di GitHub: https://github.com/asyiraafnufail/to-do-in/actions -> Run workflow
```
