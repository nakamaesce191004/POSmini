import 'package:flutter/material.dart';
import '../database/auth_repository.dart';
import '../services/email_service.dart';

enum ForgotPasswordStep { inputEmail, inputToken, inputNewPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onGoToLogin;

  const ForgotPasswordScreen({super.key, required this.onGoToLogin});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final AuthRepository _authRepo = AuthRepository();
  final EmailService _emailService = EmailService();

  ForgotPasswordStep _step = ForgotPasswordStep.inputEmail;

  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPassController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  String _userNama = '';
  String _userEmail = '';

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureKonfirmasi = true;
  String _errorMessage = '';
  String _infoMessage = '';
  bool _emailSent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _newPassController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  void _goToStep(ForgotPasswordStep step) {
    setState(() {
      _step = step;
      _errorMessage = '';
      _infoMessage = '';
    });
    _animController.forward(from: 0);
  }

  // Step 1: Request reset token & kirim OTP ke email
  Future<void> _handleRequestReset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Masukkan alamat email Anda.');
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _errorMessage = 'Format email tidak valid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Generate token di database
    final result = await _authRepo.requestPasswordReset(_emailController.text);

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'] as String;
      });
      return;
    }

    final token = result['token'] as String;
    _userNama = result['nama'] as String;
    _userEmail = result['email'] as String;

    // Kirim OTP via email
    final emailError = await _emailService.sendOtpEmail(
      toEmail: _userEmail,
      toName: _userNama,
      otpCode: token,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (emailError != null) {
      // Email gagal kirim — tetap lanjut tapi kasih warning
      setState(() {
        _emailSent = false;
        _infoMessage =
            '⚠️ Email gagal dikirim: $emailError\n\nAnda masih bisa menggunakan kode di bawah ini.';
      });
    } else {
      setState(() {
        _emailSent = true;
        _infoMessage =
            'Kode verifikasi 6 digit telah dikirim ke ${_maskEmail(_userEmail)}.\nSilakan cek inbox email Anda.';
      });
    }

    _goToStep(ForgotPasswordStep.inputToken);
  }

  // Step 2: Verify token
  Future<void> _handleVerifyToken() async {
    if (_tokenController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Kode verifikasi harus 6 digit.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final user = await _authRepo.getUserByEmail(_userEmail);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      setState(() => _errorMessage = 'Terjadi kesalahan. Coba ulangi.');
      return;
    }

    if (user.resetToken != _tokenController.text.trim()) {
      setState(() => _errorMessage = 'Kode verifikasi salah. Periksa kembali.');
      return;
    }

    if (user.resetTokenExpiry != null) {
      final expiry = DateTime.parse(user.resetTokenExpiry!);
      if (DateTime.now().isAfter(expiry)) {
        setState(() =>
            _errorMessage = 'Kode verifikasi sudah kedaluwarsa. Minta ulang kode baru.');
        return;
      }
    }

    _goToStep(ForgotPasswordStep.inputNewPassword);
  }

  // Step 3: Set new password
  Future<void> _handleResetPassword() async {
    if (_newPassController.text.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }
    if (_newPassController.text != _konfirmasiController.text) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final error = await _authRepo.resetPassword(
      email: _userEmail,
      token: _tokenController.text.trim(),
      newPassword: _newPassController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      _goToStep(ForgotPasswordStep.done);
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${name[1]}***@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.blue.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.orange.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              onPressed: widget.onGoToLogin,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(36),
                      child: _buildCurrentStep(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case ForgotPasswordStep.inputEmail:
        return _buildEmailStep();
      case ForgotPasswordStep.inputToken:
        return _buildTokenStep();
      case ForgotPasswordStep.inputNewPassword:
        return _buildNewPasswordStep();
      case ForgotPasswordStep.done:
        return _buildDoneStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _stepIcon(Icons.mark_email_read_rounded, Colors.blue)),
        const SizedBox(height: 24),
        const Center(
          child: Text('Lupa Password',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Masukkan email yang terdaftar di akun Anda.\nKami akan mengirimkan kode OTP ke email tersebut.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel('Alamat Email'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 15),
          decoration: _inputDecoration('email@anda.com', Icons.email_outlined),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAlert(_errorMessage, Colors.red, Icons.error_outline),
        ],
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label: 'Kirim Kode OTP',
          icon: Icons.send_rounded,
          onTap: _handleRequestReset,
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: widget.onGoToLogin,
            child: const Text('Kembali ke Login',
                style: TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _stepIcon(Icons.verified_user_rounded, Colors.teal)),
        const SizedBox(height: 24),
        const Center(
          child: Text('Verifikasi Kode OTP',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        if (_infoMessage.isNotEmpty)
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _emailSent
                    ? const Color(0xFFF0FFF4)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _emailSent
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _emailSent ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    color: _emailSent ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _infoMessage,
                      style: TextStyle(
                        color: _emailSent ? Colors.green[800] : Colors.orange[800],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Jika email gagal, tampilkan kode manual
        if (!_emailSent) ...[
          FutureBuilder<UserModel?>(
            future: _authRepo.getUserByEmail(_userEmail),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
              final token = snapshot.data!.resetToken ?? '';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Kode Verifikasi (Backup):',
                            style: TextStyle(
                                fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      token,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F),
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SMTP belum dikonfigurasi. Kode ditampilkan langsung.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        _buildLabel('Masukkan Kode 6 Digit'),
        const SizedBox(height: 8),
        TextField(
          controller: _tokenController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: _inputDecoration('000000', Icons.pin_rounded).copyWith(counterText: ''),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAlert(_errorMessage, Colors.red, Icons.error_outline),
        ],
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label: 'Verifikasi Kode',
          icon: Icons.verified_rounded,
          onTap: _handleVerifyToken,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => _goToStep(ForgotPasswordStep.inputEmail),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Minta Kode Baru'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _stepIcon(Icons.lock_reset_rounded, Colors.orange)),
        const SizedBox(height: 24),
        const Center(
          child: Text('Password Baru',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Buat password baru yang kuat untuk akun Anda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ),
        const SizedBox(height: 32),
        _buildLabel('Password Baru'),
        const SizedBox(height: 8),
        TextField(
          controller: _newPassController,
          obscureText: _obscurePass,
          decoration:
              _inputDecoration('Minimal 6 karakter', Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('Konfirmasi Password Baru'),
        const SizedBox(height: 8),
        TextField(
          controller: _konfirmasiController,
          obscureText: _obscureKonfirmasi,
          decoration: _inputDecoration('Ulangi password', Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKonfirmasi ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => setState(() => _obscureKonfirmasi = !_obscureKonfirmasi),
            ),
          ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAlert(_errorMessage, Colors.red, Icons.error_outline),
        ],
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Simpan Password Baru',
          icon: Icons.save_rounded,
          onTap: _handleResetPassword,
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(child: _stepIcon(Icons.check_circle_rounded, Colors.green)),
        const SizedBox(height: 24),
        const Center(
          child: Text('Password Berhasil Diubah!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ),
        const SizedBox(height: 12),
        Text(
          'Password akun Anda telah berhasil diperbarui. Silakan login dengan password baru.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: widget.onGoToLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Login Sekarang',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 36, color: Colors.white),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF444460)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFFFF8C00), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
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
        borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
      ),
    );
  }

  Widget _buildAlert(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onTap,
        icon: _isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Icon(icon, size: 20),
        label: _isLoading
            ? const Text('Memproses...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8C00),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
