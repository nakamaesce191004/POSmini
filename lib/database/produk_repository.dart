import '../models/produk_model.dart';
import 'db_helper.dart';

class ProdukRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(Produk produk) async {
    final db = await _dbHelper.database;
    return await db.insert('produk', produk.toMap());
  }

  Future<List<Produk>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('produk');
    return List.generate(maps.length, (i) {
      return Produk.fromMap(maps[i]);
    });
  }

  Future<int> update(Produk produk) async {
    final db = await _dbHelper.database;
    return await db.update(
      'produk',
      produk.toMap(),
      where: 'id = ?',
      whereArgs: [produk.id],
    );
  }

  Future<Produk?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'produk',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Produk.fromMap(maps[0]);
  }

  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'produk',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
