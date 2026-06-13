# Panduan Import Database Kasirr di Laragon (MySQL/MariaDB)

Panduan ini menjelaskan langkah demi langkah untuk membuat dan mengimpor skema database `kasirr` menggunakan **Laragon** dan **phpMyAdmin** pada sistem operasi Windows.

---

## Prasyarat
1. Pastikan Anda telah menginstal **Laragon** di komputer Anda. Jika belum, Anda bisa mengunduhnya dari [situs resmi Laragon](https://laragon.org/).
2. Pastikan servis **MySQL/MariaDB** di Laragon aktif.
3. Pastikan Anda memiliki akses ke **phpMyAdmin** (atau tools database bawaan Laragon seperti **HeidiSQL**).

---

## Langkah-Langkah Import Database via phpMyAdmin

### Langkah 1: Jalankan Laragon
1. Buka aplikasi **Laragon** di Windows Anda.
2. Klik tombol **"Start All"** untuk menjalankan servis Apache dan MySQL.

### Langkah 2: Buka phpMyAdmin
1. Klik kanan di mana saja pada area jendela Laragon.
2. Pilih menu **Quick App** -> **phpMyAdmin** (atau buka browser Anda dan ketikkan alamat: `http://localhost/phpmyadmin`).
3. Masuk menggunakan kredensial default database Laragon Anda:
   - **Username**: `root`
   - **Password**: *(kosongkan / biarkan kosong)*
4. Klik **Go** / **Masuk**.

*Catatan: Jika Anda menggunakan HeidiSQL (database manager default Laragon), cukup klik tombol **"Database"** di jendela Laragon, lalu hubungkan dengan user `root` tanpa password.*

### Langkah 3: Buat Database Baru
1. Setelah masuk ke phpMyAdmin, klik tab **"Databases"** (atau **"Basis Data"**) di bagian atas.
2. Pada bagian **"Create database"** (atau **"Buat basis data"**), masukkan nama database:
   - Nama: `kasirr`
   - Collation: `utf8mb4_unicode_ci` (opsional, biarkan default juga tidak apa-apa)
3. Klik tombol **"Create"** (atau **"Buat"**).
4. Database `kasirr` yang baru sekarang akan muncul di panel sebelah kiri. Klik pada nama database `kasirr` tersebut untuk masuk ke dalamnya.

### Langkah 4: Impor File SQL (`kasirr_mysql.sql`)
1. Setelah masuk ke database `kasirr`, klik tab **"Import"** (atau **"Impor"**) di menu bagian atas.
2. Pada bagian **"File to import"**, klik tombol **"Choose File"** (atau **"Pilih File"**).
3. Cari dan pilih file `kasirr_mysql.sql` yang berada di folder root proyek ini:
   - Path file: `d:\bisnis\kasirr\kasirr_mysql.sql`
4. Gulir ke bawah dan klik tombol **"Import"** (atau **"Kirim" / "Go"**).
5. Tunggu beberapa saat hingga muncul pesan sukses berwarna hijau: *"Import has been successfully finished, XXX queries executed."*

---

## Informasi Struktur Database
Setelah impor berhasil, tabel-tabel berikut akan otomatis terbuat beserta relasinya:
- **`produk`**: Menyimpan daftar produk, harga beli, harga jual, dan sisa stok.
- **`transaksi` & `transaksi_items`**: Menyimpan data invoice penjualan kasir beserta item detail belanjaan.
- **`meja`**: Daftar meja (nomor 1 sampai 20) untuk sistem pesanan di tempat.
- **`metode_pembayaran`**: Opsi pembayaran (Tunai, QRIS, Transfer).
- **`users` & `karyawan`**: Data akun login (Admin/Kasir) dan data staf.
- **`bahan_baku` & `resep`**: Manajemen resep makanan dan pengurangan stok bahan baku otomatis.
- **`presensi` & `settings`**: Log kehadiran karyawan dan konfigurasi keamanan PIN.

---

## Catatan Penting Hubungan Aplikasi (Flutter)
Aplikasi Flutter ini saat ini menggunakan **SQLite (`sqflite`)** sebagai database lokal untuk keperluan offline-first. Database MySQL di Laragon ini berfungsi sebagai:
1. **Skema Database Server**: Siap digunakan jika Anda ingin membangun API backend (seperti Laravel, Node.js, atau Go) untuk melakukan sinkronisasi data kasir lokal ke server cloud.
2. **Koneksi Langsung (Opsional)**: Jika Anda ingin menghubungkan aplikasi Flutter langsung ke database MySQL Laragon secara lokal melalui jaringan Wi-Fi, Anda dapat menginstal package client seperti `mysql1` di Flutter, meskipun metode REST API backend lebih direkomendasikan demi alasan keamanan.
