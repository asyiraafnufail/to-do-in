# Dokumen Rancangan Awal (Project Blueprint) — TO-DO-IN-INDONESIA (`todoin.id`)

**Subtitle:** Ekosistem Cerita Perjalanan, Perencana Aktivitas (To-Do), Direktori Terverifikasi GPS, dan Layanan Lokal  
**Domain:** `todoin.id`  
**Infrastruktur:** VPS Contabo & PocketBase  
**Klien:** Flutter Multi-Platform  

---

## 1. Visi & Konsep Inti Platform

**TO-DO-IN-INDONESIA (`todoin.id`)** dirancang sebagai platform perjalanan dan gaya hidup lokal *end-to-end* yang menjembatani inspirasi cerita dengan eksekusi perjalanan nyata. Platform ini menggabungkan empat pilar utama dalam satu alur terintegrasi:

* **Jejaring Sosial Cerita (Blog & Utas):** Ruang bagi pelancong dan warga lokal untuk membagikan pengalaman mendalam berbentuk tulisan panjang dan dokumentasi foto.
* **Perencana Aktivitas (My To-Do):** Daftar rencana aktivitas praktis yang dapat disalin langsung dari cerita pengguna lain dan dikelola per kota tujuan.
* **Direktori Tempat Terverifikasi GPS:** Mengadopsi volume ulasan lokal ala *Google Reviews* yang dipadukan dengan standar kurasi bergengsi ala *Michelin Guide*, didukung validasi lokasi GPS saat penulisan untuk mencegah ulasan palsu.
* **Marketplace Layanan Lokal Kreator:** Ekosistem bagi *Local Guide* terverifikasi untuk menawarkan paket *Open Trip*, penyewaan kendaraan, serta akomodasi *homestay* atau kos.

---

## 2. Arsitektur Teknis & Tech Stack

Pemilihan teknologi difokuskan pada efisiensi operasional di server pribadi, kecepatan pengembangan lintas perangkat, serta keterbacaan optimal di mesin pencari.

| Komponen | Teknologi Pilihan | Peran & Catatan Implementasi |
| :--- | :--- | :--- |
| **Domain & Jaringan** | `todoin.id` & `api.todoin.id` | Menggunakan *reverse proxy* (Caddy atau Nginx) untuk manajemen sertifikat SSL otomatis dan perutean trafik API. |
| **Hosting & Server** | VPS Pribadi (Contabo) | Menjalankan layanan backend utama dengan jadwal *auto-backup* database harian (menggunakan Litestream ke penyimpanan objek eksternal). |
| **Backend & Database** | PocketBase (Go + SQLite) | Menangani autentikasi pengguna (Email & OAuth), database relasional ringan, REST/Realtime API, serta penyimpanan media. |
| **Aplikasi Klien** | Flutter (Multi-Platform) | Satu basis kode untuk aplikasi mobile (Android, iOS), desktop (Windows, macOS), dan aplikasi web interaktif. |
| **Web Publik & SEO** | SSR / Dynamic Rendering | Halaman baca publik (utas cerita, profil kreator, halaman destinasi) disajikan dalam HTML semantik agar terindeks sempurna oleh Google. |
| **Layanan Lokasi GPS** | Geolocator + Nominatim OSM | Pengambilan koordinat saat publikasi dan *reverse geocoding* gratis ke tingkat kecamatan/kota tanpa membebani kuota API peta berbayar di tahap awal. |

> **Prinsip Keamanan & Privasi Lokasi:** Sistem mengambil titik koordinat GPS mentah saat pengguna menekan tombol publikasi untuk memvalidasi kehadiran fisik, namun hanya menampilkan label wilayah (*"Ditulis dari [Kecamatan/Kota]"*) secara publik guna mencegah pelacakan posisi rumah pengguna.

---

## 3. Pembagian Role Pengguna

* **Guest (Pengunjung Tanpa Login - MVP):** Dapat membaca utas cerita publik, melihat profil kreator, mencari destinasi, serta membuka halaman penawaran layanan (penting untuk konversi trafik organik SEO).
* **Member / Traveler (Pengguna Terdaftar - MVP):** Dapat menulis postingan hibrida, memberikan *like*, komentar, *bookmark*, mengikuti akun lain, serta mengelola daftar *My To-Do* pribadi.
* **Verified Local Guide & Host (Tahap Ekspansi):** Kreator dengan identitas terverifikasi (KYC) dan rekam jejak GPS aktif yang mendapatkan tab khusus *Layanan* untuk membuka *Open Trip*, menyewakan kendaraan, atau menyewakan *homestay*/kos.
* **Business / Place Owner (Tahap Ekspansi):** Pemilik tempat wisata, kafe, atau UMKM lokal yang mengklaim halaman bisnis untuk memperbarui informasi operasional dan memasang promosi.
* **Admin & Moderator:** Mengelola verifikasi KYC, memoderasi laporan konten, serta menetapkan lencana kurasi tempat.

---

## 4. Spesifikasi Fitur Utama (Fokus Tahap MVP)

### 4.1 Halaman Profil Pengguna
* **Identitas & Privasi Kontak:** Menampilkan nama, foto profil, bio, username unik, jumlah *followers* dan *following*, tombol *Edit Profile*, serta *Share Profile*. Tombol kontak WhatsApp dan Instagram dilengkapi pengaturan privasi (tampil untuk publik, hanya *followers*, atau disembunyikan).
* **Tab 1 — Feeds:** Menampilkan daftar postingan blog/utas milik pengguna, lengkap dengan fitur **Edit Postingan** (dengan indikator status edit), serta interaksi *Like*, *Comment*, *Bookmark/Save*, dan *Share*.
* **Tab 2 — Travel History:** Rekam jejak kota dan provinsi yang pernah dikunjungi pengguna, terisi secara otomatis berdasarkan data GPS dari setiap postingan yang diterbitkan.
* **Tab 3 — Saved:** Kumpulan utas cerita milik kreator lain yang disimpan untuk referensi perjalanan mendatang.
* **Tab 4 — Layanan (Khusus Verified Guide/Host):** Etalase penawaran paket *Open Trip*, unit kendaraan sewa, dan kamar *homestay*/kos yang dikelola oleh pemilik profil.

### 4.2 Sistem Postingan Hibrida + Auto-GPS
Setiap unggahan menggabungkan format cerita dan panduan praktis dalam satu struktur:
* **Narasi & Media:** Judul, cerita panjang berstruktur (format blog/utas), serta maksimal 5 foto yang dikompresi otomatis di sisi klien sebelum diunggah ke VPS.
* **Blok To-Do List (Opsional):** Daftar poin aktivitas atau rekomendasi spesifik dari penulis (misalnya: *"Datang sebelum pukul 07.00 pagi"* atau *"Coba menu kopi lokal"*).
* **Label Lokasi Penulisan:** Penanda otomatis lokasi penulisan berbasis GPS (*"Ditulis dari [Kota/Kabupaten]"*) serta penautan ke entitas nama tempat yang diulas.

### 4.3 Beranda, Explore, Detail Postingan, & My To-Do
* **Beranda & Explore:** Menyediakan *feed* kronologis maupun populer, kolom pencarian kata kunci, serta filter berdasarkan **Provinsi** dan **Kategori** (Kuliner, Alam, Budaya, *Hidden Gem*, Ramah Keluarga).
* **Detail Postingan & Tempat:** Menampilkan cerita utuh, rangkuman ulasan tempat, serta tombol aksi **"+ Simpan ke To-Do Saya"** pada setiap poin aktivitas yang ditulis kreator.
* **My To-Do (Trip Planner):** Ruang kerja pribadi berisi daftar aktivitas yang dikumpulkan dari berbagai postingan, dikelompokkan berdasarkan kota tujuan, dilengkapi *checkbox* status penyelesaian dan catatan pribadi.

---

## 5. Modul Layanan Guide, Sewa Kendaraan, & Homestay/Kos

Fitur ini memungkinkan pengguna yang telah membaca cerita seorang kreator lokal untuk langsung menyewa jasa maupun akomodasi dari orang yang sama. Pada tahap awal, pemesanan diarahkan ke WhatsApp penyedia jasa menggunakan *template* pesan terstruktur sebelum berkembang ke sistem pembayaran *escrow*.

| Kategori Layanan | Spesifikasi Data Wajib | Detail Tambahan & Kepercayaan |
| :--- | :--- | :--- |
| **Open Trip & Private Guide** | Nama paket, destinasi, jadwal keberangkatan (tanggal pasti atau fleksibel), harga per peserta, kuota maksimal, serta rincian fasilitas *include* dan *exclude*. | Rangkaian *itinerary* dapat disalin ke *My To-Do* peserta; menampilkan jumlah perjalanan yang telah sukses dipandu. |
| **Sewa Kendaraan** | Kategori (Motor, Mobil, Campervan), merek, tipe dan tahun produksi, jenis transmisi (Matic/Manual), harga sewa per 24 jam/mingguan, serta opsi lepas kunci atau dengan sopir. | Titik serah terima unit (stasiun/bandara/penginapan), syarat dokumen (e-KTP, SIM aktif), serta kelengkapan ekstra (helm SNI, jas hujan). |
| **Homestay & Kos** | Tipe properti (Homestay, Kos Harian, Kos Bulanan, Villa), tarif sewa (malam/minggu/bulan), kapasitas tamu, jumlah kamar tersedia, dan fasilitas utama (AC, Wi-Fi, kamar mandi dalam, parkir). | Titik lokasi dan jarak ke pusat aktivitas, aturan menginap (jam *check-in/out*, kategori penghuni), serta dokumentasi foto kamar dan kamar mandi. |

**Mekanisme Mitigasi Risiko:** Penyedia jasa wajib melewati verifikasi identitas (KTP, swafoto, dan bukti kepemilikan/pengelolaan STNK atau properti yang disimpan di penyimpanan privat PocketBase) serta memiliki rekam jejak postingan *Live GPS* di kota operasionalnya.

---

## 6. Strategi Monetisasi Terpadu

Model pendapatan dirancang bertahap mengikuti pertumbuhan komunitas dan validasi data lokasi:

| Pilar Monetisasi | Mekanisme Bisnis | Skema Pendapatan |
| :--- | :--- | :--- |
| **1. Ekonomi Kreator** | Penjualan *Premium Itinerary* mendetail (rute jam per jam, estimasi biaya, kontak lokal) yang dapat disalin ke *My To-Do* pembeli, serta fitur tip apresiasi pembaca (*"Traktir Kopi"*). | Komisi platform **15%–20%** per penjualan *itinerary* dan biaya layanan transaksi tip. |
| **2. Direktori Lokal (Model Google Reviews)** | Penayangan *Promoted To-Do* di posisi teratas pencarian kota, akun bisnis *freemium* bagi pemilik tempat untuk membalas ulasan dan memasang promo, serta penukaran poin ulasan GPS dengan voucher mitra. | Biaya iklan lokal per penempatan, langganan bulanan akun bisnis, dan komisi kemitraan *merchant*. |
| **3. Kurasi & Prestise (Model Michelin Guide)** | Pemberian lencana **"To-Do-In Curated"** bagi tempat dengan skor ulasan GPS tertinggi dan audit *Local Guide* (tidak dapat dibeli langsung), diikuti kampanye panduan wisata daerah. | Sponsorship Dinas Pariwisata atau korporat serta lisensi perangkat branding fisik (plakat/stiker QR Code resmi). |
| **4. Layanan Sewa & Open Trip** | Penyediaan etalase layanan di profil *Verified Guide/Host*. Gratis untuk kuota awal (maksimal 2 unit/paket) dan berbayar untuk pemilik armada atau kamar dalam jumlah banyak. | Langganan bulanan **Host Pro** untuk *unlimited listing* serta komisi *escrow* **5%–10%** saat fitur pembayaran DP aktif. |

---

## 7. Arsitektur Koleksi Database Awal (PocketBase)

Untuk menjaga performa kueri tetap ringan di VPS Contabo pada tahap MVP hingga ekspansi awal, struktur data dipusatkan pada enam koleksi utama:

* `users`: Data autentikasi, `username` unik, profil, `whatsapp`, `instagram`, `show_contact`, dan status verifikasi (`is_verified_guide`).
* `places`: Entitas destinasi/tempat usaha (`name`, `category`, `city`, `province`, `lat`, `lng`, `is_curated`) sebagai induk kumpulan ulasan.
* `posts`: Utas cerita (`author`, `place`, `title`, `content`, `images`, `todo_items` JSON, `gps_city`, `lat`, `lng`, `is_edited`).
* `user_todos`: Daftar rencana perjalanan pribadi (`user`, `source_post`, `city`, `task_title`, `is_completed`, `notes`).
* `interactions` & `comments`: Pencatatan relasi *like*, *bookmark*, *follow*, dan komentar utas.
* `listings`: Katalog layanan milik *Verified Guide/Host* (`owner`, `type`, `title`, `price`, `price_unit`, `city`, `specs` JSON, `is_available`).