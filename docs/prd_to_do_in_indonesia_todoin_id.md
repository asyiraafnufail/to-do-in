# Product Requirements Document (PRD) — TO-DO-IN-INDONESIA (`todoin.id`)

**Versi:** 1.0 (MVP & Ekosistem Guide/Host)  
**Domain:** `todoin.id`  
**Infrastruktur:** VPS Contabo, PocketBase, Flutter Multi-Platform, & Web SEO (SSR)  

---

## 1. Ringkasan Produk & Target MVP

### Tujuan Produk
Membangun platform komunitas perjalanan Indonesia yang memadukan **cerita autentik berbasis lokasi GPS**, **perencana aktivitas (*My To-Do*)**, **direktori tempat anti-*fake review***, serta **layanan lokal terverifikasi** (*open trip*, sewa kendaraan, dan *homestay*/kos).

### Metrik Keberhasilan Tahap Awal (North Star & KPI MVP)
* **Kualitas Konten:** Minimal 70% postingan baru memiliki tag *Live GPS* yang tervalidasi.
* **Retensi Utilitas:** Rata-rata pengguna aktif menyimpan minimal 3 item aktivitas ke dalam daftar *My To-Do* per bulan.
* **Konversi Layanan Lokal:** Klik tombol reservasi WhatsApp pada tab *Layanan* (Guide/Host) tanpa keluhan penipuan/akun fiktif.
* **Performa SEO:** Halaman utas publik (`/p/[slug]`) dan profil (`/u/[username]`) terindeks oleh Google dalam waktu < 7 hari setelah publikasi.

---

## 2. Matriks Hak Akses (Role-Based Access Control)

| Fitur / Aksi | Guest (Tanpa Login) | Member (Reguler) | Verified Guide / Host | Admin |
| :--- | :---: | :---: | :---: | :---: |
| Baca utas cerita, profil, & daftar layanan | Ya | Ya | Ya | Ya |
| Lihat kontak WA/IG di profil (jika publik) | Tidak (Blur/Login) | Ya | Ya | Ya |
| Buat, edit, & hapus postingan cerita/utas | Tidak | Ya (Milik sendiri) | Ya (Milik sendiri) | Ya (Moderasi) |
| Like, komentar, bookmark, & follow | Tidak | Ya | Ya | Ya |
| Simpan aktivitas ke *My To-Do* | Tidak | Ya | Ya | Ya |
| Ajukan verifikasi KYC (KTP/STNK/Properti) | Tidak | Ya | Sudah Terverifikasi | Ya (Approve) |
| Buat & kelola listing Sewa / Open Trip | Tidak | Tidak | Ya | Ya (Moderasi) |

---

## 3. Spesifikasi Fungsional & *Acceptance Criteria*

### Epic 1: Autentikasi, Profil & Travel History
* **FR-1.1 Registrasi & Login:** Pengguna dapat mendaftar menggunakan Email/Password atau Google OAuth (bawaan PocketBase).
  * *Acceptance Criteria:* Sistem memvalidasi format *username* unik (huruf kecil, angka, titik/underscore, 3–20 karakter) saat onboarding pertama kali.
* **FR-1.2 Manajemen Profil & Privasi Kontak:** Pengguna dapat mengatur foto profil, nama tampilan, bio (maks. 160 karakter), nomor WhatsApp, username Instagram, serta sakelar privasi kontak (`Public`, `Followers Only`, `Hidden`).
  * *Acceptance Criteria:* Tombol WA pada profil otomatis tersembunyi jika status `Hidden`, atau hanya muncul bagi pengikut jika status `Followers Only`.
* **FR-1.3 Tab Travel History Otomatis:** Sistem menampilkan daftar kota dan provinsi yang pernah dikunjungi pengguna berdasarkan data GPS dari postingan mereka.
  * *Acceptance Criteria:* Ketika pengguna memublikasikan postingan pertama dari "Kabupaten Sleman, DI Yogyakarta", nama wilayah tersebut otomatis muncul di tab *Travel History* tanpa input manual.

### Epic 2: Pembuatan Postingan Hibrida & Auto-GPS
* **FR-2.1 Editor Blog/Utas & To-Do:** Pengguna menulis judul, isi cerita panjang, mengunggah maksimal 5 foto (otomatis dikompresi ke format WebP/JPEG < 500 KB di perangkat sebelum dikirim ke VPS), dan menambahkan daftar poin *To-Do* (opsional).
  * *Acceptance Criteria:* Postingan tetap dapat dipublikasikan meskipun blok daftar *To-Do* dikosongkan.
* **FR-2.2 Pengambilan Lokasi GPS Otomatis:** Saat menekan tombol *Publikasikan*, aplikasi mengambil koordinat perangkat melalui `geolocator` dan mengubahnya menjadi nama Kecamatan/Kota & Provinsi via *reverse geocoding*.
  * *Acceptance Criteria:* Jika izin GPS ditolak, pengguna tetap bisa memublikasikan cerita dengan memilih kota secara manual, namun label *"Live GPS"* tidak akan ditampilkan.
* **FR-2.3 Edit Postingan:** Penulis dapat menyunting teks, judul, kategori, dan daftar *To-Do* pada postingan yang sudah tayang.
  * *Acceptance Criteria:* Setelah disimpan, muncul keterangan kecil *"Diedit"* di samping waktu tayang postingan.

### Epic 3: Beranda, Explore & Direktori Tempat
* **FR-3.1 Feed & Filter Pencarian:** Menampilkan tab *Terbaru* dan *Mengikuti*, kolom pencarian kata kunci, serta filter berdasarkan **Provinsi** dan **Kategori** (*Kuliner, Alam, Budaya, Hidden Gem, Penginapan*).
  * *Acceptance Criteria:* Hasil filter dimuat dalam waktu < 1,5 detik menggunakan pagination PocketBase (`page=1&perPage=15`).
* **FR-3.2 Halaman Detail Postingan & Simpan To-Do:** Menampilkan isi cerita, galeri foto, label wilayah GPS, serta daftar *To-Do* dari penulis yang masing-masing memiliki tombol **"+ To-Do"**.
  * *Acceptance Criteria:* Menekan tombol "+ To-Do" langsung menyalin item aktivitas tersebut ke koleksi `user_todos` milik pengguna dengan notifikasi *snackbar* konfirmasi.

### Epic 4: Perencana Perjalanan (*My To-Do*)
* **FR-4.1 Manajemen Checklist Perjalanan:** Pengguna melihat seluruh aktivitas yang disimpan, dikelompokkan otomatis berdasarkan **Kota/Kabupaten**. Pengguna juga dapat menambah item *to-do* secara manual.
  * *Acceptance Criteria:* Pengguna dapat mencentang status selesai (*completed*), menambahkan catatan pribadi (misal: *"Bawa uang tunai"*), atau menghapus item.

### Epic 5: Layanan Guide & Host (Open Trip, Sewa Kendaraan, Homestay/Kos)
* **FR-5.1 Pengajuan Verifikasi (KYC):** Member mengunggah foto KTP, swafoto, dan dokumen pendukung aset (STNK kendaraan / foto lokasi properti) ke penyimpanan privat.
  * *Acceptance Criteria:* Dokumen KYC tidak dapat diakses melalui URL publik dan hanya dapat dilihat oleh Admin di dashboard PocketBase.
* **FR-5.2 Manajemen Listing Layanan:** Akun *Verified Guide/Host* mendapatkan tab **Layanan** di profilnya untuk menambah listing dengan tipe `open_trip`, `vehicle`, atau `stay`, lengkap dengan sakelar status **Tersedia / Penuh**.
  * *Acceptance Criteria:* Spesifikasi dinamis tersimpan rapi sesuai kategori (misal: transmisi & lepas kunci untuk kendaraan; fasilitas AC/Wi-Fi & harga harian/bulanan untuk kos/homestay).
* **FR-5.3 Reservasi Cepat via WhatsApp:** Setiap halaman detail layanan memiliki tombol **"Tanya / Booking via WhatsApp"**.
  * *Acceptance Criteria:* Menekan tombol membuka aplikasi WhatsApp dengan pesan otomatis berisi nama layanan, harga, dan tautan halaman listing di `todoin.id`.

---

## 4. Skema Database & Aturan Keamanan (PocketBase)

Berikut rancangan 6 koleksi utama yang perlu dibuat di panel Admin PocketBase (`https://api.todoin.id/_/`):

| Nama Koleksi | Tipe | Field Utama & Tipe Data | Aturan API (Security Rules) |
| :--- | :--- | :--- | :--- |
| **`users`** | Auth | `name` (text), `username` (text, unique), `avatar` (file), `bio` (text), `whatsapp` (text), `instagram` (text), `contact_privacy` (select: `public`, `followers`, `hidden`), `is_verified_host` (bool) | **View/List:** Public<br>**Update:** `@request.auth.id = id` (kecuali `is_verified_host` hanya Admin) |
| **`posts`** | Base | `author` (relation: `users`), `title` (text), `slug` (text, unique), `content` (editor/text), `images` (file, max 5), `category` (select), `place_name` (text), `city` (text), `province` (text), `is_live_gps` (bool), `lat_approx` (number), `lng_approx` (number), `todo_items` (json), `is_edited` (bool) | **View/List:** Public<br>**Create:** `@request.auth.id != ""`<br>**Update/Delete:** `@request.auth.id = author.id` |
| **`user_todos`** | Base | `user` (relation: `users`), `source_post` (relation: `posts`, optional), `city` (text), `task_title` (text), `notes` (text), `is_completed` (bool) | **All Rules:** `@request.auth.id = user.id` (Privat penuh milik user) |
| **`listings`** | Base | `owner` (relation: `users`), `type` (select: `open_trip`, `vehicle`, `stay`), `title` (text), `description` (text), `price` (number), `price_unit` (select: `pax`, `day`, `night`, `month`), `city` (text), `province` (text), `images` (file, max 6), `specs` (json), `is_available` (bool) | **View/List:** Public<br>**Create:** `@request.auth.is_verified_host = true`<br>**Update/Delete:** `@request.auth.id = owner.id` |
| **`kyc_requests`** | Base | `user` (relation: `users`), `id_card` (file, **Protected**), `selfie` (file, **Protected**), `asset_proof` (file, **Protected**), `status` (select: `pending`, `approved`, `rejected`), `admin_note` (text) | **Create:** `@request.auth.id != ""`<br>**View:** `@request.auth.id = user.id`<br>**List/Update:** Admin Only |
| **`social_actions`** | Base | `user` (relation: `users`), `target_post` (relation: `posts`, optional), `target_user` (relation: `users`, optional), `action_type` (select: `like`, `bookmark`, `follow`), `comment_body` (text, optional) | **View/List:** Public<br>**Create:** `@request.auth.id != ""`<br>**Delete:** `@request.auth.id = user.id` |

---

## 5. Persyaratan Non-Fungsional (NFR) & Infrastruktur

1. **Privasi Lokasi GPS:** Aplikasi Flutter membulatkan koordinat menjadi **3 angka di belakang koma** (akurasi ~110 meter) sebelum dikirim ke API `posts` untuk mencegah pelacakan alamat rumah pribadi pengguna.
2. **Optimasi Penyimpanan VPS Contabo:** Seluruh unggahan gambar diproses menggunakan package `flutter_image_compress` (lebar maksimal 1280px, kualitas 75%) di sisi klien agar hemat ruang disk SSD VPS dan cepat dimuat di jaringan seluler.
3. **Arsitektur Web SEO (`todoin.id`):**
   * `todoin.id/p/[slug]` dan `todoin.id/u/[username]` dirender secara *Server-Side* (SSR) lengkap dengan meta tag OpenGraph (`og:title`, `og:image`, `og:description`) agar tampilan pratinjau tautan rapi saat dibagikan ke WhatsApp dan terindeks Google.
   * `app.todoin.id` (atau rute `/app`) menjalankan aplikasi interaktif Flutter Web penuh untuk pengguna yang login.
4. **Backup Otomatis:** Konfigurasi *cronjob* atau **Litestream** di VPS Contabo untuk mencadangkan direktori `pb_data` (database SQLite dan media) setiap hari ke penyimpanan eksternal.