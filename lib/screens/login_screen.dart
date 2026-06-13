import 'package:flutter/material.dart';
import '../database/auth_repository.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum AuthView { login, register, forgotPassword }

class LoginScreen extends StatefulWidget {
  final Function(String role) onLoginSuccess;
  final VoidCallback? onBack;

  const LoginScreen({super.key, required this.onLoginSuccess, this.onBack});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  AuthView _currentView = AuthView.login;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthRepository _authRepo = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchView(AuthView view) {
    setState(() {
      _currentView = view;
      _errorMessage = '';
    });
    _animController.forward(from: 0);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final user = await _authRepo.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (user != null) {
      widget.onLoginSuccess(user.role);
    } else {
      setState(() {
        _errorMessage = 'Username atau password salah. Periksa kembali dan coba lagi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentView == AuthView.register) {
      return RegisterScreen(
        onGoToLogin: () => _switchView(AuthView.login),
      );
    }
    if (_currentView == AuthView.forgotPassword) {
      return ForgotPasswordScreen(
        onGoToLogin: () => _switchView(AuthView.login),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.orange.withValues(alpha: 0.16),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.deepOrange.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
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
                              color: Colors.black.withValues(alpha: 0.09),
                              blurRadius: 48,
                              offset: const Offset(0, 20),
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
                                // Logo
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF8C00),
                                          Color(0xFFFF5722),
                                        ],
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
                                      Icons.storefront_rounded,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Center(
                                  child: Text(
                                    'Selamat Datang',
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
                                    'Masuk ke akun Anda untuk melanjutkan',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 36),

                                // Username
                                _buildLabel('Username'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
                                  decoration: _inputDecoration(
                                      'Masukkan username', Icons.person_outline_rounded),
                                  validator: (v) {
                                    if (v!.trim().isEmpty) {
                                      return 'Username tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Password
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildLabel('Password'),
                                    GestureDetector(
                                      onTap: () => _switchView(AuthView.forgotPassword),
                                      child: const Text(
                                        'Lupa password?',
                                        style: TextStyle(
                                          color: Color(0xFFFF8C00),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
                                  decoration: _inputDecoration(
                                    'Masukkan password',
                                    Icons.lock_outline_rounded,
                                  ).copyWith(
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

                                // Error
                                if (_errorMessage.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
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
                                            'Masuk ke Aplikasi',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Divider
                                Row(children: [
                                  Expanded(child: Divider(color: Colors.grey[200])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('atau',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[200])),
                                ]),
                                const SizedBox(height: 24),

                                // Register Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _switchView(AuthView.register),
                                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                    label: const Text(
                                      'Buat Akun Baru',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF8C00),
                                      side: const BorderSide(color: Color(0xFFFF8C00), width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),

                                if (widget.onBack != null) ...[
                                  const SizedBox(height: 16),
                                  Center(
                                    child: TextButton(
                                      onPressed: widget.onBack,
                                      child: Text('Kembali', style: TextStyle(color: Colors.grey[500])),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('POS Mini © 2025 · Versi 1.0',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (widget.onBack != null)
            Positioned(
              top: 48,
              left: 16,
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  elevation: 4,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
