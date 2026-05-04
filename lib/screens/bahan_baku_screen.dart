import 'package:flutter/material.dart';
import '../database/resep_repository.dart';
import '../database/transaksi_repository.dart';
import '../models/resep_model.dart';
import '../models/transaksi_model.dart';
import '../utils/formatters.dart';

class BahanBakuScreen extends StatefulWidget {
  const BahanBakuScreen({super.key});

  @override
  State<BahanBakuScreen> createState() => _BahanBakuScreenState();
}

class _BahanBakuScreenState extends State<BahanBakuScreen> {
  final ResepRepository _repo = ResepRepository();
  final TransaksiRepository _trxRepo = TransaksiRepository();
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
    final belanjaController = TextEditingController(text: bahan != null ? formatRupiah(bahan.totalBelanja) : '');
    final bahanController = TextEditingController(text: bahan?.totalBahan.toString());
    final stokMinimalController = TextEditingController(text: bahan?.stokMinimal.toString() ?? '0');
    final supplierController = TextEditingController(text: bahan?.supplier ?? '');
    String selectedSatuan = bahan?.satuan ?? 'gram';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                bahan == null ? 'Tambah Bahan Baku' : 'Edit Bahan Baku',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Bahan',
                  hintText: 'e.g. Kopi Arabica',
                  prefixIcon: const Icon(Icons.egg_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: belanjaController,
                inputFormatters: [RibuanInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Total Belanja (Harga Beli)',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bahanController,
                      decoration: InputDecoration(
                        labelText: 'Total Isi/Berat',
                        prefixIcon: const Icon(Icons.scale_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedSatuan,
                      items: ['gram', 'ml', 'pcs', 'kg', 'liter']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedSatuan = val!),
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stokMinimalController,
                decoration: InputDecoration(
                  labelText: 'Stok Minimal (Notifikasi)',
                  hintText: 'Beri peringatan jika stok di bawah...',
                  prefixIcon: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: supplierController,
                decoration: InputDecoration(
                  labelText: 'Nama Supplier',
                  hintText: 'e.g. PT. Sumber Makmur',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final belanjaText = belanjaController.text.replaceAll('.', '');
                    final totalText = bahanController.text.replaceAll(',', '.');
                    final minStokText = stokMinimalController.text.replaceAll(',', '.');

                    final belanja = int.tryParse(belanjaText) ?? 0;
                    final total = double.tryParse(totalText) ?? 0;
                    final minStok = double.tryParse(minStokText) ?? 0;

                    if (namaController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama bahan tidak boleh kosong')),
                      );
                      return;
                    }
                    if (belanja <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Harga belanja harus lebih dari 0')),
                      );
                      return;
                    }
                    if (total <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Total isi/berat harus lebih dari 0')),
                      );
                      return;
                    }

                    try {
                      final newBahan = BahanBaku(
                        id: bahan?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        nama: namaController.text,
                        totalBelanja: belanja,
                        totalBahan: total,
                        satuan: selectedSatuan,
                        hargaPerSatuan: belanja / total,
                        stokMinimal: minStok,
                        supplier: supplierController.text.isEmpty ? null : supplierController.text,
                      );

                      await _repo.insertBahan(newBahan);

                      // OTOMATIS: Catat sebagai Pengeluaran HANYA jika ini adalah bahan BARU
                      if (bahan == null) {
                        final newTrx = Transaksi(
                          id: 'PURCH-${newBahan.id}',
                          jenis: 'pengeluaran',
                          nominal: newBahan.totalBelanja,
                          tanggal: DateTime.now(),
                          deskripsi: 'Pembelian Bahan: ${newBahan.nama} (${newBahan.totalBahan.toStringAsFixed(0)} ${newBahan.satuan})',
                          pelanggan: supplierController.text.isEmpty ? 'Supplier' : supplierController.text,
                          metode: 'Tunai',
                          items: [],
                        );
                        await _trxRepo.insert(newTrx);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  bahan == null ? 'Bahan baku berhasil ditambahkan' : 'Perubahan berhasil disimpan',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green[700],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                        _loadBahan();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal menyimpan: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    bahan == null ? 'Tambah Bahan' : 'Simpan Perubahan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Purchasing ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allBahan.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada data bahan baku',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Bahan Pertama'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allBahan.length,
                  itemBuilder: (context, index) {
                    final b = _allBahan[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showForm(b),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.egg_outlined, color: Colors.orange[700]),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                b.nama,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              // SISA STOK
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: b.totalBahan <= 0 
                                                      ? Colors.red[50] 
                                                      : (b.totalBahan <= b.stokMinimal ? Colors.orange[50] : Colors.green[50]),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: b.totalBahan <= 0 
                                                        ? Colors.red 
                                                        : (b.totalBahan <= b.stokMinimal ? Colors.orange : Colors.green),
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      'Sisa Stok',
                                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                                    ),
                                                    Text(
                                                      '${b.totalBahan.toStringAsFixed(0)} ${b.satuan}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: b.totalBahan <= 0 
                                                            ? Colors.red[900] 
                                                            : (b.totalBahan <= b.stokMinimal ? Colors.orange[900] : Colors.green[900]),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (b.totalBahan <= b.stokMinimal)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        b.totalBahan <= 0 ? 'Stok Habis!' : 'Stok Menipis!',
                                                        style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  _infoBadge(Icons.money, 'Rp ${formatRupiah(b.totalBelanja)}'),
                                                  const SizedBox(width: 8),
                                                  _infoBadge(Icons.sell_outlined, 'HPP: Rp ${formatRupiah(b.hargaPerSatuan.round())}/${b.satuan}'),
                                                  if (b.supplier != null && b.supplier!.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    _infoBadge(Icons.business_outlined, b.supplier!),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Tombol Restock Cepat
                                        IconButton(
                                          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                                          onPressed: () => _showRestockDialog(b),
                                          tooltip: 'Tambah Stok (Restock)',
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Hapus Bahan?'),
                                          content: Text('Apakah Anda yakin ingin menghapus "${b.nama}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _repo.deleteBahan(b.id!);
                                        // OTOMATIS: Hapus juga dari catatan transaksi pengeluaran
                                        await _trxRepo.delete('PURCH-${b.id}');
                                        _loadBahan();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
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
  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _showRestockDialog(BahanBaku b) {
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final supplierController = TextEditingController(text: b.supplier ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock: ${b.nama}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: 'Jumlah Tambah (${b.satuan})',
                hintText: 'Contoh: 1000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Total Biaya Beli (Rp)',
                prefixText: 'Rp ',
                hintText: 'Contoh: 50.000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: supplierController,
              decoration: InputDecoration(
                labelText: 'Nama Supplier',
                hintText: 'e.g. PT. Sumber Makmur',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final double addQty = double.tryParse(qtyController.text) ?? 0;
              final int addPrice = int.tryParse(priceController.text.replaceAll('.', '')) ?? 0;

              if (addQty > 0) {
                final updatedBahan = BahanBaku(
                  id: b.id,
                  nama: b.nama,
                  totalBelanja: b.totalBelanja + addPrice,
                  totalBahan: b.totalBahan + addQty,
                  satuan: b.satuan,
                  hargaPerSatuan: (b.totalBelanja + addPrice) / (b.totalBahan + addQty),
                  supplier: supplierController.text.isEmpty ? b.supplier : supplierController.text,
                );

                await _repo.insertBahan(updatedBahan);
                
                // Catat ke Pengeluaran
                final newTrx = Transaksi(
                  id: 'PURCH-RESTOCK-${DateTime.now().millisecondsSinceEpoch}',
                  jenis: 'pengeluaran',
                  nominal: addPrice,
                   tanggal: DateTime.now(),
                  deskripsi: 'Restock Bahan: ${b.nama} (+${addQty.toStringAsFixed(0)} ${b.satuan})',
                  pelanggan: supplierController.text.isEmpty ? (b.supplier ?? 'Supplier') : supplierController.text,
                  metode: 'Tunai',
                  items: [],
                );
                await _trxRepo.insert(newTrx);

                _loadBahan();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.add_shopping_cart, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'Berhasil restock ${b.nama}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.blue[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
