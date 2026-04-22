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
}
