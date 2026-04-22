import 'db_helper.dart';

class SettingsRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<String> getPin() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['pin_security'],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'].toString();
    }
    return '1234'; // Fallback
  }

  Future<void> updatePin(String newPin) async {
    final db = await _dbHelper.database;
    await db.update(
      'settings',
      {'value': newPin},
      where: 'id = ?',
      whereArgs: ['pin_security'],
    );
  }
}
