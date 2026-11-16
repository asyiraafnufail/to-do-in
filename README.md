# TO-DO-IN INDONESIA (`todoin.id`)

Platform komunitas perjalanan Indonesia yang memadukan **cerita autentik berbasis Live GPS**, **perencana aktivitas pribadi (*My To-Do*)**, **direktori anti-*fake review***, serta **layanan lokal terverifikasi** (*open trip*, sewa kendaraan, dan penginapan).

---

## 🏛️ Arsitektur Proyek

Repository ini berbentuk monorepo terstruktur:
```
to-do-in/
├── flutter_app/         # Aplikasi mobile Flutter (Android & iOS)
├── backend/             # Skema & Migrasi PocketBase
│   ├── pb_migrations/   # Skrip migrasi database otomatis
│   └── pb_schema.json   # Backup skema PocketBase JSON
├── web_seo/             # Web SSR Next.js 14 (OpenGraph & Google SEO)
├── docs/                # PRD, Design System, & Spesifikasi Arsitektur
└── shared-assets/       # Logo resmi, font, dan aset visual
```

---

## 🚀 Panduan Kolaborasi (Onboarding Teman / Tim)

### 1. Prasyarat Sistem
- **Flutter SDK:** `>= 3.24.0` (Dart `>= 3.5.0`)
- **Node.js:** `>= 18.17.0` (untuk `web_seo`)
- **PocketBase:** `>= v0.23.0` (Download dari [pocketbase.io](https://pocketbase.io/docs/))

---

### 2. Setup Backend (PocketBase)

Teman satu tim dapat memilih salah satu opsi:

#### Opsi A — Terhubung ke VPS Tim (Paling Cepat):
Jalankan aplikasi dengan `--dart-define`:
```bash
flutter run --dart-define=PB_URL=https://pb-dev.todoin.id
```
Atau atur langsung URL backend default di `flutter_app/lib/core/constants/app_constants.dart`.

#### Opsi B — Menjalankan PocketBase Lokal:
1. Letakkan binari `pocketbase` di folder `backend/`.
2. Jalankan server:
   ```bash
   cd backend
   ./pocketbase serve
   ```
   *(Skrip migrasi di `backend/pb_migrations/` otomatis menyusun skema database & relasi).*
3. Buat superuser lokal:
   ```bash
   ./pocketbase superuser create admin@todoin.id admin123456
   ```
4. Isi data testing (Admin, Guide, Traveler) secara otomatis:
   ```bash
   cd ../flutter_app
   dart run bin/seed_test_accounts.dart http://127.0.0.1:8090
   ```

---

### 3. Menjalankan Aplikasi Mobile (Flutter)

```bash
cd flutter_app
flutter pub get
flutter run
```

---

### 4. Menjalankan Web SEO (Next.js)

```bash
cd web_seo
npm install
npm run dev
```
Buka browser di `http://localhost:3000`.

---

## 👥 Aturan Kolaborasi Git (Git Workflow)

1. **Aturan Branching:**
   - `main` adalah branch produksi (stabil). Jangan commit langsung ke `main`.
   - Buat branch baru untuk setiap pekerjaan:
     - Fitur baru: `feat/nama-fitur` (contoh: `feat/search-filter`)
     - Perbaikan bug: `fix/nama-bug` (contoh: `fix/overflow-button`)
2. **Pull Request (PR):**
   - Sebelum merge ke `main`, buat Pull Request di GitHub.
   - Diskusikan kode dan pastikan `flutter test` lolos tanpa error.
3. **Keamanan File Sensitif:**
   - `.gitignore` sudah mengunci file sensitif (`.env*`, `pb_data`, file signing `.keystore`, dan `progress.md`).
   - Jangan pernah melakukan `git add -f` pada file yang di-ignore.
