import '../models/presensi_model.dart';
import 'db_helper.dart';

class PresensiRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(Presensi presensi) async {
    final db = await _dbHelper.database;
    return await db.insert('presensi', presensi.toMap());
  }

  Future<List<Presensi>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('presensi', orderBy: 'waktu DESC');
    return maps.map((m) => Presensi.fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('presensi', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearAll() async {
    final db = await _dbHelper.database;
    return await db.delete('presensi');
  }

  Future<String?> getLastStatus(String namaKaryawan) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'presensi',
      where: 'nama_karyawan = ?',
      whereArgs: [namaKaryawan],
      orderBy: 'waktu DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['status'] as String?;
    }
    return null;
  }
}
