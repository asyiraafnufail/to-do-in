# Roadmap & Panduan Implementasi Awal — TO-DO-IN-INDONESIA (`todoin.id`)

**Lingkungan Pengembangan:** macOS (Intel `amd64`), Flutter Multi-Platform, PocketBase, & VPS Contabo (Ubuntu/Linux `amd64`)

---

## 1. Struktur Folder Proyek (Monorepo)

Simpan seluruh bagian proyek dalam satu direktori induk (`todoin-project/`) agar manajemen dokumen, skema database, aplikasi klien, dan halaman web SEO tetap terpusat.

```bash
mkdir -p docs backend flutter_app web_seo
mv *.pdf *.md docs/
```

Susunan direktori akhir:
```text
todoin-project/
├── docs/               # Dokumen Blueprint (PDF), PRD (.md), Design (.md), & Roadmap (.md)
├── backend/            # Binary PocketBase lokal & ekspor skema database (pb_schema.json)
├── flutter_app/        # Aplikasi utama (Android, iOS, Windows, macOS, & Web App)
└── web_seo/            # Aplikasi SSR (Next.js) khusus halaman baca publik terindeks Google
```

---

## 2. Setup Backend Lokal di Mac Intel (`darwin_amd64`)

Gunakan PocketBase lokal terlebih dahulu untuk membangun dan menguji skema tabel tanpa membebani server produksi.

### Langkah Eksekusi:
1. Masuk ke folder `backend/` dan unduh *binary* PocketBase versi macOS Intel (`darwin_amd64`):
   ```bash
   cd backend
   curl -L https://github.com/pocketbase/pocketbase/releases/download/v0.25.9/pocketbase_0.25.9_darwin_amd64.zip -o pb.zip
   unzip pb.zip && rm pb.zip
   chmod +x pocketbase
   ```
2. Jalankan server PocketBase lokal:
   ```bash
   ./pocketbase serve
   ```
3. Buka `http://127.0.0.1:8090/_/` di browser untuk membuat akun Admin lokal dan menyusun 6 koleksi utama sesuai PRD:
   * `users` (Auth)
   * `posts`
   * `user_todos`
   * `listings`
   * `kyc_requests`
   * `social_actions`
4. **Catatan Git:** Pastikan folder `backend/pb_data/` dimasukkan ke dalam `.gitignore` agar data pengujian lokal tidak ikut terunggah ke repositori.

---

## 3. Inisialisasi Proyek & Arsitektur Folder Flutter

### Langkah Eksekusi:
1. Buka terminal baru di direktori induk (`todoin-project/`), periksa kesiapan perangkat dengan `flutter doctor`, lalu buat proyek Flutter:
   ```bash
   flutter create --org id.todoin flutter_app
   cd flutter_app
   ```
2. Pasang *package* inti sesuai kebutuhan fungsional PRD dan Design System:
   ```bash
   flutter pub add pocketbase go_router google_fonts geolocator geocoding flutter_image_compress image_picker url_launcher cached_network_image
   ```
3. Susun arsitektur folder modular di dalam `flutter_app/lib/`:
   ```text
   lib/
   ├── core/
   │   ├── constants/      # Konfigurasi base URL API (lokal vs api.todoin.id) & daftar kategori/provinsi
   │   ├── theme/          # Palet warna (Emerald Nusantara, Terracotta Sunset) & tipografi
   │   └── services/       # Singleton PocketBase client, GPS & Reverse Geocoding, Image Compressor
   ├── features/
   │   ├── auth/           # Login, Register, Google OAuth, & Onboarding username
   │   ├── feed/           # Beranda, FeedCard, Detail Postingan, & Form Buat/Edit Postingan + GPS
   │   ├── explore/        # Pencarian, filter provinsi/kategori, direktori tempat, & katalog sewa
   │   ├── todo/           # Halaman My To-Do (checklist aktivitas per kota)
   │   └── profile/        # Halaman Profil, Tab Feeds, Travel History, Saved, Tab Layanan, & Form KYC
   └── main.dart
   ```

---

## 4. Deployment Backend ke VPS Contabo (`api.todoin.id`)

Setelah seluruh koleksi dan aturan akses (*API Rules*) diuji di lokal, lakukan *deployment* ke VPS Contabo:

1. **Konfigurasi DNS:** Pada panel manajemen domain `todoin.id`, tambahkan **A Record** dengan nama `api` (`api.todoin.id`) yang mengarah ke alamat IP Publik VPS Contabo.
2. **Ekspor Skema Lokal:** Pada dashboard PocketBase lokal (`Settings -> Export collections`), unduh file konfigurasi `pb_schema.json`.
3. **Instalasi PocketBase di VPS (Linux `amd64`):**
   ```bash
   ssh root@IP_VPS_CONTABO
   mkdir -p /opt/pocketbase && cd /opt/pocketbase
   wget https://github.com/pocketbase/pocketbase/releases/download/v0.25.9/pocketbase_0.25.9_linux_amd64.zip
   unzip pocketbase_0.25.9_linux_amd64.zip && rm *.zip
   ```
4. **Konfigurasi SSL Otomatis dengan Caddy:** Pasang Caddy di VPS dan atur `/etc/caddy/Caddyfile`:
   ```caddyfile
   api.todoin.id {
       reverse_proxy 127.0.0.1:8090
   }
   ```
5. **Menjalankan Layanan & Backup:**
   * Daftarkan `./pocketbase serve --http="127.0.0.1:8090"` sebagai `systemd` service agar otomatis berjalan saat VPS *restart*.
   * Buka `https://api.todoin.id/_/`, buat akun Admin produksi, lalu impor file `pb_schema.json` melalui menu `Settings -> Import collections`.
   * Jadwalkan pencadangan rutin direktori `/opt/pocketbase/pb_data` (menggunakan Litestream atau *cronjob* backup harian).

---

## 5. Rencana Pengerjaan Bertahap (*Sprint Roadmap*)

### Sprint 1: Fondasi, Autentikasi, & Profil (Minggu 1)
* Penyusunan skema lengkap 6 koleksi PocketBase beserta *API Rules*.
* Implementasi tema aplikasi (`ThemeData`), navigasi responsif (`go_router`), serta halaman Login/Register.
* Implementasi halaman Profil, Edit Profil, pengaturan privasi kontak (WhatsApp & Instagram), dan fitur *Follow*.

### Sprint 2: Core Loop — Cerita Hibrida, Live GPS, & My To-Do (Minggu 2)
* Pembuatan halaman *Create Post* dengan kompresi gambar otomatis, pengambilan lokasi GPS (`geolocator` + *reverse geocoding*), dan input blok *To-Do List*.
* Implementasi Beranda (*Feed* dengan filter provinsi/kategori), fitur Edit Postingan, Like, Komentar, dan Bookmark.
* Otomatisasi tab *Travel History* pada profil berdasarkan kota GPS postingan pengguna.
* Implementasi halaman *My To-Do* untuk menyimpan dan mencentang aktivitas per kota tujuan.

### Sprint 3: Ekosistem Guide/Host & Web Publik SEO (Minggu 3)
* Pembuatan formulir pengajuan verifikasi KYC (unggah KTP, swafoto, & bukti aset ke penyimpanan privat).
* Implementasi tab *Layanan* di profil *Verified Host* (*Open Trip*, Sewa Kendaraan, Homestay/Kos) serta tombol reservasi langsung dengan *template* pesan WhatsApp.
* Pengembangan halaman baca publik berorientasi SEO (`web_seo/`) untuk rute `/p/[slug]` dan `/u/[username]`.