import 'package:flutter/material.dart';
import '../database/settings_repository.dart';

class GantiPinScreen extends StatefulWidget {
  const GantiPinScreen({super.key});

  @override
  State<GantiPinScreen> createState() => _GantiPinScreenState();
}

class _GantiPinScreenState extends State<GantiPinScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final _formKey = GlobalKey<FormState>();
  
  String _currentPinInput = '';
  String _newPinInput = '';
  String _confirmPinInput = '';
  
  bool _isLoading = false;

  Future<void> _updatePin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    
    try {
      final actualPin = await _settingsRepo.getPin();
      
      if (_currentPinInput != actualPin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN Lama Salah!'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (_newPinInput != _confirmPinInput) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konfirmasi PIN baru tidak cocok!'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (_newPinInput.length != 4) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN harus 4 digit!'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await _settingsRepo.updatePin(_newPinInput);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN Berhasil Diperbarui!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui PIN: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ganti PIN Keamanan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PIN saat ini diperlukan untuk verifikasi identitas Anda.', 
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),
                  
                  _buildPasswordField(
                    label: 'PIN Lama (4 Digit)',
                    onSaved: (val) => _currentPinInput = val!,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  _buildPasswordField(
                    label: 'PIN Baru (4 Digit)',
                    onSaved: (val) => _newPinInput = val!,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    label: 'Konfirmasi PIN Baru',
                    onSaved: (val) => _confirmPinInput = val!,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updatePin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Simpan Perubahan PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({required String label, required FormFieldSetter<String> onSaved}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      validator: (val) => val == null || val.isEmpty ? 'Jangan dikosongkan' : null,
      onSaved: onSaved,
    );
  }
}
