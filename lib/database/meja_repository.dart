import '../models/meja_model.dart';
import 'db_helper.dart';

class MejaRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insert(Meja meja) async {
    final db = await _dbHelper.database;
    return await db.insert('meja', meja.toMap());
  }

  Future<void> ensureMejaSeeded() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('meja');
    if (maps.isEmpty) {
      for (int i = 1; i <= 20; i++) {
        await db.insert('meja', {
          'id': i.toString(),
          'nama': 'Meja $i',
          'kategori': 'Umum',
          'isActive': 1,
        });
      }
    }
  }

  Future<List<Meja>> getAll() async {
    await ensureMejaSeeded();
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('meja');
    return List.generate(maps.length, (i) {
      return Meja.fromMap(maps[i]);
    });
  }

  Future<List<Meja>> getActive() async {
    await ensureMejaSeeded();
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meja',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return Meja.fromMap(maps[i]);
    });
  }

  Future<int> update(Meja meja) async {
    final db = await _dbHelper.database;
    return await db.update(
      'meja',
      meja.toMap(),
      where: 'id = ?',
      whereArgs: [meja.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'meja',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
