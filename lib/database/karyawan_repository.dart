import '../models/karyawan_model.dart';
import 'db_helper.dart';

class KaryawanRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<void> insertKaryawan(Karyawan karyawan) async {
    final db = await _dbHelper.database;
    await db.insert('karyawan', karyawan.toMap());
  }

  Future<List<Karyawan>> getKaryawan() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('karyawan');
    return maps.map((map) => Karyawan.fromMap(map)).toList();
  }

  Future<void> updateKaryawan(Karyawan karyawan) async {
    final db = await _dbHelper.database;
    await db.update(
      'karyawan',
      karyawan.toMap(),
      where: 'id = ?',
      whereArgs: [karyawan.id],
    );
  }

  Future<void> deleteKaryawan(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'karyawan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
