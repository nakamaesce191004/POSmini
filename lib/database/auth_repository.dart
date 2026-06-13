import 'dart:math';
import 'package:flutter/material.dart';
import 'db_helper.dart';

class UserModel {
  final String id;
  final String nama;
  final String username;
  final String email;
  final String password;
  final String role;
  final String? resetToken;
  final String? resetTokenExpiry;

  UserModel({
    required this.id,
    required this.nama,
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    this.resetToken,
    this.resetTokenExpiry,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nama': nama,
    'username': username,
    'email': email,
    'password': password,
    'role': role,
    'reset_token': resetToken,
    'reset_token_expiry': resetTokenExpiry,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'].toString(),
    nama: map['nama'].toString(),
    username: map['username']?.toString() ?? '',
    email: map['email'].toString(),
    password: map['password'].toString(),
    role: map['role'].toString(),
    resetToken: map['reset_token']?.toString(),
    resetTokenExpiry: map['reset_token_expiry']?.toString(),
  );
}

class AuthRepository {
  final DBHelper _dbHelper = DBHelper();

  /// Pastikan tabel users sudah ada
  Future<void> ensureUsersTable() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT DEFAULT 'admin',
        reset_token TEXT,
        reset_token_expiry TEXT
      )
    ''');
    // Pastikan kolom username ada (migrasi dari versi sebelumnya)
    await _ensureUsernameColumn(db);
  }

  Future<void> _ensureUsernameColumn(dynamic db) async {
    try {
      final List<Map<String, dynamic>> res =
          await db.rawQuery('PRAGMA table_info(users)');
      final columns = res.map((c) => c['name'].toString()).toList();
      if (!columns.contains('username')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN username TEXT DEFAULT ""');
      }
    } catch (e) {
      debugPrint('Error ensuring username column: $e');
    }
  }

  /// Register user baru
  Future<String?> register({
    required String nama,
    required String username,
    required String email,
    required String password,
    String role = 'admin',
  }) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;

      // Cek apakah username sudah terdaftar
      final existingUser = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [username.trim()],
      );
      if (existingUser.isNotEmpty) {
        return 'Username sudah digunakan. Pilih username lain.';
      }

      // Cek apakah email sudah terdaftar
      final existingEmail = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email.trim()],
      );
      if (existingEmail.isNotEmpty) {
        return 'Email sudah terdaftar. Gunakan email lain.';
      }

      final id = 'USR${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('users', UserModel(
        id: id,
        nama: nama.trim(),
        username: username.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        role: role,
      ).toMap());

      return null; // null = sukses
    } catch (e) {
      debugPrint('Register error: $e');
      return 'Terjadi kesalahan saat mendaftar: $e';
    }
  }

  /// Login dengan username dan password
  Future<UserModel?> login({
    required String username,
    required String password,
  }) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;

      final results = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?) AND password = ?',
        whereArgs: [username.trim(), password],
      );

      if (results.isNotEmpty) {
        return UserModel.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      return null;
    }
  }

  /// Cek apakah ada user terdaftar
  Future<bool> hasAnyUser() async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;
      final results = await db.query('users', limit: 1);
      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Cek email terdaftar, generate reset token
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;

      final results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email.trim().toLowerCase()],
      );

      if (results.isEmpty) {
        return {
          'success': false,
          'error': 'Email tidak ditemukan. Pastikan email yang Anda masukkan sudah benar.',
        };
      }

      // Generate 6-digit token
      final token = _generateToken();
      // Token valid 15 menit
      final expiry = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();

      await db.update(
        'users',
        {'reset_token': token, 'reset_token_expiry': expiry},
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email.trim().toLowerCase()],
      );

      final user = UserModel.fromMap(results.first);
      return {
        'success': true,
        'token': token,
        'nama': user.nama,
        'email': user.email,
        'username': user.username,
      };
    } catch (e) {
      debugPrint('Request password reset error: $e');
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  /// Verifikasi token reset dan ubah password baru
  Future<String?> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;

      final results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?) AND reset_token = ?',
        whereArgs: [email.trim().toLowerCase(), token],
      );

      if (results.isEmpty) {
        return 'Kode verifikasi tidak valid.';
      }

      final user = UserModel.fromMap(results.first);
      if (user.resetTokenExpiry == null) {
        return 'Kode verifikasi sudah tidak berlaku. Minta ulang kode baru.';
      }

      final expiry = DateTime.parse(user.resetTokenExpiry!);
      if (DateTime.now().isAfter(expiry)) {
        return 'Kode verifikasi sudah kedaluwarsa. Minta ulang kode baru.';
      }

      // Update password dan hapus token
      await db.update(
        'users',
        {
          'password': newPassword,
          'reset_token': null,
          'reset_token_expiry': null,
        },
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email.trim().toLowerCase()],
      );

      return null; // null = sukses
    } catch (e) {
      debugPrint('Reset password error: $e');
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;
      final results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email.trim().toLowerCase()],
      );
      if (results.isNotEmpty) return UserModel.fromMap(results.first);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;
      final results = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [username.trim().toLowerCase()],
      );
      if (results.isNotEmpty) return UserModel.fromMap(results.first);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get first user by role
  Future<UserModel?> getFirstUserByRole(String role) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;
      final results = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: [role],
        limit: 1,
      );
      if (results.isNotEmpty) return UserModel.fromMap(results.first);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create or update user by role (used by Settings)
  Future<String?> createOrUpdateUserByRole({
    required String role,
    required String username,
    required String password,
  }) async {
    try {
      await ensureUsersTable();
      final db = await _dbHelper.database;
      
      final existingRoleUser = await getFirstUserByRole(role);
      
      // Check if username is taken by ANOTHER user
      final existingUsernameUser = await db.query(
        'users',
        where: 'LOWER(username) = LOWER(?)',
        whereArgs: [username.trim()],
      );
      
      if (existingUsernameUser.isNotEmpty) {
        final userIdTaken = existingUsernameUser.first['id'].toString();
        if (existingRoleUser == null || existingRoleUser.id != userIdTaken) {
          return 'Username "$username" sudah digunakan oleh akun lain.';
        }
      }

      if (existingRoleUser != null) {
        // Update
        await db.update(
          'users',
          {
            'username': username.trim(),
            'password': password,
          },
          where: 'id = ?',
          whereArgs: [existingRoleUser.id],
        );
      } else {
        // Create dummy
        final id = 'USR${DateTime.now().millisecondsSinceEpoch}';
        await db.insert('users', UserModel(
          id: id,
          nama: role == 'admin' ? 'Administrator' : 'Kasir',
          username: username.trim(),
          email: '${role}_${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: password,
          role: role,
        ).toMap());
      }
      return null;
    } catch (e) {
      debugPrint('Error create/update role $role: $e');
      return 'Terjadi kesalahan: $e';
    }
  }

  String _generateToken() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
