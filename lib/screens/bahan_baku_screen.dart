import 'package:flutter/material.dart';
import '../database/resep_repository.dart';
import '../models/resep_model.dart';
import '../utils/formatters.dart';

class BahanBakuScreen extends StatefulWidget {
  const BahanBakuScreen({super.key});

  @override
  State<BahanBakuScreen> createState() => _BahanBakuScreenState();
}

class _BahanBakuScreenState extends State<BahanBakuScreen> {
  final ResepRepository _repo = ResepRepository();
  List<BahanBaku> _allBahan = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBahan();
  }

  Future<void> _loadBahan() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAllBahan();
    setState(() {
      _allBahan = data;
      _isLoading = false;
    });
  }

  void _showForm([BahanBaku? bahan]) {
    final namaController = TextEditingController(text: bahan?.nama);
    final belanjaController = TextEditingController(text: bahan?.totalBelanja.toString());
    final bahanController = TextEditingController(text: bahan?.totalBahan.toString());
    String selectedSatuan = bahan?.satuan ?? 'gram';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(bahan == null ? 'Tambah Bahan Baku' : 'Edit Bahan Baku'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaController,
                  decoration: const InputDecoration(labelText: 'Nama Bahan (e.g. Kopi Arabica)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: belanjaController,
                  decoration: const InputDecoration(labelText: 'Total Belanja (Harga Beli)', prefixText: 'Rp '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bahanController,
                        decoration: const InputDecoration(labelText: 'Total Isi/Berat'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSatuan,
                        items: ['gram', 'ml', 'pcs', 'kg', 'liter'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setDialogState(() => selectedSatuan = val!),
                        decoration: const InputDecoration(labelText: 'Satuan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final belanja = int.tryParse(belanjaController.text) ?? 0;
                final total = double.tryParse(bahanController.text) ?? 0;
                if (namaController.text.isEmpty || belanja <= 0 || total <= 0) return;

                final newBahan = BahanBaku(
                  id: bahan?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  nama: namaController.text,
                  totalBelanja: belanja,
                  totalBahan: total,
                  satuan: selectedSatuan,
                  hargaPerSatuan: belanja / total,
                );

                await _repo.insertBahan(newBahan);
                Navigator.pop(context);
                _loadBahan();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Bahan Baku')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allBahan.isEmpty
              ? const Center(child: Text('Belum ada data bahan baku'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allBahan.length,
                  itemBuilder: (context, index) {
                    final b = _allBahan[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(b.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Rp ${formatRupiah(b.totalBelanja)} / ${b.totalBahan} ${b.satuan}\nCost: Rp ${b.hargaPerSatuan.toStringAsFixed(2)} / ${b.satuan}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(b)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hapus Bahan?'),
                                    content: const Text('Bahan ini akan dihapus permanen.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _repo.deleteBahan(b.id!);
                                  _loadBahan();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
