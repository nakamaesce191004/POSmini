import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as exc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/produk_repository.dart';
import '../models/produk_model.dart';
import '../database/db_helper.dart';

class DataManajemenScreen extends StatefulWidget {
  const DataManajemenScreen({super.key});

  @override
  State<DataManajemenScreen> createState() => _DataManajemenScreenState();
}

class _DataManajemenScreenState extends State<DataManajemenScreen> {
  final ProdukRepository _repo = ProdukRepository();
  bool _isLoading = false;

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      final allProduk = await _repo.getAll();
      var excel = exc.Excel.createExcel();
      exc.Sheet sheetObject = excel['Produk'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        exc.TextCellValue('ID'),
        exc.TextCellValue('Nama'),
        exc.TextCellValue('Kategori'),
        exc.TextCellValue('Harga Jual'),
        exc.TextCellValue('Harga Beli'),
        exc.TextCellValue('Stok'),
      ]);

      for (var p in allProduk) {
        sheetObject.appendRow([
          exc.TextCellValue(p.id ?? ''),
          exc.TextCellValue(p.nama),
          exc.TextCellValue(p.kategori),
          exc.IntCellValue(p.harga),
          exc.IntCellValue(p.hargaBeli),
          exc.IntCellValue(p.stok),
        ]);
      }

      final bytes = excel.save();
      if (bytes != null) {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          // Mode Download untuk Desktop: Menggunakan FilePicker untuk memilih lokasi simpan
          String? outputFile = await FilePicker.saveFile(
            dialogTitle: 'Simpan Data Produk',
            fileName: 'data_produk_${DateTime.now().millisecondsSinceEpoch}.xlsx',
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (outputFile != null) {
            // Pastikan ekstensi file benar
            if (!outputFile.toLowerCase().endsWith('.xlsx')) {
              outputFile += '.xlsx';
            }
            final file = File(outputFile);
            await file.writeAsBytes(bytes);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File berhasil di-download ke: $outputFile'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          // Mode Share untuk Mobile
          final directory = await getTemporaryDirectory();
          final filePath = "${directory.path}/data_produk_${DateTime.now().millisecondsSinceEpoch}.xlsx";
          final file = File(filePath);
          await file.create(recursive: true);
          await file.writeAsBytes(bytes);
          await Share.shareXFiles([XFile(filePath)], text: 'Export Data Produk');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _isLoading = true);

      final bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = exc.Excel.decodeBytes(bytes);
      int importCount = 0;

      final existingProduk = await _repo.getAll();

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        // Skip header
        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty || row.length < 2) continue;

          final id = row[0]?.value?.toString() ?? '';
          final nama = row[1]?.value?.toString() ?? '';
          final kategori = row[2]?.value?.toString() ?? '';
          final harga = int.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
          final hargaBeli = int.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
          final stok = int.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;

          if (nama.isEmpty) continue;

          final existingIndex = existingProduk.indexWhere((p) => p.id == id && id.isNotEmpty);
          
          final produk = Produk(
            id: id.isEmpty ? null : id,
            nama: nama,
            kategori: kategori,
            harga: harga,
            hargaBeli: hargaBeli,
            stok: stok,
            gambar: Icons.inventory_2,
          );

          if (existingIndex != -1) {
            await _repo.update(produk);
          } else {
            await _repo.insert(produk);
          }
          importCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor $importCount produk!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal impor: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      var excel = exc.Excel.createExcel();
      exc.Sheet sheetObject = excel['Produk'];
      excel.delete('Sheet1');

      // Headers
      sheetObject.appendRow([
        exc.TextCellValue('ID'),
        exc.TextCellValue('Nama'),
        exc.TextCellValue('Kategori'),
        exc.TextCellValue('Harga Jual'),
        exc.TextCellValue('Harga Beli'),
        exc.TextCellValue('Stok'),
      ]);

      // Sample Row (optional, good for guidance)
      sheetObject.appendRow([
        exc.TextCellValue(''),
        exc.TextCellValue('Contoh Produk'),
        exc.TextCellValue('Lainnya'),
        exc.IntCellValue(20000),
        exc.IntCellValue(15000),
        exc.IntCellValue(10),
      ]);

      final directory = await getTemporaryDirectory();
      final filePath = "${directory.path}/template_produk.xlsx";
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(filePath)], text: 'Template Import Produk');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat template: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Semua data produk, transaksi, dan riwayat akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus Semua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await DBHelper().clearAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database berhasil dikosongkan!'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal reset: $e'), backgroundColor: Colors.orange),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _hapusDataSelainProduk() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Hapus Data Selain Produk?',
          style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Semua transaksi, item transaksi, metode pembayaran, pelanggan, dan riwayat presensi akan dihapus. Data produk akan tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await DBHelper().clearNonProductData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data selain produk berhasil dihapus!'),
              backgroundColor: Colors.deepOrange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus data: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Manajemen Excel', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.green),
            onPressed: _downloadTemplate,
            tooltip: 'Download Template Excel',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  title: 'Export ke Excel',
                  description: 'Download semua data produk ke dalam file .xlsx yang bisa dibuka di Microsoft Excel atau Google Sheets.',
                  icon: Icons.upload_file,
                  color: Colors.green,
                  buttonLabel: 'Export Data Produk',
                  onPressed: _exportToExcel,
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Import dari Excel',
                  description: 'Unggah file Excel (.xlsx) untuk menambah atau memperbarui data produk secara massal.',
                  icon: Icons.download_for_offline,
                  color: Colors.blue,
                  buttonLabel: 'Pilih File Excel',
                  onPressed: _importFromExcel,
                ),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Hapus Data Selain Produk',
                  description: 'Bersihkan transaksi, pelanggan, metode pembayaran, dan riwayat presensi tanpa menghapus data produk.',
                  icon: Icons.cleaning_services_outlined,
                  color: Colors.deepOrange,
                  buttonLabel: 'Hapus Data Non-Produk',
                  onPressed: _hapusDataSelainProduk,
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Reset Database',
                  description: 'Hapus seluruh data di aplikasi secara permanen. Gunakan fitur ini jika ingin memulai dari awal.',
                  icon: Icons.delete_forever,
                  color: Colors.red,
                  buttonLabel: 'Hapus Semua Data Sekarang',
                  onPressed: _resetDatabase,
                ),
                const SizedBox(height: 40),
                _buildInfoSection(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[800], size: 22),
              const SizedBox(width: 12),
              Text(
                'Petunjuk Penting',
                style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('Gunakan header kolom: ID, Nama, Kategori, Harga Jual, Harga Beli, Stok.'),
          _buildInfoItem('Jika ID dikosongkan, data akan dianggap sebagai produk baru.'),
          _buildInfoItem('Jika ID diisi, sistem akan memperbarui produk yang sudah ada.'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(color: Colors.orange[900], fontSize: 13))),
        ],
      ),
    );
  }
}
