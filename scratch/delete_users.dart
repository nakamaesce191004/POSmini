// Jalankan: dart run scratch/delete_users.dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await getDatabasesPath();
  final path = '$dbPath${Platform.pathSeparator}kasirr.db';

  if (!File(path).existsSync()) {
    print('❌ Database tidak ditemukan.');
    return;
  }

  final db = await openDatabase(path);

  final before = await db.query('users');
  print('User sebelum hapus: ${before.length}');

  await db.delete('users');

  final after = await db.query('users');
  print('User setelah hapus: ${after.length}');
  print('\n✅ Semua data user berhasil dihapus!');

  await db.close();
}
