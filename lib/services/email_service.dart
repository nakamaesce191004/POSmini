import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmtpConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool ssl;

  SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.ssl = true,
  });

  bool get isConfigured =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// Preset untuk Gmail
  static SmtpConfig gmail(String email, String appPassword) => SmtpConfig(
        host: 'smtp.gmail.com',
        port: 465,
        username: email,
        password: appPassword,
        ssl: true,
      );
}

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  static const String _keySmtpHost = 'smtp_host';
  static const String _keySmtpPort = 'smtp_port';
  static const String _keySmtpUsername = 'smtp_username';
  static const String _keySmtpPassword = 'smtp_password';
  static const String _keySmtpSsl = 'smtp_ssl';

  /// Simpan konfigurasi SMTP
  Future<void> saveConfig(SmtpConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySmtpHost, config.host);
    await prefs.setInt(_keySmtpPort, config.port);
    await prefs.setString(_keySmtpUsername, config.username);
    await prefs.setString(_keySmtpPassword, config.password);
    await prefs.setBool(_keySmtpSsl, config.ssl);
  }

  /// Load konfigurasi SMTP
  Future<SmtpConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return SmtpConfig(
      host: prefs.getString(_keySmtpHost) ?? '',
      port: prefs.getInt(_keySmtpPort) ?? 465,
      username: prefs.getString(_keySmtpUsername) ?? '',
      password: prefs.getString(_keySmtpPassword) ?? '',
      ssl: prefs.getBool(_keySmtpSsl) ?? true,
    );
  }

  /// Cek apakah SMTP sudah dikonfigurasi
  Future<bool> isConfigured() async {
    final config = await loadConfig();
    return config.isConfigured;
  }

  /// Kirim email OTP
  /// Returns null jika sukses, error message jika gagal
  Future<String?> sendOtpEmail({
    required String toEmail,
    required String toName,
    required String otpCode,
  }) async {
    try {
      final config = await loadConfig();
      if (!config.isConfigured) {
        return 'SMTP belum dikonfigurasi. Silakan atur di Pengaturan > Email SMTP.';
      }

      final smtpServer = SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: config.ssl,
        allowInsecure: !config.ssl,
      );

      final message = Message()
        ..from = Address(config.username, 'POS Mini App')
        ..recipients.add(toEmail)
        ..subject = 'Kode Verifikasi Reset Password'
        ..html = _buildOtpEmailHtml(toName, otpCode);

      await send(message, smtpServer);
      debugPrint('[EmailService] OTP berhasil dikirim ke $toEmail');
      return null; // sukses
    } catch (e) {
      debugPrint('[EmailService] Error mengirim email: $e');
      if (e.toString().contains('Authentication')) {
        return 'Gagal autentikasi SMTP. Periksa username/password email Anda di Pengaturan.';
      }
      if (e.toString().contains('Connection')) {
        return 'Gagal koneksi ke server SMTP. Periksa koneksi internet dan konfigurasi SMTP.';
      }
      return 'Gagal mengirim email: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e}';
    }
  }

  /// Test koneksi SMTP
  Future<String?> testConnection() async {
    try {
      final config = await loadConfig();
      if (!config.isConfigured) {
        return 'SMTP belum dikonfigurasi.';
      }

      final smtpServer = SmtpServer(
        config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        ssl: config.ssl,
        allowInsecure: !config.ssl,
      );

      final message = Message()
        ..from = Address(config.username, 'POS Mini App')
        ..recipients.add(config.username)
        ..subject = 'Test Koneksi SMTP - POS Mini'
        ..text = 'Ini adalah email test. Konfigurasi SMTP Anda berhasil!';

      await send(message, smtpServer);
      return null; // sukses
    } catch (e) {
      debugPrint('[EmailService] Test connection error: $e');
      return 'Gagal: $e';
    }
  }

  String _buildOtpEmailHtml(String nama, String otpCode) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #f5f7fa; padding: 20px;">
  <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08);">
    <div style="background: linear-gradient(135deg, #FF8C00, #FF5722); padding: 32px; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 24px;">🔐 Reset Password</h1>
      <p style="color: rgba(255,255,255,0.85); margin: 8px 0 0; font-size: 14px;">POS Mini App</p>
    </div>
    <div style="padding: 32px;">
      <p style="color: #333; font-size: 16px;">Halo <strong>$nama</strong>,</p>
      <p style="color: #666; font-size: 14px; line-height: 1.6;">
        Anda telah meminta reset password. Gunakan kode verifikasi berikut untuk mengatur password baru:
      </p>
      <div style="background: #f0f9ff; border: 2px dashed #3B82F6; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
        <p style="margin: 0 0 8px; color: #666; font-size: 13px;">Kode Verifikasi Anda:</p>
        <h2 style="margin: 0; font-size: 40px; letter-spacing: 12px; color: #1E40AF; font-family: 'Courier New', monospace;">$otpCode</h2>
      </div>
      <p style="color: #999; font-size: 13px; line-height: 1.5;">
        ⏱️ Kode ini berlaku selama <strong>15 menit</strong>.<br>
        Jika Anda tidak meminta reset password, abaikan email ini.
      </p>
    </div>
    <div style="background: #f9fafb; padding: 16px; text-align: center; border-top: 1px solid #eee;">
      <p style="margin: 0; color: #aaa; font-size: 12px;">© POS Mini App · Email otomatis, jangan dibalas</p>
    </div>
  </div>
</body>
</html>
''';
  }
}
