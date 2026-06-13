import 'package:flutter/material.dart';
import '../services/email_service.dart';

class SmtpSettingsScreen extends StatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  State<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends State<SmtpSettingsScreen> {
  final EmailService _emailService = EmailService();
  final _formKey = GlobalKey<FormState>();

  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _ssl = true;
  bool _isLoading = true;
  bool _obscurePassword = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _emailService.loadConfig();
    if (mounted) {
      setState(() {
        _hostController.text = config.host;
        _portController.text = config.port.toString();
        _usernameController.text = config.username;
        _passwordController.text = config.password;
        _ssl = config.ssl;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await _emailService.saveConfig(SmtpConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? 465,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      ssl: _ssl,
    ));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfigurasi SMTP berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);

    // Simpan dulu sebelum test
    await _emailService.saveConfig(SmtpConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? 465,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      ssl: _ssl,
    ));

    final error = await _emailService.testConnection();

    if (!mounted) return;
    setState(() => _isTesting = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              error == null ? Icons.check_circle : Icons.error,
              color: error == null ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Text(error == null ? 'Berhasil!' : 'Gagal'),
          ],
        ),
        content: Text(
          error == null
              ? 'Koneksi SMTP berhasil! Email test telah dikirim ke ${_usernameController.text}.'
              : 'Gagal menghubungi server SMTP:\n\n$error',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _applyGmailPreset() {
    setState(() {
      _hostController.text = 'smtp.gmail.com';
      _portController.text = '465';
      _ssl = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preset Gmail diterapkan. Masukkan email & App Password.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Email SMTP',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Konfigurasi SMTP digunakan untuk mengirim kode OTP ke email saat reset password. '
                              'Untuk Gmail, gunakan App Password (bukan password biasa).',
                              style: TextStyle(
                                  color: Colors.blue[800], fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick preset
                    Row(
                      children: [
                        const Text('Preset Cepat:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(width: 12),
                        ActionChip(
                          avatar: const Icon(Icons.email, size: 16),
                          label: const Text('Gmail'),
                          onPressed: _applyGmailPreset,
                          backgroundColor: Colors.red.withValues(alpha: 0.08),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // SMTP Host
                    _buildLabel('SMTP Host'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _hostController,
                      decoration: _inputDecoration('smtp.gmail.com', Icons.dns_outlined),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Host tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 20),

                    // Port
                    _buildLabel('Port'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('465', Icons.numbers),
                      validator: (v) => v!.trim().isEmpty ? 'Port tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 20),

                    // SSL
                    SwitchListTile(
                      title: const Text('Gunakan SSL', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Port 465 biasanya SSL, port 587 biasanya TLS',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      value: _ssl,
                      onChanged: (v) => setState(() => _ssl = v),
                      activeTrackColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 32),

                    // Email
                    _buildLabel('Email / Username SMTP'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('email@gmail.com', Icons.person_outline),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Email tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 20),

                    // Password
                    _buildLabel('Password / App Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration('App Password', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Password tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 36),

                    // Test Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.speed_rounded, size: 20),
                        label: Text(
                          _isTesting ? 'Menguji...' : 'Test Koneksi',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _saveConfig,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Simpan Konfigurasi',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Help section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('Cara Setup Gmail',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Buka Google Account → Security\n'
                            '2. Aktifkan 2-Step Verification\n'
                            '3. Buat App Password (search "App passwords")\n'
                            '4. Pilih "Other" → beri nama "POS Mini"\n'
                            '5. Salin 16-digit password yang muncul\n'
                            '6. Masukkan email Gmail & App Password di atas',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 13, height: 1.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF444460)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.orange, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}
