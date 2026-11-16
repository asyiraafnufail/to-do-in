# TO-DO-IN Indonesia (`todoin.id`) — Agent Workspace Context & Memory

Dokumen ini adalah **memori lokal permanen** untuk agent (Antigravity / Gemini CLI) dan pengembang dalam mengelola, mengembangkan, dan mem-build proyek TO-DO-IN Indonesia.

---

## 1. Arsitektur Proyek & Lingkungan

* **Monorepo:**
  * `flutter_app/`: Aplikasi multi-platform (Android, iOS, Web, macOS, Desktop). Dibuat dengan Flutter `3.24.5` (Dart `3.5.4`).
  * `web_seo/`: Frontend publik Next.js 14 (SSR & SEO) untuk perutean rute `/p/[slug]`, `/u/[username]`, dan `/listing/[id]`.
  * `backend/`: Skema migrasi PocketBase v0.25+, file service systemd, dan Caddyfile.
  * `docs/`: PRD, Design System, Roadmap, dan dokumentasi arsitektur.
* **Server Produksi & Database (VPS Contabo):**
  * **Base URL:** `https://pb-dev.todoin.id`
  * **Health Endpoint:** `https://pb-dev.todoin.id/api/health` (HTTP 200)
  * **Admin UI:** `https://pb-dev.todoin.id/_/`
  * **6 Koleksi Aktif:** `users`, `posts`, `listings`, `user_todos`, `social_actions`, `kyc_requests`.

---

## 2. Standar Desain & Fitur Mobile (`flutter_app`)

* **Floating Modern Navpill (`lib/core/navigation/main_scaffold.dart`):**
  * Desain kapsul mengambang (*floating pill capsule*, `borderRadius: 32`) dengan efek *frosted glass* (`BackdropFilter` blur 16) dan drop shadow berlapis.
  * Tombol aksi tengah: Lingkaran gradien emerald **(+)** berdiameter 44px dengan `Icons.add_rounded` (24px) berpusat vertikal. **Jangan tambahkan teks di bawah tombol tengah** untuk mencegah *RenderFlex bottom overflow*.
  * Responsive Dark Mode (`#1E293B`) & Light Mode (Putih translusen `#FFFFFF`).
* **Endpoint PocketBase (`lib/core/constants/app_constants.dart`):**
  * Default URL langsung mengarah ke VPS: `https://pb-dev.todoin.id`.
  * Dapat di-override saat build/run menggunakan `--dart-define=PB_URL=...`.
* **Optimasi Gambar & Geocoding (`lib/features/feed/create_post_screen.dart`):**
  * Kompresi otomatis via `flutter_image_compress` (< 450 KB, quality 75, max width 1280px) sebelum dikirim ke VPS.
  * Validasi Live GPS dengan koordinat perangkat dan reverse geocoding nama tempat/kota/provinsi otomatis.
* **Offline Fallback (`lib/features/todo/todo_screen.dart`):**
  * Menggunakan `SharedPreferences` untuk menyimpan cache to-do saat tidak ada koneksi internet.
* **Deep Linking:**
  * Skema terdaftar: `todoin://` (Android & iOS).

---

## 3. Aturan Build & CI/CD Pipeline (PENTING)

### A. GitHub Actions Cloud Build iOS IPA (`.github/workflows/build_app.yml`)
* **Runner OS:** Gunakan **`runs-on: macos-latest`**.
  * *CATATAN PENTING:* Jangan gunakan `macos-13` atau `macos-14` karena sudah dipensiunkan (*deprecated/retired*) oleh GitHub dan akan memicu queue timeout / cancellation.
* **Versi Flutter:** **WAJIB dikunci ke `flutter-version: '3.24.5'`**.
  * *CATATAN PENTING:* Jangan gunakan `channel: 'stable'` tanpa versi, karena di masa depan akan menarik Flutter versi baru (seperti 3.50+) yang memiliki breaking change pada `CardThemeData`, `TabBarThemeData`, dan `google_fonts: 6.3.0`.
* **Bypass Code Signing untuk Sideloading (AltStore / Sideloadly):**
  * `ios/Runner.xcodeproj/project.pbxproj`: Harus memiliki placeholder `DEVELOPMENT_TEAM = TOD01NID01;` agar lolos dari validasi pra-pemeriksaan Flutter CLI.
  * `ios/Flutter/Release.xcconfig` & `ios/Podfile`: Menggunakan `CODE_SIGNING_ALLOWED = NO`, `CODE_SIGNING_REQUIRED = NO`, `CODE_SIGN_IDENTITY = ''`, dan `CODE_SIGN_STYLE = Manual`.
* **Pengemasan IPA:**
  * Gunakan flag `-y` saat zip: `zip -r -y -q todoin-release.ipa Payload` untuk menjaga integritas symlink framework Flutter.
  * Output artifact: `todoin-ios-ipa`.

### B. Konfigurasi Android (`flutter_app/android/`)
* **Android Gradle Plugin (AGP):** `8.5.2` (di `settings.gradle`)
* **Kotlin Android Plugin:** `2.1.0` (di `settings.gradle`)
* **Gradle Wrapper:** `gradle-8.9-all.zip` (di `gradle-wrapper.properties`)
* **Java Compatibility:** `JavaVersion.VERSION_17` (di `app/build.gradle`)

---

## 4. Cheat Sheet Perintah Terminal

```bash
# Menjalankan aplikasi mobile (otomatis mengarah ke VPS Contabo)
cd flutter_app && flutter run

# Menjalankan rangkaian test dan analyzer
cd flutter_app && flutter test && flutter analyze

# Build APK Android Release lokal
cd flutter_app && flutter build apk --release

# Menjalankan Web SEO lokal
cd web_seo && npm run dev
```
