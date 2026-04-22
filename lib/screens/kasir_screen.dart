import 'package:flutter/material.dart';
import '../database/produk_repository.dart';
import '../database/transaksi_repository.dart';
import '../models/produk_model.dart';
import '../models/transaksi_model.dart';
import '../utils/formatters.dart';
import 'pembayaran_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  String _searchQuery = '';
  String _selectedKategori = 'Semua';
  
  final ProdukRepository _produkRepo = ProdukRepository();
  List<Produk> _allProduk = [];
  bool _isLoading = true;

  // Format keranjang: { 'id_produk' : jumlah }
  final Map<String, int> _cart = {};
  int _diskonValue = 0;
  bool _isDiskonPersen = false;
  
  int _pajakValue = 0; // dalam persen 
  bool _isPajakAktif = false;

  @override
  void initState() {
    super.initState();
    _loadProduk();
  }

  Future<void> _loadProduk() async {
    setState(() => _isLoading = true);
    final data = await _produkRepo.getAll();
    if (mounted) {
      setState(() {
        _allProduk = data;
        _isLoading = false;
      });
    }
  }

  int get _diskonNominalKalkulasi {
    if (_isDiskonPersen) {
      return (_subtotal * (_diskonValue / 100)).round();
    }
    return _diskonValue;
  }

  int get _pajakNominalKalkulasi {
    if (!_isPajakAktif) return 0;
    // Pajak dihitung dari subtotal setelah diskon (umumnya)
    int dasarPajak = _subtotal - _diskonNominalKalkulasi;
    if (dasarPajak < 0) dasarPajak = 0;
    return (dasarPajak * (_pajakValue / 100)).round();
  }

  int get _subtotal {
    int total = 0;
    _cart.forEach((id, qty) {
      try {
        final produk = _allProduk.firstWhere((p) => p.id == id);
        total += produk.harga * qty;
      } catch (e) {
        // Product might have been deleted, ignore in subtotal or handle
      }
    });
    return total;
  }

  int get _totalItem {
    int total = 0;
    _cart.forEach((key, value) => total += value);
    return total;
  }

  int get _totalHarga {
    int total = _subtotal - _diskonNominalKalkulasi + _pajakNominalKalkulasi;
    return total < 0 ? 0 : total;
  }

  void _tambahKeKeranjang(String id, int stok) {
    setState(() {
      final currentQty = _cart[id] ?? 0;
      if (currentQty < stok) {
        _cart[id] = currentQty + 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok tidak mencukupi!'), duration: Duration(seconds: 1)),
        );
      }
    });
  }

  void _kurangiDariKeranjang(String id) {
    setState(() {
      final currentQty = _cart[id] ?? 0;
      if (currentQty > 1) {
        _cart[id] = currentQty - 1;
      } else {
        _cart.remove(id);
      }
    });
  }

  void _prosesPembayaran() async {
    if (_cart.isEmpty) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PembayaranScreen(
          totalHarga: _totalHarga,
          cart: Map.from(_cart),
          diskon: _diskonNominalKalkulasi,
          pajak: _pajakNominalKalkulasi,
          diskonInfo: _diskonValue > 0 ? (_isDiskonPersen ? "$_diskonValue%" : "Rp ${formatRupiah(_diskonValue)}") : null,
          pajakInfo: _isPajakAktif ? "$_pajakValue%" : null,
        ),
      ),
    );

    if (result == true) {
      // Performa: Gunakan batch update jika produk banyak (opsional, tapi bagus)
      for (var entry in _cart.entries) {
        try {
           final produk = _allProduk.firstWhere((p) => p.id == entry.key);
           final updatedProduk = produk.copyWith(stok: produk.stok - entry.value);
           await _produkRepo.update(updatedProduk);
        } catch (e) {
           // Ignore
        }
      }

      if (mounted) {
        setState(() {
          _cart.clear(); // Bersihkan keranjang
          _diskonValue = 0; // Bersihkan diskon
          _isDiskonPersen = false;
          _pajakValue = 0;
          _isPajakAktif = false;
        });
        
        // Reload products to reflect new stock
        _loadProduk();

        // TUTUP MODAL BOTTOM SHEET jika sedang terbuka (Issue #1 & #3)
        // Kita gunakan Navigator.popUntil untuk memastikan kembali ke layar utama kasir
        Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/');
      }
    }
  }

  void _simpanBayarNanti() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang masih kosong!')));
      return;
    }

    final txRepo = TransaksiRepository();
    final usedSeats = await txRepo.getUsedSeatsToday();
    if (!mounted) return;

    // Pilih Meja (Opsional)
    String? selectedMeja = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? tempSelected;
        return StatefulBuilder(
          builder: (stateContext, setDialogState) {
            return AlertDialog(
              title: const Text('Pilih Meja (Opsional)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pilih meja atau simpan sebagai pesanan umum/bawa pulang.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.maxFinite,
                    height: 250, // Beri tinggi tetap untuk menghindari error intrinsic height
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8,
                      ),
                      itemCount: 20,
                      itemBuilder: (context, index) {
                        final no = (index + 1).toString();
                        final isOcc = usedSeats.contains(no);
                        final isSelected = tempSelected == no;

                        return InkWell(
                          onTap: isOcc ? null : () => setDialogState(() => tempSelected = no),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isOcc ? Colors.green[100] : (isSelected ? Colors.blue : Colors.white),
                              border: Border.all(color: isOcc ? Colors.green : (isSelected ? Colors.blue : Colors.grey[200]!)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(no, style: TextStyle(color: isOcc ? Colors.green[900] : (isSelected ? Colors.white : Colors.black))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, ''), 
                  child: const Text('Simpan Tanpa Meja'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, tempSelected ?? ''),
                  child: const Text('Simpan Ke Meja'),
                ),
              ],
            );
          }
        );
      },
    );

    if (selectedMeja == null) return;

    final String displayName = selectedMeja.isEmpty ? 'Umum' : 'Meja $selectedMeja';

    // Buat objek Transaksi
    List<TransaksiItem> items = [];
    for (var entry in _cart.entries) {
      try {
        final p = _allProduk.firstWhere((prod) => prod.id == entry.key);
        items.add(TransaksiItem(
          transaksiId: '', // Akan diisi otomatis oleh repository
          produkId: p.id ?? '',
          namaProduk: p.nama,
          qty: entry.value,
          hargaSaatIni: p.harga,
        ));
      } catch (_) {}
    }

    final trx = Transaksi(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jenis: 'pemasukan',
      nominal: _totalHarga,
      tanggal: DateTime.now(),
      pelanggan: displayName,
      deskripsi: 'Pesanan Pending $displayName',
      metode: 'Tunai', 
      diskon: _diskonNominalKalkulasi,
      pajak: _pajakNominalKalkulasi,
      diskonInfo: _diskonValue > 0 ? (_isDiskonPersen ? "$_diskonValue%" : "Rp ${formatRupiah(_diskonValue)}") : null,
      pajakInfo: _isPajakAktif ? "$_pajakValue%" : null,
      items: items,
      noMeja: selectedMeja.isEmpty ? null : selectedMeja,
      status: 'Pending',
    );

    await txRepo.insert(trx);

    if (mounted) {
      setState(() {
        _cart.clear();
        _diskonValue = 0;
        _isDiskonPersen = false;
        _pajakValue = 0;
        _isPajakAktif = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan Meja $selectedMeja disimpan! Silakan cek di menu Pesanan Aktif.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    final categories = ['Semua', ..._allProduk.map((p) => p.kategori).toSet()];

    final filteredProduk = _allProduk.where((p) {
      final matchKategori = _selectedKategori == 'Semua' || p.kategori == _selectedKategori;
      final matchSearch = p.nama.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchKategori && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Sistem Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined, color: Colors.orange),
            onPressed: _showPendingOrdersDialog,
            tooltip: 'Pesanan Belum Bayar',
          ),
          IconButton(
            icon: const Icon(Icons.table_bar_outlined, color: Colors.blue),
            onPressed: _showMejaManagementDialog,
            tooltip: 'Manajemen Kursi/Meja',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KIRI: Daftar Produk
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSearchBar(categories),
                Expanded(
                  child: filteredProduk.isEmpty
                      ? Center(
                          child: Text(
                            'Produk tidak ditemukan',
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 250,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredProduk.length,
                          itemBuilder: (context, index) {
                            final produk = filteredProduk[index];
                            return _buildProductCard(produk);
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // KANAN: Detail Keranjang (Terlihat di Tablet/Desktop)
          if (isWideScreen) 
            Container(
              width: isDesktop ? 400 : 320,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.black12)),
              ),
              child: _buildCartPanel(),
            ),
        ],
      ),
      
      // BAWAH: Floating Cart Footer (Hanya terlihat di Mobile)
      bottomNavigationBar: (!isWideScreen && _cart.isNotEmpty) ? _buildMobileCartFooter() : null,
    );
  }

  Widget _buildSearchBar(List<String> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Cari menu...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedKategori,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.keyboard_arrow_down, size: 20),
                ),
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedKategori = val!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Produk produk) {
    if (produk.id == null) return const SizedBox.shrink();
    final qty = _cart[produk.id!] ?? 0;
    final stok = produk.stok;
    
    return GestureDetector(
      onTap: stok > 0 ? () => _tambahKeKeranjang(produk.id!, stok) : null,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: qty > 0 ? Colors.orange : Colors.grey[200]!, width: qty > 0 ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: stok == 0 ? Colors.grey[200] : Colors.orange[50],
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(produk.gambar, size: 50, color: stok == 0 ? Colors.grey : Colors.orange),
                      if (qty > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                            child: Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produk.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: stok == 0 ? Colors.grey : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rp ${formatRupiah(produk.harga)}',
                          style: TextStyle(color: stok == 0 ? Colors.grey : Colors.orange[800], fontWeight: FontWeight.bold),
                        ),
                        Text(
                          stok == 0 ? 'Habis' : 'Stok: $stok',
                          style: TextStyle(color: stok == 0 ? Colors.red : Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel({VoidCallback? onUpdate}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange[50],
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Pesanan Saat Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                child: Text('$_totalItem Item', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(child: Text('Keranjang kosong', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final id = _cart.keys.elementAt(index);
                    final qty = _cart[id]!;
                    Produk? produk;
                    try {
                      produk = _allProduk.firstWhere((p) => p.id == id);
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                    
                    return Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(produk.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Rp ${formatRupiah(produk.harga)}', style: TextStyle(color: Colors.orange[800])),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red,
                                  onPressed: () {
                                    _kurangiDariKeranjang(id);
                                    if (onUpdate != null) onUpdate();
                                  },
                                ),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: Colors.green,
                                  onPressed: () {
                                     _tambahKeKeranjang(id, produk!.stok);
                                     if (onUpdate != null) onUpdate();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
                  Text('Rp ${formatRupiah(_subtotal)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      int tempValue = _diskonValue;
                      bool tempIsPersen = _isDiskonPersen;
                      final controller = TextEditingController(text: tempValue == 0 ? '' : tempValue.toString());
                      
                      showDialog(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Tambah Diskon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ChoiceChip(
                                          label: const Center(child: Text('Rp')),
                                          selected: !tempIsPersen,
                                          onSelected: (val) => setDialogState(() => tempIsPersen = false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ChoiceChip(
                                          label: const Center(child: Text('%')),
                                          selected: tempIsPersen,
                                          onSelected: (val) => setDialogState(() => tempIsPersen = true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: tempIsPersen ? 'Persentase (%)' : 'Nominal (Rp)',
                                      prefixText: tempIsPersen ? '% ' : 'Rp ',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _diskonValue = 0;
                                      _isDiskonPersen = false;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _diskonValue = int.tryParse(controller.text) ?? 0;
                                      if (tempIsPersen && _diskonValue > 100) _diskonValue = 100;
                                      _isDiskonPersen = tempIsPersen;
                                    });
                                    if (onUpdate != null) onUpdate();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          }
                        ),
                      );
                    },
                    child: Text(
                      _diskonValue > 0 
                          ? 'Diskon ($_diskonValue${_isDiskonPersen ? '%' : ' Rp'})' 
                          : '+ Tambah Diskon',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '- Rp ${formatRupiah(_diskonNominalKalkulasi)}',
                    style: TextStyle(color: _diskonValue > 0 ? Colors.red : Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      final controller = TextEditingController(text: _pajakValue == 0 ? '' : _pajakValue.toString());
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Atur Pajak (PPN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Persentase Pajak (%)',
                                  prefixText: '% ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _pajakValue = 0;
                                  _isPajakAktif = false;
                                });
                                if (onUpdate != null) onUpdate();
                                Navigator.pop(context);
                              },
                              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () {
                                setState(() {
                                  _pajakValue = int.tryParse(controller.text) ?? 0;
                                  _isPajakAktif = _pajakValue > 0;
                                });
                                if (onUpdate != null) onUpdate();
                                Navigator.pop(context);
                              },
                              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      _isPajakAktif ? 'Pajak ($_pajakValue%)' : '+ Tambah Pajak',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '+ Rp ${formatRupiah(_pajakNominalKalkulasi)}',
                    style: TextStyle(color: _isPajakAktif ? Colors.orange : Colors.grey),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Rp ${formatRupiah(_totalHarga)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _prosesPembayaran,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _cart.isEmpty ? null : _simpanBayarNanti,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan / Bayar Nanti', style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCartFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_totalItem Item di Keranjang', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('Rp $_totalHarga', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => StatefulBuilder(
                      builder: (context, setModalState) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 4,
                                width: 40,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                              ),
                              Expanded(
                                child: _buildCartPanel(
                                  onUpdate: () => setModalState(() {}),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lihat Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMejaManagementDialog() async {
    final txRepo = TransaksiRepository();
    final usedSeats = await txRepo.getUsedSeatsToday();
    if (!mounted) return;

    String? toClear;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Manajemen Kursi Terisi'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pilih meja berstatus "Isi" untuk dikosongkan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 20,
                    itemBuilder: (context, index) {
                      final no = (index + 1).toString();
                      final isOccupied = usedSeats.contains(no);
                      final isTarget = toClear == no;

                      return InkWell(
                        onTap: !isOccupied ? null : () {
                          setDialogState(() => toClear = no);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isTarget ? Colors.red : (isOccupied ? Colors.green[100] : Colors.grey[50]),
                            border: Border.all(
                              color: isTarget ? Colors.red : (isOccupied ? Colors.green : Colors.grey[300]!)
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                no,
                                style: TextStyle(
                                  color: isTarget ? Colors.white : (isOccupied ? Colors.green[900] : Colors.grey),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isOccupied)
                                Text('Isi', style: TextStyle(fontSize: 8, color: isTarget ? Colors.white : Colors.green)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: toClear != null ? Colors.red : Colors.grey[300],
                  foregroundColor: toClear != null ? Colors.white : Colors.grey,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: toClear == null ? null : () async {
                  await txRepo.clearSeat(toClear!);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Meja $toClear telah dikosongkan')),
                    );
                  }
                },
                child: Text(toClear != null ? 'Kosongkan Meja $toClear' : 'Pilih Meja'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showPendingOrdersDialog() async {
    final txRepo = TransaksiRepository();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) {
          return FutureBuilder<List<Transaksi>>(
            future: txRepo.getPendingTransactions(),
            builder: (fContext, snapshot) {
              final pendings = snapshot.data ?? [];
              final isLoad = snapshot.connectionState == ConnectionState.waiting;

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Icon(Icons.assignment_late_outlined, color: Colors.orange),
                    const SizedBox(width: 10),
                    const Text('Pesanan Belum Bayar'),
                    const Spacer(),
                    if (!isLoad)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () => setDialogState(() {}),
                      ),
                  ],
                ),
                content: isLoad
                    ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                    : (pendings.isEmpty
                        ? const SizedBox(height: 100, child: Center(child: Text('Tidak ada pesanan aktif')))
                        : SizedBox(
                            width: double.maxFinite,
                            height: 400, // Fixed height to avoid intrinsic calculation issues
                            child: ListView.builder(
                              itemCount: pendings.length,
                              itemBuilder: (itemContext, index) {
                                final trx = pendings[index];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ExpansionTile(
                                    title: Text(trx.pelanggan, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Rp ${formatRupiah(trx.nominal)} • ${trx.items.length} Item'),
                                    leading: const Icon(Icons.table_restaurant, color: Colors.blue),
                                    children: [
                                      const Divider(height: 1),
                                      ...trx.items.map((item) => ListTile(
                                        dense: true,
                                        title: Text(item.namaProduk ?? 'Produk'),
                                        trailing: Text('${item.qty} x Rp ${formatRupiah(item.hargaSaatIni)}'),
                                      )),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // DELETE BUTTON
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 13)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.red),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: stateContext,
                                                    builder: (cContext) => AlertDialog(
                                                      title: const Text('Hapus Pesanan?'),
                                                      content: Text('Apakah Anda yakin ingin menghapus pesanan ${trx.pelanggan}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(cContext, false), child: const Text('Batal')),
                                                        TextButton(onPressed: () => Navigator.pop(cContext, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true && trx.id != null) {
                                                    await txRepo.delete(trx.id!);
                                                    setDialogState(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // EDIT BUTTON
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                                label: const Text('Ubah', style: TextStyle(color: Colors.blue, fontSize: 13)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.blue),
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () {
                                                  _editPendingOrder(trx);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // PAY BUTTON
                                            Expanded(
                                              flex: 2,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.payment, size: 18),
                                                label: const Text('Bayar Sekarang', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue, 
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () async {
                                                  Navigator.pop(dialogContext); // Close dialog using dialogContext
                                                  final result = await Navigator.push(
                                                    context, // Use screen context for push
                                                    MaterialPageRoute(
                                                      builder: (pContext) => PembayaranScreen(
                                                        totalHarga: trx.nominal,
                                                        cart: { for (var item in trx.items) item.produkId : item.qty },
                                                        diskon: trx.diskon,
                                                        pajak: trx.pajak,
                                                        diskonInfo: trx.diskonInfo,
                                                        pajakInfo: trx.pajakInfo,
                                                        existingTrx: trx,
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    // Update stok produk
                                                    final pRepo = ProdukRepository();
                                                    for (var item in trx.items) {
                                                      try {
                                                        final p = await pRepo.getById(item.produkId);
                                                        if (p != null) {
                                                          await pRepo.update(p.copyWith(stok: p.stok - item.qty));
                                                        }
                                                      } catch (_) {}
                                                    }
                                                    _loadProduk();
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tutup')),
                ],
              );
            },
          );
        }
      ),
    );
  }

  void _editPendingOrder(Transaksi trx) async {
    final confirmed = _cart.isEmpty ? true : await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Keranjang?'),
        content: const Text('Keranjang saat ini tidak kosong. Ingin menggantinya dengan pesanan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Ganti'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
        ],
      ),
    );

    if (confirmed == true) {
      if (trx.id == null) return;

      setState(() {
        _cart.clear();
        for (var item in trx.items) {
          _cart[item.produkId] = item.qty;
        }
        
        // Restore diskon
        _diskonValue = 0;
        _isDiskonPersen = false;
        if (trx.diskonInfo != null) {
          if (trx.diskonInfo!.contains('%')) {
            _isDiskonPersen = true;
            _diskonValue = int.tryParse(trx.diskonInfo!.replaceAll('%', '').trim()) ?? 0;
          } else {
            _diskonValue = trx.diskon;
          }
        }

        // Restore pajak
        _pajakValue = 0;
        _isPajakAktif = false;
        if (trx.pajakInfo != null) {
          _isPajakAktif = true;
          _pajakValue = int.tryParse(trx.pajakInfo!.replaceAll('%', '').trim()) ?? 0;
        }
      });

      await TransaksiRepository().delete(trx.id!);
      
      if (mounted) {
        Navigator.pop(context); // Tutup dialog Pesanan Pending
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan ${trx.pelanggan} berhasil dimuat ke keranjang.'))
        );
      }
    }
  }
}
