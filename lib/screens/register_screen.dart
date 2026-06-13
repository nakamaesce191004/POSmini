import 'package:flutter/material.dart';
import '../database/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoToLogin;

  const RegisterScreen({super.key, required this.onGoToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureKonfirmasi = true;
  String _errorMessage = '';
  String _successMessage = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _namaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    final error = await _authRepo.register(
      nama: _namaController.text,
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    } else {
      setState(() {
        _successMessage = 'Akun berhasil dibuat! Silakan login dengan username Anda.';
        _isLoading = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onGoToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.orange.withValues(alpha: 0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.deepOrange.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
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
                        child: Padding(
                          padding: const EdgeInsets.all(36),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Center(
                                  child: Text(
                                    'Buat Akun Baru',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    'Daftarkan diri Anda untuk mengakses aplikasi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Nama
                                _buildLabel('Nama Lengkap'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _namaController,
                                  hint: 'Masukkan nama lengkap',
                                  icon: Icons.badge_outlined,
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Nama tidak boleh kosong' : null,
                                ),
                                const SizedBox(height: 18),

                                // Username
                                _buildLabel('Username'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _usernameController,
                                  hint: 'Username untuk login',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) {
                                    if (v!.trim().isEmpty) {
                                      return 'Username tidak boleh kosong';
                                    }
                                    if (v.trim().length < 3) {
                                      return 'Username minimal 3 karakter';
                                    }
                                    if (v.trim().contains(' ')) {
                                      return 'Username tidak boleh mengandung spasi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Email
                                _buildLabel('Alamat Email'),
                                const SizedBox(height: 4),
                                Text(
                                  'Digunakan untuk reset password jika lupa',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _emailController,
                                  hint: 'contoh@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v!.trim().isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    final emailRegex =
                                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(v.trim())) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Password
                                _buildLabel('Password'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _passwordController,
                                  hint: 'Minimal 6 karakter',
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  obscure: _obscurePassword,
                                  onToggleObscure: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                  validator: (v) {
                                    if (v!.isEmpty) {
                                      return 'Password tidak boleh kosong';
                                    }
                                    if (v.length < 6) {
                                      return 'Password minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Konfirmasi Password
                                _buildLabel('Konfirmasi Password'),
                                const SizedBox(height: 8),
                                _buildField(
                                  controller: _konfirmasiController,
                                  hint: 'Ulangi password',
                                  icon: Icons.lock_reset_rounded,
                                  isPassword: true,
                                  obscure: _obscureKonfirmasi,
                                  onToggleObscure: () =>
                                      setState(() => _obscureKonfirmasi = !_obscureKonfirmasi),
                                  validator: (v) {
                                    if (v!.isEmpty) {
                                      return 'Konfirmasi password tidak boleh kosong';
                                    }
                                    if (v != _passwordController.text) {
                                      return 'Password tidak cocok';
                                    }
                                    return null;
                                  },
                                ),

                                if (_errorMessage.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildAlert(_errorMessage, Colors.red, Icons.error_outline),
                                ],
                                if (_successMessage.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildAlert(
                                      _successMessage, Colors.green, Icons.check_circle_outline),
                                ],

                                const SizedBox(height: 28),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF8C00),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Daftar Sekarang',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Sudah punya akun? ',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    GestureDetector(
                                      onTap: widget.onGoToLogin,
                                      child: const Text(
                                        'Masuk Sekarang',
                                        style: TextStyle(
                                          color: Color(0xFFFF8C00),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF444460),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFFFF8C00), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildAlert(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
