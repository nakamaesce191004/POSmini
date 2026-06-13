-- Skema Database Kasirr untuk MySQL/MariaDB (Laragon + phpMyAdmin)
-- Dibuat pada: 2026-06-11
-- Engine: InnoDB

CREATE DATABASE IF NOT EXISTS `kasirr` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `kasirr`;

-- 1. Tabel Users
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(100) NOT NULL,
  `username` VARCHAR(50) NOT NULL DEFAULT '',
  `email` VARCHAR(100) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `role` VARCHAR(20) DEFAULT 'admin',
  `reset_token` VARCHAR(255) DEFAULT NULL,
  `reset_token_expiry` VARCHAR(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Tabel Karyawan
CREATE TABLE IF NOT EXISTS `karyawan` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(100) NOT NULL,
  `posisi` VARCHAR(50) DEFAULT NULL,
  `telepon` VARCHAR(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Tabel Meja
CREATE TABLE IF NOT EXISTS `meja` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(50) NOT NULL,
  `kategori` VARCHAR(50) DEFAULT NULL,
  `isActive` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Tabel Produk
CREATE TABLE IF NOT EXISTS `produk` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(100) NOT NULL,
  `kategori` VARCHAR(50) DEFAULT NULL,
  `harga` INT NOT NULL,
  `harga_beli` INT NOT NULL,
  `stok` INT NOT NULL,
  `icon_code` INT NOT NULL,
  `icon_font_family` VARCHAR(50) DEFAULT NULL,
  `icon_font_package` VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Tabel Transaksi
CREATE TABLE IF NOT EXISTS `transaksi` (
  `id` VARCHAR(50) NOT NULL,
  `jenis` VARCHAR(20) NOT NULL,
  `nominal` INT NOT NULL,
  `tanggal` VARCHAR(50) NOT NULL,
  `deskripsi` TEXT DEFAULT NULL,
  `pelanggan` VARCHAR(100) DEFAULT NULL,
  `metode` VARCHAR(50) DEFAULT NULL,
  `diskon` INT DEFAULT 0,
  `pajak` INT DEFAULT 0,
  `diskon_info` VARCHAR(50) DEFAULT NULL,
  `pajak_info` VARCHAR(50) DEFAULT NULL,
  `no_meja` VARCHAR(50) DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT 'Selesai',
  `is_printed` TINYINT(1) DEFAULT 0,
  `is_settled` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Tabel Transaksi Items (Relasional)
CREATE TABLE IF NOT EXISTS `transaksi_items` (
  `id` INT AUTO_INCREMENT,
  `transaksi_id` VARCHAR(50) NOT NULL,
  `produk_id` VARCHAR(50) NOT NULL,
  `qty` INT NOT NULL,
  `harga_saat_ini` INT NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_transaksi_items_transaksi` FOREIGN KEY (`transaksi_id`) REFERENCES `transaksi` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Tabel Metode Pembayaran
CREATE TABLE IF NOT EXISTS `metode_pembayaran` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(50) DEFAULT NULL,
  `tipe` VARCHAR(50) DEFAULT NULL,
  `nomor` VARCHAR(50) DEFAULT NULL,
  `atasNama` VARCHAR(100) DEFAULT NULL,
  `gambar` VARCHAR(255) DEFAULT NULL,
  `isActive` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Tabel Pelanggan
CREATE TABLE IF NOT EXISTS `pelanggan` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(100) NOT NULL,
  `telepon` VARCHAR(20) DEFAULT NULL,
  `alamat` TEXT DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Tabel Presensi
CREATE TABLE IF NOT EXISTS `presensi` (
  `id` INT AUTO_INCREMENT,
  `nama_karyawan` VARCHAR(100) DEFAULT NULL,
  `waktu` VARCHAR(50) DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT NULL,
  `foto_path` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Tabel Settings
CREATE TABLE IF NOT EXISTS `settings` (
  `id` VARCHAR(50) NOT NULL,
  `key` VARCHAR(50) DEFAULT NULL,
  `value` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Tabel Bahan Baku
CREATE TABLE IF NOT EXISTS `bahan_baku` (
  `id` VARCHAR(50) NOT NULL,
  `nama` VARCHAR(100) NOT NULL,
  `total_belanja` INT DEFAULT 0,
  `total_bahan` REAL DEFAULT 0,
  `satuan` VARCHAR(20) DEFAULT NULL,
  `harga_per_satuan` REAL DEFAULT 0,
  `stok_minimal` REAL DEFAULT 0,
  `supplier` VARCHAR(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Tabel Resep
CREATE TABLE IF NOT EXISTS `resep` (
  `id` INT AUTO_INCREMENT,
  `produk_id` VARCHAR(50) NOT NULL,
  `bahan_id` VARCHAR(50) NOT NULL,
  `qty` REAL NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_resep_produk` FOREIGN KEY (`produk_id`) REFERENCES `produk` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_resep_bahan` FOREIGN KEY (`bahan_id`) REFERENCES `bahan_baku` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ==========================================
-- DATA AWAL (SEED SEEDS)
-- ==========================================

-- Seed Metode Pembayaran
INSERT INTO `metode_pembayaran` (`id`, `nama`, `tipe`, `nomor`, `atasNama`, `gambar`, `isActive`) VALUES
('M1', 'Tunai', 'Cash', '', '', '', 1),
('M2', 'QRIS', 'E-Wallet', '123456789', 'Toko Kasirr', '', 1),
('M3', 'Transfer Bank', 'Bank Transfer', '987654321', 'Toko Kasirr', '', 1);

-- Seed Pelanggan (Umum)
INSERT INTO `pelanggan` (`id`, `nama`, `telepon`, `alamat`) VALUES
('P1', 'Umum', '', '');

-- Seed Settings
INSERT INTO `settings` (`id`, `key`, `value`) VALUES
('pin_security', 'pin', '1234'),
('admin_username', 'username', 'admin'),
('admin_password', 'password', 'admin123');

-- Seed Users (Default Admin & Kasir)
INSERT INTO `users` (`id`, `nama`, `username`, `email`, `password`, `role`) VALUES
('U1', 'Administrator', 'admin', 'admin@kasirr.com', 'admin123', 'admin'),
('U2', 'Kasir Utama', 'kasir', 'kasir@kasirr.com', 'kasir123', 'kasir');

-- Seed Karyawan (Default Karyawan untuk presensi)
INSERT INTO `karyawan` (`id`, `nama`, `posisi`, `telepon`) VALUES
('K1', 'Budi Santoso', 'Kasir', '081234567890'),
('K2', 'Siti Rahma', 'Koki', '081234567891');

-- Seed Meja 1-20
INSERT INTO `meja` (`id`, `nama`, `kategori`, `isActive`) VALUES
('1', 'Meja 1', 'Umum', 1),
('2', 'Meja 2', 'Umum', 1),
('3', 'Meja 3', 'Umum', 1),
('4', 'Meja 4', 'Umum', 1),
('5', 'Meja 5', 'Umum', 1),
('6', 'Meja 6', 'Umum', 1),
('7', 'Meja 7', 'Umum', 1),
('8', 'Meja 8', 'Umum', 1),
('9', 'Meja 9', 'Umum', 1),
('10', 'Meja 10', 'Umum', 1),
('11', 'Meja 11', 'Umum', 1),
('12', 'Meja 12', 'Umum', 1),
('13', 'Meja 13', 'Umum', 1),
('14', 'Meja 14', 'Umum', 1),
('15', 'Meja 15', 'Umum', 1),
('16', 'Meja 16', 'Umum', 1),
('17', 'Meja 17', 'Umum', 1),
('18', 'Meja 18', 'Umum', 1),
('19', 'Meja 19', 'Umum', 1),
('20', 'Meja 20', 'Umum', 1);

-- Seed Produk (Beberapa data demo agar langsung terlihat)
INSERT INTO `produk` (`id`, `nama`, `kategori`, `harga`, `harga_beli`, `stok`, `icon_code`, `icon_font_family`, `icon_font_package`) VALUES
('PRD1', 'Nasi Goreng Spesial', 'Makanan', 22000, 15000, 50, 58355, 'MaterialIcons', NULL),
('PRD2', 'Ayam Goreng Penyet', 'Makanan', 18000, 12000, 30, 58355, 'MaterialIcons', NULL),
('PRD3', 'Es Teh Manis', 'Minuman', 5000, 2000, 100, 60219, 'MaterialIcons', NULL),
('PRD4', 'Kopi Susu Gula Aren', 'Minuman', 15000, 8000, 40, 57929, 'MaterialIcons', NULL),
('PRD5', 'Kentang Goreng', 'Cemilan', 12000, 7000, 25, 58355, 'MaterialIcons', NULL);
