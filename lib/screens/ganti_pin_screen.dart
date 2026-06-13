import 'package:flutter/material.dart';
import '../database/settings_repository.dart';

class GantiPinScreen extends StatefulWidget {
  const GantiPinScreen({super.key});

  @override
  State<GantiPinScreen> createState() => _GantiPinScreenState();
}

class _GantiPinScreenState extends State<GantiPinScreen> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final SettingsRepository _settingsRepo = SettingsRepository();
  bool _isLoading = false;

  Future<void> _updatePin() async {
    if (_newPinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN baru harus 4 digit')),
      );
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi PIN tidak cocok')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final currentPin = await _settingsRepo.getPin();

    if (_oldPinController.text != currentPin) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN lama salah')),
      );
      return;
    }

    await _settingsRepo.updatePin(_newPinController.text);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN berhasil diperbarui'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti PIN Keamanan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            TextField(
              controller: _oldPinController,
              decoration: const InputDecoration(labelText: 'PIN Lama', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPinController,
              decoration: const InputDecoration(labelText: 'PIN Baru', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              decoration: const InputDecoration(labelText: 'Konfirmasi PIN Baru', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePin,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan PIN Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
