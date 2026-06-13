import 'db_helper.dart';

class SettingsRepository {
  final DBHelper _dbHelper = DBHelper();

  Future<void> ensureAccountsExist() async {
    final db = await _dbHelper.database;
    
    // Pastikan Akun Admin ada
    final List<Map<String, dynamic>> userMaps = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['admin_username'],
    );
    if (userMaps.isEmpty) {
      await db.insert('settings', {'id': 'admin_username', 'key': 'username', 'value': 'admin'});
      await db.insert('settings', {'id': 'admin_password', 'key': 'password', 'value': 'admin123'});
    }

    // Pastikan Akun Kasir ada
    final List<Map<String, dynamic>> kasirMaps = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['kasir_username'],
    );
    if (kasirMaps.isEmpty) {
      await db.insert('settings', {'id': 'kasir_username', 'key': 'username', 'value': 'kasir'});
      await db.insert('settings', {'id': 'kasir_password', 'key': 'password', 'value': 'kasir123'});
    }
  }

  // Admin Account Methods
  Future<String> getUsername() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', where: 'id = ?', whereArgs: ['admin_username']);
    return maps.isNotEmpty ? maps.first['value'].toString() : 'admin';
  }

  Future<void> updateUsername(String username) async {
    final db = await _dbHelper.database;
    await db.update('settings', {'value': username}, where: 'id = ?', whereArgs: ['admin_username']);
  }

  Future<String> getPassword() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', where: 'id = ?', whereArgs: ['admin_password']);
    return maps.isNotEmpty ? maps.first['value'].toString() : 'admin123';
  }

  Future<void> updatePassword(String password) async {
    final db = await _dbHelper.database;
    await db.update('settings', {'value': password}, where: 'id = ?', whereArgs: ['admin_password']);
  }

  // Kasir Account Methods
  Future<String> getKasirUsername() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', where: 'id = ?', whereArgs: ['kasir_username']);
    return maps.isNotEmpty ? maps.first['value'].toString() : 'kasir';
  }

  Future<void> updateKasirUsername(String username) async {
    final db = await _dbHelper.database;
    await db.update('settings', {'value': username}, where: 'id = ?', whereArgs: ['kasir_username']);
  }

  Future<String> getKasirPassword() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('settings', where: 'id = ?', whereArgs: ['kasir_password']);
    return maps.isNotEmpty ? maps.first['value'].toString() : 'kasir123';
  }

  Future<void> updateKasirPassword(String password) async {
    final db = await _dbHelper.database;
    await db.update('settings', {'value': password}, where: 'id = ?', whereArgs: ['kasir_password']);
  }
}
