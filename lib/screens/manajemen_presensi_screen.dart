import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/karyawan_model.dart';
import '../database/karyawan_repository.dart';
import '../models/presensi_model.dart';
import '../database/presensi_repository.dart';
import '../widgets/app_image_view.dart';
import 'riwayat_presensi_screen.dart';

class ManajemenPresensiScreen extends StatefulWidget {
  const ManajemenPresensiScreen({super.key});

  @override
  State<ManajemenPresensiScreen> createState() => _ManajemenPresensiScreenState();
}

class _ManajemenPresensiScreenState extends State<ManajemenPresensiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Presensi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Data Karyawan'),
            Tab(text: 'Riwayat Presensi'),
            Tab(text: 'Laporan Kerja'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DataKaryawanTab(),
          RiwayatPresensiScreen(),
          _LaporanKerjaTab(),
        ],
      ),
    );
  }
}

class _DataKaryawanTab extends StatefulWidget {
  const _DataKaryawanTab();

  @override
  State<_DataKaryawanTab> createState() => _DataKaryawanTabState();
}

class _DataKaryawanTabState extends State<_DataKaryawanTab> {
  final KaryawanRepository _repo = KaryawanRepository();
  List<Karyawan> _karyawanList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getKaryawan();
    if (mounted) {
      setState(() {
        _karyawanList = data;
        _isLoading = false;
      });
    }
  }

  void _showFormDialog([Karyawan? karyawan]) {
    final nameController = TextEditingController(text: karyawan?.nama ?? '');
    final posisiController = TextEditingController(text: karyawan?.posisi ?? '');
    final teleponController = TextEditingController(text: karyawan?.telepon ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(karyawan == null ? 'Tambah Karyawan' : 'Edit Karyawan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Karyawan'),
            ),
            TextField(
              controller: posisiController,
              decoration: const InputDecoration(labelText: 'Posisi'),
            ),
            TextField(
              controller: teleponController,
              decoration: const InputDecoration(labelText: 'Telepon'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              final newKaryawan = Karyawan(
                id: karyawan?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                nama: nameController.text,
                posisi: posisiController.text,
                telepon: teleponController.text,
              );

              if (karyawan == null) {
                await _repo.insertKaryawan(newKaryawan);
              } else {
                await _repo.updateKaryawan(newKaryawan);
              }

              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteKaryawan(String id) async {
    await _repo.deleteKaryawan(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _karyawanList.isEmpty
          ? const Center(child: Text('Belum ada data karyawan'))
          : ListView.builder(
              itemCount: _karyawanList.length,
              itemBuilder: (context, index) {
                final k = _karyawanList[index];
                return ListTile(
                  title: Text(k.nama),
                  subtitle: Text(k.posisi ?? '-'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showFormDialog(k),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteKaryawan(k.id),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LaporanKerjaTab extends StatefulWidget {
  const _LaporanKerjaTab();

  @override
  State<_LaporanKerjaTab> createState() => _LaporanKerjaTabState();
}

class _LaporanKerjaTabState extends State<_LaporanKerjaTab> {
  final PresensiRepository _repo = PresensiRepository();
  List<Presensi> _presensiList = [];
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
        _presensiList = data;
        _isLoading = false;
      });
    }
  }

  Map<String, double> _calculateTotalHours() {
    Map<String, List<Presensi>> grouped = {};
    for (var p in _presensiList) {
      if (!grouped.containsKey(p.namaKaryawan)) {
        grouped[p.namaKaryawan] = [];
      }
      grouped[p.namaKaryawan]!.add(p);
    }

    Map<String, double> totalHours = {};
    grouped.forEach((nama, records) {
      records.sort((a, b) => a.waktu.compareTo(b.waktu));
      double hours = 0;
      DateTime? lastMasuk;

      for (var p in records) {
        if (p.status == 'Masuk') {
          lastMasuk = p.waktu;
        } else if (p.status == 'Pulang' && lastMasuk != null) {
          final diff = p.waktu.difference(lastMasuk);
          hours += diff.inMinutes / 60.0;
          lastMasuk = null;
        }
      }
      totalHours[nama] = hours;
    });

    return totalHours;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final totalHours = _calculateTotalHours();
    if (totalHours.isEmpty) {
      return const Center(child: Text('Belum ada data laporan'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: totalHours.entries.map((e) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(e.key),
            trailing: Text(
              '${e.value.toStringAsFixed(2)} Jam',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      }).toList(),
    );
  }
}
