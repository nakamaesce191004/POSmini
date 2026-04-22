import '../models/metode_pembayaran_model.dart';
import 'db_helper.dart';

class MetodeRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(MetodePembayaran metode) async {
    final db = await _dbHelper.database;
    return await db.insert('metode_pembayaran', metode.toMap());
  }

  Future<List<MetodePembayaran>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('metode_pembayaran');
    return maps.map((m) => MetodePembayaran.fromMap(m)).toList();
  }

  Future<int> update(MetodePembayaran metode) async {
    final db = await _dbHelper.database;
    return await db.update(
      'metode_pembayaran',
      metode.toMap(),
      where: 'id = ?',
      whereArgs: [metode.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'metode_pembayaran',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
