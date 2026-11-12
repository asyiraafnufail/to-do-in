# UI/UX Design Specification & User Flow — TO-DO-IN-INDONESIA (`todoin.id`)

**Versi:** 1.0 (MVP & Ekosistem Guide/Host)  
**Target Platform:** Flutter Multi-Platform (Android, iOS, Windows, macOS, Web App) & Web Publik (SSR SEO)

---

## 1. Arsitektur Navigasi & Responsivitas

### 1.1 Navigasi Mobile (Android & iOS)
Menggunakan **Bottom Navigation Bar** dengan 4 menu utama dan 1 tombol aksi tengah (*Center Action Button*):
1. **Beranda:** Feed cerita perjalanan (*Terbaru* & *Mengikuti*).
2. **Explore & Sewa:** Direktori tempat, filter provinsi/kategori, serta katalog *Open Trip*, sewa kendaraan, dan *homestay*/kos.
3. **[+] Buat (Tombol Tengah):** Membuka *bottom sheet* pilihan aksi:
   * *Tulis Cerita & To-Do* (Semua Member)
   * *Tambah Layanan Sewa / Trip* (Khusus *Verified Guide/Host*)
4. **My To-Do:** *Checklist* rencana aktivitas perjalanan yang dikelompokkan per kota.
5. **Profil:** Identitas kreator, tab *Feeds*, *Travel History*, *Saved*, dan *Layanan*.

### 1.2 Navigasi Desktop & Web App
Menggunakan tata letak **3-Kolom Adaptif**:
* **Left Navigation Rail / Sidebar (240px):** Menu utama (*Beranda, Explore & Sewa, My To-Do, Profil*) dan tombol primer `+ Buat Postingan`.
* **Center Main Content (Max-width 680px):** Area *feed* cerita, detail utas, atau papan *My To-Do*.
* **Right Context Panel (320px):** Menampilkan destinasi *trending* minggu ini, filter cepat per provinsi, dan rekomendasi *Verified Local Guide*.

---

## 2. Alur Pengguna Utama (*Core User Flows*)

### 2.1 Alur Penulisan Cerita & Validasi Live GPS
```text
[Klik Tombol (+) Buat]
       │
       ▼
[Buka Form CreatePostScreen] ──► Sistem otomatis meminta izin & mengambil koordinat GPS
       │                                  │
       │                        ┌─────────┴─────────┐
       │                        ▼                   ▼
       │               [GPS Diizinkan]       [GPS Ditolak]
       │               Reverse Geocoding     Pilih Kota Manual
       │               (Kecamatan, Kota)     (Tanpa Badge Live)
       │                        │                   │
       ▼                        └─────────┬─────────┘
[Isi Judul, Cerita, Foto (Auto-Compress), & Blok To-Do (Opsional)]
       │
       ▼
[Klik Publikasikan] ──► Simpan ke PocketBase (posts)
       │
       ├──► Tampil di Feed dengan label "Ditulis dari [Kota]"
       └──► Otomatis memperbarui daftar kota di Tab "Travel History" Profil
```

### 2.2 Alur Konsumsi Konten ke Perencanaan & Reservasi Layanan
```text
[Pengguna Membaca Utas di Aplikasi / Google Search (SEO)]
       │
       ├──► Melihat Badge "Live GPS" (Validasi kehadiran fisik penulis)
       │
       ├──► Klik "+ To-Do" pada poin aktivitas penulis
       │           │
       │           ▼
       │    [Masuk ke Halaman "My To-Do" (Dikelompokkan per Kota)]
       │
       └──► Klik Kartu Layanan Penulis di bawah cerita (Sewa Motor / Homestay / Open Trip)
                   │
                   ▼
            [Halaman Detail Layanan (ListingDetailScreen)]
                   │
                   ▼
            Klik "Booking via WhatsApp" ──► Membuka WA dengan template pesan otomatis
```

### 2.3 Alur Verifikasi & Aktivasi Tab Layanan (Guide / Host)
```text
[Member Masuk ke Pengaturan Profil]
       │
       ▼
[Klik "Daftar sebagai Local Guide / Host"]
       │
       ▼
[Unggah KTP, Swafoto, & Bukti Aset (STNK / Foto Properti)] ──► Disimpan di Private Storage
       │
       ▼
[Admin Memverifikasi di Panel PocketBase]
       │
       ▼
[Status is_verified_host = true] ──► Lencana Terverifikasi & Tab "Layanan" Aktif di Profil
```

---

## 3. Wireframe Tata Letak Halaman Utama

### 3.1 Kartu Postingan Hibrida (`FeedCard`)
```text
+-------------------------------------------------------+
| [Avatar] Nama Kreator  ✓ (Badge Guide)       [Ikuti]  |
| 📍 Ditulis dari: Depok, Sleman • 2 jam lalu  [Live]   |
+-------------------------------------------------------+
|                                                       |
|            [ Carousel Foto (Rasio 4:3) ]              |
|            (Indikator slide: 1 / 5)                   |
|                                                       |
+-------------------------------------------------------+
| #Kuliner  📍 Kopi Klotok Pakem                        |
| Judul Cerita: Sarapan Pagi Kabut Tipis di Lereng...   |
| Cuplikan paragraf pembuka maksimal 3 baris... Baca    |
|                                                       |
| +---------------------------------------------------+ |
| | 📋 To-Do dari Penulis (3 Aktivitas):              | |
| | • Datang sebelum jam 07.00 pagi         [+ To-Do] | |
| | • Pesan pisang goreng & sayur lodeh     [+ To-Do] | |
| +---------------------------------------------------+ |
+-------------------------------------------------------+
| ❤️ 124    💬 18    🔖 Simpan         🔗 Bagikan       |
+-------------------------------------------------------+
```

### 3.2 Halaman Profil Pengguna (`ProfileScreen`)
```text
+-------------------------------------------------------+
| [Avatar]      142          1.2K          18           |
|              Cerita      Pengikut       Kota          |
|                                                       |
| Nama Lengkap  [Lencana Verified Guide/Host]           |
| @username • 📍 Domisili: Yogyakarta                   |
| Bio singkat kreator maksimal 160 karakter...          |
|                                                       |
| [ Edit Profil ]  [ Bagikan ]   [ 💬 WA ]  [ 📷 IG ]   |
+-------------------------------------------------------+
|  [ Feeds ]  |  [ Travel History ]  | [ Saved ] | [Layanan*]
+-------------------------------------------------------+
| (Area Konten Tab Aktif)                               |
| • Feeds: Daftar cerita + menu (⋮) untuk Edit Post     |
| • Travel History: Daftar Provinsi & Kota (auto-GPS)   |
| • Saved: Kumpulan utas yang di-bookmark               |
| • Layanan*: Kartu Open Trip, Kendaraan, Homestay/Kos  |
+-------------------------------------------------------+
*Catatan: Tab Layanan hanya tampil jika is_verified_host = true
```

### 3.3 Halaman My To-Do (`MyTodoScreen`)
```text
+-------------------------------------------------------+
| My To-Do (Rencana Perjalanan)           [+ Manual]    |
| Filter Kota: [ Semua ] [ Yogyakarta ] [ Malang ]      |
+-------------------------------------------------------+
| 📍 DI YOGYAKARTA (2 dari 4 Selesai)                   |
| +---------------------------------------------------+ |
| | [✓] Datang ke Kopi Klotok sebelum jam 07.00       | |
| |     Sumber: @budi_jalan • Catatan: Bawa uang tunai| |
| +---------------------------------------------------+ |
| | [ ] Sewa Honda Vario 160 (Stasiun Tugu)           | |
| |     Sumber: Layanan @jogja_guide                  | |
| +---------------------------------------------------+ |
+-------------------------------------------------------+
```

### 3.4 Halaman Detail Layanan (`ListingDetailScreen`)
```text
+-------------------------------------------------------+
| [<]  Detail Layanan                        [🔗] [🔖]  |
+-------------------------------------------------------+
| [ Galeri Foto Unit / Kamar / Destinasi Trip ]         |
+-------------------------------------------------------+
| [Tersedia]  •  Sewa Kendaraan  •  📍 Yogyakarta       |
| Honda Vario 160 ABS (2024) — Lepas Kunci              |
| Rp85.000 / 24 jam                                     |
+-------------------------------------------------------+
| Spesifikasi & Fasilitas:                              |
| • Transmisi: Matic          • Antar Jemput: Stasiun   |
| • Kelengkapan: 2 Helm SNI   • Syarat: e-KTP & SIM C   |
+-------------------------------------------------------+
| Dikelola oleh:                                        |
| [Avatar] @jogja_guide ✓ (Terverifikasi KTP & STNK)    |
+-------------------------------------------------------+
| [ + Simpan ke To-Do ]   [ 💬 Booking via WhatsApp ]   |
+-------------------------------------------------------+
```

---

## 4. Design System

### 4.1 Palet Warna (*Color Palette*)
* **Primary Brand (`Emerald Nusantara`):** `#0F766E` — Warna utama untuk navigasi aktif, tautan, dan identitas merek.
* **Secondary / Accent (`Terracotta Sunset`):** `#EA580C` — Warna kontras untuk tombol ajakan bertindak (*CTA*) seperti `+ To-Do` dan sorotan penting.
* **Live GPS Badge (`Verified Mint`):**
  * Latar Belakang: `#DCFCE7`
  * Teks & Ikon: `#15803D`
* **WhatsApp Action (`WA Green`):** `#16A34A` — Khusus tombol reservasi langsung ke WhatsApp.
* **Surface & Background:**
  * *Light Mode:* Background `#F8FAFC`, Surface/Card `#FFFFFF`, Border `#E2E8F0`.
  * *Dark Mode:* Background `#0F172A`, Surface/Card `#1E293B`, Border `#334155`.
* **Tipografi / Teks:**
  * Primary Text: `#0F172A` (Light) / `#F8FAFC` (Dark)
  * Secondary Text: `#475569` (Light) / `#CBD5E1` (Dark)
  * Muted / Metadata: `#94A3B8`

### 4.2 Tipografi (*Typography*)
* **Font Keluarga Utama:** `Plus Jakarta Sans` (Judul, Navigasi, Label Tombol) & `Inter` (Isi cerita panjang/blog).
* **Skala Ukuran:**
  * `H1 / Judul Artikel Detail`: `22sp`, Bold (`700`), Line-height `1.3`
  * `H2 / Judul Kartu Feed`: `17sp`, SemiBold (`600`), Line-height `1.35`
  * `Body / Isi Cerita Panjang`: `15sp`, Regular (`400`), Line-height `1.65` (dioptimalkan untuk kenyamanan membaca utas panjang)
  * `Caption / Metadata GPS & Waktu`: `12sp`, Medium (`500`), Line-height `1.4`

### 4.3 Standar Komponen UI (Flutter)
* **Card & Container:** `BorderRadius.circular(12)`, tanpa *elevation shadow* berlebih, menggunakan garis tepi `1px` (`Border.all`) agar tampilan bersih dan konsisten di mobile maupun desktop.
* **Tombol & Input Field:** `BorderRadius.circular(8)`, tinggi minimum area sentuh `44px` untuk aksesibilitas jempol di layar ponsel.
* **Chip Filter & Badge Status:** `BorderRadius.circular(999)` (*pill shape*) dengan padding horizontal `12px` dan vertikal `6px`.