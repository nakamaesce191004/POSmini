import 'package:flutter/material.dart';
import '../database/presensi_repository.dart';
import '../models/presensi_model.dart';
import 'package:intl/intl.dart';
import '../widgets/app_image_view.dart';

class RiwayatPresensiScreen extends StatefulWidget {
  const RiwayatPresensiScreen({super.key});

  @override
  State<RiwayatPresensiScreen> createState() => _RiwayatPresensiScreenState();
}

class _RiwayatPresensiScreenState extends State<RiwayatPresensiScreen> {
  final PresensiRepository _repo = PresensiRepository();
  List<Presensi> _allPresensi = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAll();
    if (mounted) {
      setState(() {
        _allPresensi = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat?'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan presensi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.delete(int.parse(id));
      _loadData();
    }
  }

  Future<void> _resetAll() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Riwayat?'),
        content: const Text('Semua data riwayat presensi akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Reset Semua', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.clearAll();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Riwayat Presensi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_allPresensi.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'Hapus Semua Riwayat',
              onPressed: _resetAll,
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _allPresensi.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Belum ada riwayat presensi', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allPresensi.length,
              itemBuilder: (context, index) {
                final item = _allPresensi[index];
                final DateTime waktu = item.waktu;
                final String formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(waktu);
                final bool isMasuk = item.status == 'Masuk';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppImageView(
                          path: item.fotoPath ?? '',
                          fit: BoxFit.cover,
                          errorWidget: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(
                      item.namaKaryawan,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMasuk ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isMasuk ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.fullscreen, color: Colors.orange),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppImageView(path: item.fotoPath ?? ''),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('Presensi ${item.status} - $formattedTime'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteItem(item.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
