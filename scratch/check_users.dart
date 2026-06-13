// Jalankan: dart run scratch/check_users.dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await getDatabasesPath();
  final path = '$dbPath${Platform.pathSeparator}kasirr.db';

  print('Database path: $path');
  print('File exists: ${File(path).existsSync()}');

  if (!File(path).existsSync()) {
    print('\n❌ Database file belum ada. Jalankan app dulu untuk membuat database.');
    return;
  }

  final db = await openDatabase(path, readOnly: true);

  // Cek apakah tabel users ada
  try {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
    if (tables.isEmpty) {
      print('\n❌ Tabel "users" belum ada. Jalankan app dulu.');
      await db.close();
      return;
    }

    // Query semua users
    final users = await db.query('users');

    print('\n${'=' * 60}');
    print('📋 DATA USER TERDAFTAR');
    print('${'=' * 60}');

    if (users.isEmpty) {
      print('\n(kosong) — Belum ada user terdaftar.');
    } else {
      for (int i = 0; i < users.length; i++) {
        final u = users[i];
        print('\n--- User ${i + 1} ---');
        print('  ID       : ${u['id']}');
        print('  Nama     : ${u['nama']}');
        print('  Username : ${u['username'] ?? '-'}');
        print('  Email    : ${u['email']}');
        print('  Password : ${u['password']}');
        print('  Role     : ${u['role']}');
      }
    }

    print('\n${'=' * 60}');
    print('Total: ${users.length} user terdaftar');
    print('${'=' * 60}');
  } catch (e) {
    print('\n❌ Error: $e');
  }

  await db.close();
}
