import 'package:flutter/material.dart';
import '../database/meja_repository.dart';
import '../models/meja_model.dart';

class MejaScreen extends StatefulWidget {
  const MejaScreen({super.key});

  @override
  State<MejaScreen> createState() => _MejaScreenState();
}

class _MejaScreenState extends State<MejaScreen> {
  final MejaRepository _mejaRepo = MejaRepository();
  List<Meja> _mejas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeja();
  }

  Future<void> _loadMeja() async {
    setState(() => _isLoading = true);
    final data = await _mejaRepo.getAll();
    setState(() {
      _mejas = data;
      _isLoading = false;
    });
  }

  void _showAddEditDialog([Meja? meja]) {
    final isEdit = meja != null;
    final idController = TextEditingController(text: meja?.id ?? '');
    final namaController = TextEditingController(text: meja?.nama ?? '');
    final kategoriController = TextEditingController(text: meja?.kategori ?? 'Umum');
    bool isActive = meja?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Ubah Meja' : 'Tambah Meja Baru', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEdit)
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID Meja (Misal: 1, A1, VIP-1)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: namaController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Meja',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: kategoriController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori (Misal: Lantai 1, Outdoor)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (namaController.text.isEmpty) return;
                
                final newMeja = Meja(
                  id: isEdit ? meja.id : idController.text,
                  nama: namaController.text,
                  kategori: kategoriController.text,
                  isActive: isActive,
                );

                if (isEdit) {
                  await _mejaRepo.update(newMeja);
                } else {
                  if (idController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID tidak boleh kosong')));
                    return;
                  }
                  await _mejaRepo.insert(newMeja);
                }

                if (mounted) {
                  Navigator.pop(context);
                  _loadMeja();
                }
              },
              child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMeja(Meja meja) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Meja?'),
        content: Text('Apakah Anda yakin ingin menghapus ${meja.nama}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _mejaRepo.delete(meja.id);
      _loadMeja();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Manajemen Meja', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mejas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Belum ada data meja', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mejas.length,
                  itemBuilder: (context, index) {
                    final meja = _mejas[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: meja.isActive ? Colors.blue[50] : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.table_bar,
                            color: meja.isActive ? Colors.blue : Colors.grey,
                          ),
                        ),
                        title: Text(
                          meja.nama,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Kategori: ${meja.kategori ?? "-"}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: meja.isActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meja.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: meja.isActive ? Colors.green[700] : Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showAddEditDialog(meja),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteMeja(meja),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Meja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
