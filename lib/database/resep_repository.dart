import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/resep_model.dart';
import 'db_helper.dart';

class ResepRepository {
  final DBHelper _dbHelper = DBHelper();

  // BAHAN BAKU CRUD
  Future<int> insertBahan(BahanBaku bahan) async {
    final db = await _dbHelper.database;
    return await db.insert('bahan_baku', bahan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BahanBaku>> getAllBahan() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('bahan_baku', orderBy: 'nama ASC');
    return maps.map((m) => BahanBaku.fromMap(m)).toList();
  }

  Future<int> deleteBahan(String id) async {
    final db = await _dbHelper.database;
    return await db.delete('bahan_baku', where: 'id = ?', whereArgs: [id]);
  }

  // RESEP CRUD
  Future<int> insertResep(Resep resep) async {
    final db = await _dbHelper.database;
    return await db.insert('resep', resep.toMap());
  }

  Future<List<Resep>> getResepByProduk(String produkId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, b.nama as nama_bahan, b.harga_per_satuan, b.satuan
      FROM resep r
      JOIN bahan_baku b ON r.bahan_id = b.id
      WHERE r.produk_id = ?
    ''', [produkId]);
    return maps.map((m) => Resep.fromMap(m)).toList();
  }

  Future<void> deleteResepByProduk(String produkId) async {
    final db = await _dbHelper.database;
    await db.delete('resep', where: 'produk_id = ?', whereArgs: [produkId]);
  }

  // Calculate Product HPP based on recipe
  Future<int> calculateProdukHpp(String produkId) async {
    final resepList = await getResepByProduk(produkId);
    double total = 0;
    for (var r in resepList) {
      total += r.totalHppContribution;
    }
    return total.round();
  }

  // POTONG STOK OTOMATIS BERDASARKAN PENJUALAN
  Future<void> kurangiStokBahanBaku(String produkId, int qtyTerjual, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _dbHelper.database;
    
    // 1. Ambil semua bahan yang ada di resep produk ini
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, b.nama as nama_bahan, b.harga_per_satuan, b.satuan
      FROM resep r
      JOIN bahan_baku b ON r.bahan_id = b.id
      WHERE r.produk_id = ?
    ''', [produkId]);
    
    final resepList = maps.map((m) => Resep.fromMap(m)).toList();
    
    for (var resep in resepList) {
      final jumlahYangDikurangi = resep.qty * qtyTerjual;
      
      // 2. Update tabel bahan_baku (total_bahan - pemakaian)
      await db.rawUpdate('''
        UPDATE bahan_baku 
        SET total_bahan = total_bahan - ? 
        WHERE id = ?
      ''', [jumlahYangDikurangi, resep.bahanId]);
      
    }
  }

  // HITUNG ESTIMASI SISA PORSI PRODUK
  Future<Map<String, int>> getEstimasiStokProduk() async {
    final db = await _dbHelper.database;
    
    // 1. Ambil semua bahan baku
    final List<Map<String, dynamic>> bahanMaps = await db.query('bahan_baku');
    Map<String, double> stokBahan = {
      for (var b in bahanMaps) b['id'].toString(): (b['total_bahan'] ?? 0.0).toDouble()
    };

    // 2. Ambil semua resep
    final List<Map<String, dynamic>> resepMaps = await db.query('resep');
    
    // Kelompokkan resep berdasarkan produk_id
    Map<String, List<Map<String, dynamic>>> resepPerProduk = {};
    for (var r in resepMaps) {
      final pid = r['produk_id'].toString();
      resepPerProduk.putIfAbsent(pid, () => []).add(r);
    }

    Map<String, int> estimasi = {};

    // 3. Hitung untuk setiap produk
    resepPerProduk.forEach((produkId, resepList) {
      double minPorsi = double.infinity;

      for (var r in resepList) {
        final bahanId = r['bahan_id'].toString();
        final qtyPerPorsi = (r['qty'] ?? 0.0).toDouble();
        final stokTersedia = stokBahan[bahanId] ?? 0.0;

        if (qtyPerPorsi > 0) {
          double porsiMungkin = stokTersedia / qtyPerPorsi;
          if (porsiMungkin < minPorsi) {
            minPorsi = porsiMungkin;
          }
        }
      }

      if (minPorsi == double.infinity) {
        // Produk tidak punya resep atau bahan?
        estimasi[produkId] = 0;
      } else {
        estimasi[produkId] = minPorsi.floor();
      }
    });

    return estimasi;
  }
}
