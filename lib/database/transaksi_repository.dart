import 'package:flutter/foundation.dart';
import '../models/transaksi_model.dart';
import 'db_helper.dart';

class DashboardSummary {
  final int totalPenjualan;
  final int totalHpp;
  final int totalProdukTerjual;

  const DashboardSummary({
    required this.totalPenjualan,
    required this.totalHpp,
    required this.totalProdukTerjual,
  });

  int get laba => totalPenjualan - totalHpp;
}

class DashboardTrendPoint {
  final DateTime tanggal;
  final int totalPenjualan;
  final int totalHpp;
  final int totalProdukTerjual;

  const DashboardTrendPoint({
    required this.tanggal,
    required this.totalPenjualan,
    required this.totalHpp,
    required this.totalProdukTerjual,
  });

  int get laba => totalPenjualan - totalHpp;
}

class TransaksiRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(Transaksi transaksi) async {
    final db = await _dbHelper.database;
    
    // Use transaction to ensure both header and items are saved
    return await db.transaction((txn) async {
      int id = await txn.insert('transaksi', transaksi.toMap());
      
      for (var item in transaksi.items) {
        await txn.insert('transaksi_items', {
          'transaksi_id': transaksi.id ?? id.toString(),
          'produk_id': item.produkId,
          'qty': item.qty,
          'harga_saat_ini': item.hargaSaatIni,
        });
      }
      return id;
    });
  }

  Future<List<Transaksi>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('transaksi', orderBy: 'tanggal DESC');
    
    List<Transaksi> transaksis = [];
    for (var map in maps) {
      final List<Map<String, dynamic>> itemMaps = await db.rawQuery('''
        SELECT ti.*, p.nama
        FROM transaksi_items ti
        LEFT JOIN produk p ON ti.produk_id = p.id
        WHERE ti.transaksi_id = ?
      ''', [map['id']]);
      
      List<TransaksiItem> items = itemMaps.map((i) => TransaksiItem.fromMap(i)).toList();
      transaksis.add(Transaksi.fromMap(map, items));
    }
    return transaksis;
  }

  Future<int> update(Transaksi transaksi) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Update main record
      int count = await txn.update(
        'transaksi',
        transaksi.toMap(),
        where: 'id = ?',
        whereArgs: [transaksi.id],
      );

      // 2. Delete old items
      await txn.delete(
        'transaksi_items',
        where: 'transaksi_id = ?',
        whereArgs: [transaksi.id],
      );

      // 3. Insert new items
      for (var item in transaksi.items) {
        await txn.insert('transaksi_items', {
          'transaksi_id': transaksi.id,
          'produk_id': item.produkId,
          'qty': item.qty,
          'harga_saat_ini': item.hargaSaatIni,
        });
      }
      return count;
    });
  }

  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await txn.delete('transaksi_items', where: 'transaksi_id = ?', whereArgs: [id]);
      return await txn.delete('transaksi', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> getTotalHpp() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(ti.qty * p.harga_beli), 0) AS total_hpp
      FROM transaksi_items ti
      INNER JOIN transaksi t ON ti.transaksi_id = t.id
      INNER JOIN produk p ON ti.produk_id = p.id
      WHERE t.jenis = ?
    ''', ['pemasukan']);

    final totalHpp = result.first['total_hpp'];
    if (totalHpp is int) return totalHpp;
    if (totalHpp is num) return totalHpp.toInt();
    return 0;
  }

  Future<DashboardSummary> getDashboardSummary() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        (
          SELECT COALESCE(SUM(nominal), 0)
          FROM transaksi
          WHERE jenis = 'pemasukan'
        ) AS total_penjualan,
        (
          SELECT COALESCE(SUM(ti.qty * p.harga_beli), 0)
          FROM transaksi_items ti
          INNER JOIN transaksi t ON ti.transaksi_id = t.id
          INNER JOIN produk p ON ti.produk_id = p.id
          WHERE t.jenis = 'pemasukan'
        ) AS total_hpp,
        (
          SELECT COALESCE(SUM(ti.qty), 0)
          FROM transaksi_items ti
          INNER JOIN transaksi t ON ti.transaksi_id = t.id
          WHERE t.jenis = 'pemasukan'
        ) AS total_produk_terjual
    ''');

    final row = result.first;
    return DashboardSummary(
      totalPenjualan: _asInt(row['total_penjualan']),
      totalHpp: _asInt(row['total_hpp']),
      totalProdukTerjual: _asInt(row['total_produk_terjual']),
    );
  }

  Future<List<DashboardTrendPoint>> getDashboardTrend({int days = 7}) async {
    final db = await _dbHelper.database;
    final startDate = DateTime.now().subtract(Duration(days: days - 1));
    final startDateIso = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).toIso8601String();

    final salesRows = await db.rawQuery('''
      SELECT
        substr(tanggal, 1, 10) AS tanggal,
        COALESCE(SUM(nominal), 0) AS total_penjualan
      FROM transaksi
      WHERE jenis = 'pemasukan' AND tanggal >= ?
      GROUP BY substr(tanggal, 1, 10)
      ORDER BY tanggal ASC
    ''', [startDateIso]);

    final hppRows = await db.rawQuery('''
      SELECT
        substr(t.tanggal, 1, 10) AS tanggal,
        COALESCE(SUM(ti.qty * p.harga_beli), 0) AS total_hpp,
        COALESCE(SUM(ti.qty), 0) AS total_produk_terjual
      FROM transaksi_items ti
      INNER JOIN transaksi t ON ti.transaksi_id = t.id
      INNER JOIN produk p ON ti.produk_id = p.id
      WHERE t.jenis = 'pemasukan' AND t.tanggal >= ?
      GROUP BY substr(t.tanggal, 1, 10)
      ORDER BY tanggal ASC
    ''', [startDateIso]);

    final salesMap = {
      for (final row in salesRows)
        row['tanggal'].toString(): _asInt(row['total_penjualan']),
    };
    final hppMap = {
      for (final row in hppRows)
        row['tanggal'].toString(): {
          'hpp': _asInt(row['total_hpp']),
          'qty': _asInt(row['total_produk_terjual']),
        },
    };

    return List.generate(days, (index) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));
      final key = date.toIso8601String().substring(0, 10);
      final hppData = hppMap[key];

      return DashboardTrendPoint(
        tanggal: date,
        totalPenjualan: salesMap[key] ?? 0,
        totalHpp: hppData?['hpp'] as int? ?? 0,
        totalProdukTerjual: hppData?['qty'] as int? ?? 0,
      );
    });
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
  Future<List<String>> getUsedSeatsToday() async {
    final db = await _dbHelper.database;
    final String todayString = DateTime.now().toString().substring(0, 10); // YYYY-MM-DD
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transaksi',
      columns: ['no_meja'],
      where: "tanggal LIKE ? AND no_meja IS NOT NULL AND no_meja != '' AND (status = 'Pending' OR status = 'pending')",
      whereArgs: ['$todayString%'],
    );
    
    return maps.map((m) => m['no_meja'].toString()).toSet().toList(); // Unique list
  }

  Future<void> clearSeat(String noMeja) async {
    final db = await _dbHelper.database;
    final String todayString = DateTime.now().toString().substring(0, 10);
    
    // Cari transaksi hari ini yang menggunakan meja ini
    await db.update(
      'transaksi',
      {'no_meja': null}, 
      where: "tanggal LIKE ? AND no_meja = ?",
      whereArgs: ['$todayString%', noMeja],
    );
  }

  Future<List<Transaksi>> getPendingTransactions() async {
    final db = await _dbHelper.database;
    final String todayString = DateTime.now().toString().substring(0, 10);
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'transaksi',
        where: 'status = ? OR status = ?', // Check both cases just in case
        whereArgs: ['Pending', 'pending'],
        orderBy: 'tanggal DESC',
      );
      
      List<Transaksi> transaksis = [];
      for (var map in maps) {
        final List<Map<String, dynamic>> itemMaps = await db.rawQuery('''
          SELECT ti.*, p.nama
          FROM transaksi_items ti
          LEFT JOIN produk p ON ti.produk_id = p.id
          WHERE ti.transaksi_id = ?
        ''', [map['id']]);
        
        List<TransaksiItem> items = itemMaps.map((m) => TransaksiItem.fromMap(m)).toList();
        transaksis.add(Transaksi.fromMap(map, items));
      }
      return transaksis;
    } catch (e) {
      debugPrint("Gagal mengambil pesanan aktif: $e");
      // Jika kolom status belum ada di DB lama, mungkin ini penyebabnya.
      return [];
    }
  }
}
