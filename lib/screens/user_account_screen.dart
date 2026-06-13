import 'package:flutter/material.dart';
import '../database/auth_repository.dart';

class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _kasirUsernameController = TextEditingController();
  final TextEditingController _kasirPasswordController = TextEditingController();
  
  bool _isLoading = true;
  bool _obscurePassword = true;
  bool _obscureKasirPassword = true;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final admin = await _authRepo.getFirstUserByRole('admin');
    final kasir = await _authRepo.getFirstUserByRole('kasir');
    
    if (mounted) {
      setState(() {
        _usernameController.text = admin?.username ?? '';
        _passwordController.text = admin?.password ?? '';
        
        _kasirUsernameController.text = kasir?.username ?? '';
        _kasirPasswordController.text = kasir?.password ?? '';
        
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final adminError = await _authRepo.createOrUpdateUserByRole(
        role: 'admin',
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (adminError != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error Admin: $adminError'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final kasirError = await _authRepo.createOrUpdateUserByRole(
        role: 'kasir',
        username: _kasirUsernameController.text,
        password: _kasirPasswordController.text,
      );

      if (kasirError != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error Kasir: $kasirError'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daftar akun berhasil diperbarui'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Akun'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kelola Akun Pengguna',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola akun Admin untuk akses penuh dan akun Kasir untuk akses terbatas.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Akun Admin (Full Access)'),
                  const SizedBox(height: 16),
                  _buildAccountFields(
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    userLabel: 'Admin',
                  ),
                  
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Akun Kasir (Limited Access)'),
                  const SizedBox(height: 16),
                  _buildAccountFields(
                    usernameController: _kasirUsernameController,
                    passwordController: _kasirPasswordController,
                    obscurePassword: _obscureKasirPassword,
                    onTogglePassword: () => setState(() => _obscureKasirPassword = !_obscureKasirPassword),
                    userLabel: 'Kasir',
                  ),
                  
                  const SizedBox(height: 48),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAccountFields({
    required TextEditingController usernameController,
    required TextEditingController passwordController,
    required bool obscurePassword,
    required VoidCallback onTogglePassword,
    required String userLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Username $userLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: usernameController,
          decoration: InputDecoration(
            hintText: userLabel.toLowerCase(),
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Username tidak boleh kosong';
            return null;
          },
        ),
        const SizedBox(height: 20),
        Text('Password $userLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            hintText: 'Password $userLabel',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
               icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: onTogglePassword,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
            return null;
          },
        ),
      ],
    );
  }
}
