import '../models/pelanggan_model.dart';
import 'db_helper.dart';

class PelangganRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(Pelanggan pelanggan) async {
    final db = await _dbHelper.database;
    return await db.insert('pelanggan', pelanggan.toMap());
  }

  Future<List<Pelanggan>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('pelanggan');
    return maps.map((m) => Pelanggan.fromMap(m)).toList();
  }
}
