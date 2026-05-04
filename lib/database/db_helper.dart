import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  DBHelper._internal();

  factory DBHelper() => _instance;

  static Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'kasirr.db');
    Database db = await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Safety net: Pastikan tabel settings ada (mencegah error 'no such table')
    await _ensureSettingsTable(db);
    
    // Safety net v4: Pastikan kolom baru ada di transaksi
    await _ensureTransaksiColumns(db);

    // Safety net v6: Pastikan kolom status ada
    await _ensureStatusColumn(db);

    // Safety net v7: Pastikan tabel resep & bahan baku ada
    await _ensureRecipeTables(db);

    // Safety net v8: Pastikan kolom stok_minimal & supplier ada
    await _ensureBahanBakuColumns(db);

    // Safety net v9: Pastikan kolom is_printed ada
    await _ensureIsPrintedColumn(db);

    return db;
  }

  Future<void> _ensureIsPrintedColumn(Database db) async {
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA table_info(transaksi)');
      final bool exists = res.any((col) => col['name'] == 'is_printed');
      if (!exists) {
        await db.execute('ALTER TABLE transaksi ADD COLUMN is_printed INTEGER DEFAULT 0');
      }
    } catch (e) {
      debugPrint("Error ensuring is_printed column: $e");
    }
  }

  Future<void> _ensureBahanBakuColumns(Database db) async {
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA table_info(bahan_baku)');
      final columns = res.map((c) => c['name'].toString()).toList();
      
      if (!columns.contains('stok_minimal')) {
        await db.execute('ALTER TABLE bahan_baku ADD COLUMN stok_minimal REAL DEFAULT 0');
      }
      if (!columns.contains('supplier')) {
        await db.execute('ALTER TABLE bahan_baku ADD COLUMN supplier TEXT');
      }
    } catch (e) {
      debugPrint("Error ensuring bahan_baku columns: $e");
    }
  }

  Future<void> _ensureRecipeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bahan_baku (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        total_belanja INTEGER,
        total_bahan REAL,
        satuan TEXT,
        harga_per_satuan REAL,
        stok_minimal REAL DEFAULT 0,
        supplier TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resep (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produk_id TEXT,
        bahan_id TEXT,
        qty REAL,
        FOREIGN KEY (produk_id) REFERENCES produk (id) ON DELETE CASCADE,
        FOREIGN KEY (bahan_id) REFERENCES bahan_baku (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _ensureStatusColumn(Database db) async {
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA table_info(transaksi)');
      final bool exists = res.any((col) => col['name'] == 'status');
      if (!exists) {
        await db.execute('ALTER TABLE transaksi ADD COLUMN status TEXT DEFAULT "Selesai"');
      }
    } catch (e) {
      debugPrint("Error ensuring status column: $e");
    }
  }

  Future<void> _ensureMejaColumn(Database db) async {
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA table_info(transaksi)');
      final columns = res.map((c) => c['name'].toString()).toList();
      
      if (!columns.contains('no_meja')) {
        await db.execute('ALTER TABLE transaksi ADD COLUMN no_meja TEXT');
      }
    } catch (e) {
      debugPrint("Error ensuring no_meja column: $e");
    }
  }

  Future<void> _ensureTransaksiColumns(Database db) async {
    try {
      final List<Map<String, dynamic>> res = await db.rawQuery('PRAGMA table_info(transaksi)');
      final columns = res.map((c) => c['name'].toString()).toList();
      
      if (!columns.contains('diskon_info')) {
        await db.execute('ALTER TABLE transaksi ADD COLUMN diskon_info TEXT');
      }
      if (!columns.contains('pajak_info')) {
        await db.execute('ALTER TABLE transaksi ADD COLUMN pajak_info TEXT');
      }
    } catch (e) {
      debugPrint("Error ensuring columns: $e");
    }
  }

  Future<void> _ensureSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id TEXT PRIMARY KEY,
        key TEXT,
        value TEXT
      )
    ''');
    
    // Cek apakah PIN sudah ada, jika belum masukkan default
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['pin_security'],
    );
    if (maps.isEmpty) {
      await db.insert('settings', {
        'id': 'pin_security',
        'key': 'pin',
        'value': '1234',
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Pastikan tabel settings dibuat jika user mengupgrade dari versi 1
      await db.execute('''
        CREATE TABLE settings (
          id TEXT PRIMARY KEY,
          key TEXT,
          value TEXT
        )
      ''');
      // Set PIN default
      await db.insert('settings', {
        'id': 'pin_security',
        'key': 'pin',
        'value': '1234',
      });
    }
    
    if (oldVersion < 3) {
      // Tambahkan kolom diskon dan pajak ke tabel transaksi
      try {
        await db.execute('ALTER TABLE transaksi ADD COLUMN diskon INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE transaksi ADD COLUMN pajak INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint("Upgrade to v3 error: $e");
      }
    }

    if (oldVersion < 4) {
      // Tambahkan kolom info untuk mendetailkan persen atau nominal
      try {
        await db.execute('ALTER TABLE transaksi ADD COLUMN diskon_info TEXT');
        await db.execute('ALTER TABLE transaksi ADD COLUMN pajak_info TEXT');
      } catch (e) {
        debugPrint("Upgrade to v4 error: $e");
      }
    }

    if (oldVersion < 5) {
      // Tambahkan kolom no_meja
      try {
        await db.execute('ALTER TABLE transaksi ADD COLUMN no_meja TEXT');
      } catch (e) {
        debugPrint("Upgrade to v5 error: $e");
      }
    }
    if (oldVersion < 6) {
      // Tambahkan kolom status
      try {
        await db.execute('ALTER TABLE transaksi ADD COLUMN status TEXT DEFAULT "Selesai"');
      } catch (e) {
        debugPrint("Error upgrading to v6: $e");
      }
    }
    if (oldVersion < 7) {
      await _ensureRecipeTables(db);
    }
    if (oldVersion < 8) {
      await _ensureBahanBakuColumns(db);
    }
    if (oldVersion < 9) {
      await _ensureIsPrintedColumn(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Tables
    await db.execute('''
      CREATE TABLE produk (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        kategori TEXT,
        harga INTEGER,
        harga_beli INTEGER,
        stok INTEGER,
        icon_code INTEGER,
        icon_font_family TEXT,
        icon_font_package TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi (
        id TEXT PRIMARY KEY,
        jenis TEXT,
        nominal INTEGER,
        tanggal TEXT,
        deskripsi TEXT,
        pelanggan TEXT,
        metode TEXT,
        diskon INTEGER,
        pajak INTEGER,
        diskon_info TEXT,
        pajak_info TEXT,
        no_meja TEXT,
        status TEXT DEFAULT "Selesai",
        is_printed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaksi_id TEXT,
        produk_id TEXT,
        qty INTEGER,
        harga_saat_ini INTEGER,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE metode_pembayaran (
        id TEXT PRIMARY KEY,
        nama TEXT,
        tipe TEXT,
        nomor TEXT,
        atasNama TEXT,
        gambar TEXT,
        isActive INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pelanggan (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        telepon TEXT,
        alamat TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE presensi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_karyawan TEXT,
        waktu TEXT,
        status TEXT,
        foto_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id TEXT PRIMARY KEY,
        key TEXT,
        value TEXT
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Initial Metode Pembayaran
    await db.insert('metode_pembayaran', {
      'id': 'M1',
      'nama': 'Tunai',
      'tipe': 'Cash',
      'nomor': '',
      'atasNama': '',
      'gambar': '',
      'isActive': 1,
    });
    
    // Initial Pelanggan (Umum)
    await db.insert('pelanggan', {
      'id': 'P1',
      'nama': 'Umum',
    });

    // Initial Security PIN
    await db.insert('settings', {
      'id': 'pin_security',
      'key': 'pin',
      'value': '1234',
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('produk');
    await db.delete('transaksi');
    await db.delete('transaksi_items');
    await db.delete('metode_pembayaran');
    await db.delete('pelanggan');
    await db.delete('presensi');
  }

  Future<void> clearNonProductData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transaksi_items');
      await txn.delete('transaksi');
      await txn.delete('metode_pembayaran');
      await txn.delete('pelanggan');
      await txn.delete('presensi');
    });

    await _seedInitialData(db);
    await _ensureSettingsTable(db);
  }
}
