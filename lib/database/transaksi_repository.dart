import 'package:flutter/foundation.dart';
import '../models/transaksi_model.dart';
import 'db_helper.dart';
import 'resep_repository.dart'; // Tambahkan ini

class DashboardSummary {
  final int totalPenjualan;
  final int totalHpp;
  final int totalProdukTerjual;
  final int totalDiskon;
  final int totalPajak;
  final int totalPengeluaranManual;

  const DashboardSummary({
    required this.totalPenjualan,
    required this.totalHpp,
    required this.totalProdukTerjual,
    required this.totalDiskon,
    required this.totalPajak,
    required this.totalPengeluaranManual,
  });

  // Laba = (Penjualan - Diskon) - HPP - Pengeluaran Manual
  int get laba => (totalPenjualan - totalDiskon) - totalHpp - totalPengeluaranManual;
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

        // POTONG STOK BAHAN BAKU JIKA STATUS SELESAI
        if (transaksi.status == 'Selesai') {
          await ResepRepository().kurangiStokBahanBaku(item.produkId, item.qty, executor: txn);
        }
      }
      return id;
    });
  }

  Future<List<Transaksi>> getAll({int limit = 50, String? startDate, String? endDate, bool? isPrinted, bool? isSettled}) async {
    final db = await _dbHelper.database;
    
    List<String> conditions = [];
    List<Object?> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      conditions.add("tanggal >= ? AND tanggal <= ?");
      whereArgs.addAll([startDate, endDate]);
    } else if (startDate != null) {
      conditions.add("tanggal >= ?");
      whereArgs.add(startDate);
    }

    if (isPrinted != null) {
      conditions.add("is_printed = ?");
      whereArgs.add(isPrinted ? 1 : 0);
    }

    if (isSettled != null) {
      conditions.add("is_settled = ?");
      whereArgs.add(isSettled ? 1 : 0);
    }

    String? whereClause = conditions.isEmpty ? null : conditions.join(" AND ");

    // 1. Ambil header transaksi
    final List<Map<String, dynamic>> maps = await db.query(
      'transaksi', 
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'tanggal DESC',
      limit: limit,
    );
    
    if (maps.isEmpty) return [];

    // 2. Ambil semua item untuk transaksi-transaksi tersebut dalam satu kueri
    final List<String> ids = maps.map((m) => m['id'].toString()).toList();
    final String placeholders = ids.map((_) => '?').join(',');
    
    final List<Map<String, dynamic>> allItems = await db.rawQuery('''
      SELECT ti.*, p.nama
      FROM transaksi_items ti
      LEFT JOIN produk p ON ti.produk_id = p.id
      WHERE ti.transaksi_id IN ($placeholders)
    ''', ids);

    // 3. Kelompokkan item berdasarkan transaksi_id
    Map<String, List<TransaksiItem>> itemsByTrx = {};
    for (var itemMap in allItems) {
      final trxId = itemMap['transaksi_id'].toString();
      itemsByTrx.putIfAbsent(trxId, () => []).add(TransaksiItem.fromMap(itemMap));
    }
    
    // 4. Gabungkan
    return maps.map((m) {
      final trxId = m['id'].toString();
      return Transaksi.fromMap(m, itemsByTrx[trxId] ?? []);
    }).toList();
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

        // POTONG STOK BAHAN BAKU JIKA STATUS BERUBAH JADI SELESAI
        if (transaksi.status == 'Selesai') {
          await ResepRepository().kurangiStokBahanBaku(item.produkId, item.qty, executor: txn);
        }
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

  Future<DashboardSummary> getDashboardSummary({String? startDate, String? endDate, bool? isPrinted, bool? isSettled}) async {
    final db = await _dbHelper.database;
    String dateFilter = "";
    List<Object?> args = [];
    
    if (startDate != null && endDate != null) {
      dateFilter = " AND tanggal >= ? AND tanggal <= ?";
      args = [startDate, endDate];
    } else if (startDate != null) {
      dateFilter = " AND tanggal >= ?";
      args = [startDate];
    }

    if (isPrinted != null) {
      dateFilter += " AND is_printed = ?";
      args.add(isPrinted ? 1 : 0);
    }

    if (isSettled != null) {
      dateFilter += " AND is_settled = ?";
      args.add(isSettled ? 1 : 0);
    }

    final result = await db.rawQuery('''
      SELECT
        SUM(nominal) AS total_penjualan,
        SUM(diskon) AS total_diskon,
        SUM(pajak) AS total_pajak,
        (
          SELECT SUM(ti.qty * p.harga_beli)
          FROM transaksi_items ti
          JOIN produk p ON ti.produk_id = p.id
          JOIN transaksi t ON ti.transaksi_id = t.id
          WHERE t.jenis = 'pemasukan' $dateFilter
        ) AS total_hpp,
        (
          SELECT SUM(ti.qty)
          FROM transaksi_items ti
          JOIN transaksi t ON ti.transaksi_id = t.id
          WHERE t.jenis = 'pemasukan' $dateFilter
        ) AS total_produk_terjual,
        (
          SELECT SUM(nominal)
          FROM transaksi
          WHERE jenis = 'pengeluaran' $dateFilter
        ) AS total_pengeluaran_manual
      FROM transaksi
      WHERE jenis = 'pemasukan' $dateFilter
    ''', [...args, ...args, ...args, ...args]);

    final row = result.first;
    return DashboardSummary(
      totalPenjualan: _asInt(row['total_penjualan']),
      totalHpp: _asInt(row['total_hpp']),
      totalProdukTerjual: _asInt(row['total_produk_terjual']),
      totalDiskon: _asInt(row['total_diskon']),
      totalPajak: _asInt(row['total_pajak']),
      totalPengeluaranManual: _asInt(row['total_pengeluaran_manual']),
    );
  }

  Future<List<DashboardTrendPoint>> getDashboardTrend({int days = 7, String? customStartDate}) async {
    final db = await _dbHelper.database;
    final startDate = customStartDate != null 
        ? DateTime.parse(customStartDate) 
        : DateTime.now().subtract(Duration(days: days - 1));
        
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
    final map = await getOccupiedSeatsWithCustomer();
    return map.keys.toList();
  }

  Future<Map<String, String>> getOccupiedSeatsWithCustomer() async {
    final db = await _dbHelper.database;
    final String todayString = DateTime.now().toString().substring(0, 10);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transaksi',
      columns: ['no_meja', 'pelanggan'],
      where: "tanggal LIKE ? AND no_meja IS NOT NULL AND no_meja != ''",
      whereArgs: ['$todayString%'],
      orderBy: 'tanggal ASC',
    );
    
    final Map<String, String> result = {};
    for (var m in maps) {
      result[m['no_meja'].toString()] = m['pelanggan'].toString();
    }
    return result;
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
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'transaksi',
        where: 'status = ? OR status = ?',
        whereArgs: ['Pending', 'pending'],
        orderBy: 'tanggal DESC',
      );
      
      if (maps.isEmpty) return [];

      final List<String> ids = maps.map((m) => m['id'].toString()).toList();
      final String placeholders = ids.map((_) => '?').join(',');
      
      final List<Map<String, dynamic>> allItems = await db.rawQuery('''
        SELECT ti.*, p.nama
        FROM transaksi_items ti
        LEFT JOIN produk p ON ti.produk_id = p.id
        WHERE ti.transaksi_id IN ($placeholders)
      ''', ids);

      Map<String, List<TransaksiItem>> itemsByTrx = {};
      for (var itemMap in allItems) {
        final trxId = itemMap['transaksi_id'].toString();
        itemsByTrx.putIfAbsent(trxId, () => []).add(TransaksiItem.fromMap(itemMap));
      }
      
      return maps.map((m) {
        final trxId = m['id'].toString();
        return Transaksi.fromMap(m, itemsByTrx[trxId] ?? []);
      }).toList();
    } catch (e) {
      debugPrint("Gagal mengambil pesanan aktif: $e");
      return [];
    }
  }

  Future<int> updatePrintedStatus(String id, bool isPrinted) async {
    final db = await _dbHelper.database;
    return await db.update(
      'transaksi',
      {'is_printed': isPrinted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsSettled(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    final String placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE transaksi SET is_settled = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }
}
