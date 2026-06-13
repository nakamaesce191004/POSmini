import 'package:flutter/material.dart';
import '../database/settings_repository.dart';

class PinVerifyScreen extends StatefulWidget {
  final VoidCallback onVerifySuccess;
  final VoidCallback? onBack;

  const PinVerifyScreen({super.key, required this.onVerifySuccess, this.onBack});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final TextEditingController _pinController = TextEditingController();
  final SettingsRepository _settingsRepo = SettingsRepository();
  String _errorMessage = '';
  String _correctPin = '1234';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await _settingsRepo.getPin();
    if (mounted) {
      setState(() {
        _correctPin = pin;
        _isLoading = false;
      });
    }
  }

  void _handlePinInput(String val) {
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += val;
        _errorMessage = '';
      });
    }

    if (_pinController.text.length == 4) {
      _verifyPin();
    }
  }

  void _verifyPin() {
    if (_pinController.text == _correctPin) {
      widget.onVerifySuccess();
    } else {
      setState(() {
        _errorMessage = 'PIN Salah! Silakan coba lagi.';
        _pinController.clear();
      });
    }
  }

  void _deleteLast() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.security_rounded, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Verifikasi Keamanan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan PIN untuk mengakses menu ini',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // PIN Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = _pinController.text.length > index;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.orange : Colors.grey[300],
                        border: Border.all(color: isFilled ? Colors.orange : Colors.grey[400]!),
                      ),
                    );
                  }),
                ),
                
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                ],

                const Spacer(),

                // Numpad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Column(
                    children: [
                      _buildRow(['1', '2', '3']),
                      _buildRow(['4', '5', '6']),
                      _buildRow(['7', '8', '9']),
                      _buildRow([null, '0', 'delete']),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Back Button
          if (widget.onBack != null)
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: widget.onBack,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String?> labels) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: labels.map((label) {
          if (label == null) return const SizedBox(width: 70);
          if (label == 'delete') {
            return _buildNumpadButton(
              icon: Icons.backspace_outlined,
              onTap: _deleteLast,
            );
          }
          return _buildNumpadButton(
            label: label,
            onTap: () => _handlePinInput(label),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumpadButton({String? label, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: label != null
              ? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
              : Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}
