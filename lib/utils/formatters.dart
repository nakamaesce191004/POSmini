import 'package:flutter/services.dart';

/// Memformat angka ke format Rupiah dengan pemisah titik
/// Contoh: 10000 -> 10.000
String formatRupiah(num value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.'
  );
}

class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Hapus semua karakter selain angka
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');

    final int numValue = int.parse(text);
    final String formatted = formatRupiah(numValue);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
