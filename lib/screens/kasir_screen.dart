import 'package:flutter/material.dart';
import '../database/produk_repository.dart';
import '../database/resep_repository.dart';
import '../database/transaksi_repository.dart';
import '../models/produk_model.dart';
import '../models/transaksi_model.dart';
import '../utils/formatters.dart';
import '../database/meja_repository.dart';
import '../models/meja_model.dart';
import 'pembayaran_screen.dart';
import 'meja_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  String _searchQuery = '';
  String _selectedKategori = 'Semua';
  
  final ProdukRepository _produkRepo = ProdukRepository();
  final ResepRepository _resepRepo = ResepRepository();
  List<Produk> _allProduk = [];
  Map<String, int> _estimasiStok = {};
  bool _isLoading = true;

  // Format keranjang: { 'id_produk' : jumlah }
  final Map<String, int> _cart = {};
  int _diskonValue = 0;
  bool _isDiskonPersen = false;
  
  int _pajakValue = 0; // dalam persen 
  bool _isPajakAktif = false;
  String? _selectedMeja;
  String? _selectedMejaToClear;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProduk();
  }

  Future<void> _loadProduk() async {
    setState(() => _isLoading = true);
    final data = await _produkRepo.getAll();
    final estimasi = await _resepRepo.getEstimasiStokProduk();
    final pendings = await TransaksiRepository().getPendingTransactions();
    if (mounted) {
      setState(() {
        _allProduk = data;
        _estimasiStok = estimasi;
        _pendingCount = pendings.length;
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

  void _tambahKeKeranjang(String id) {
    setState(() {
      final currentQty = _cart[id] ?? 0;
      _cart[id] = currentQty + 1;
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

  Future<void> _pilihMeja({VoidCallback? onUpdate}) async {
    final txRepo = TransaksiRepository();
    final mejaRepo = MejaRepository();
    final allMeja = await mejaRepo.getActive();
    final occupiedMap = await txRepo.getOccupiedSeatsWithCustomer();
    
    if (!mounted) return;

    String? tempSelected = _selectedMeja;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.table_restaurant_rounded, color: Colors.blue),
                SizedBox(width: 12),
                Text('Pilih Meja/Kursi', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih meja untuk pesanan ini.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildLegendItem(Colors.green[400]!, 'Tersedia'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.red[400]!, 'Terisi'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.blue, 'Dipilih'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: allMeja.length,
                      itemBuilder: (context, index) {
                        final meja = allMeja[index];
                        final no = meja.id;
                        final customerName = occupiedMap[no];
                        final isOcc = customerName != null;
                        final isSelected = tempSelected == no;

                        Color bgColor;
                        Color borderColor;
                        Color textColor;

                        if (isSelected) {
                          bgColor = Colors.blue;
                          borderColor = Colors.blue[700]!;
                          textColor = Colors.white;
                        } else if (isOcc) {
                          bgColor = Colors.red[50]!;
                          borderColor = Colors.red[200]!;
                          textColor = Colors.red[900]!;
                        } else {
                          bgColor = Colors.green[50]!;
                          borderColor = Colors.green[200]!;
                          textColor = Colors.green[900]!;
                        }

                        return InkWell(
                          onTap: () => setDialogState(() => tempSelected = isSelected ? null : no),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: bgColor,
                              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8)] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  no,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (isOcc)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      customerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 9, color: textColor.withOpacity(0.7), fontWeight: FontWeight.w500),
                                    ),
                                  )
                                else if (isSelected)
                                  const Text(
                                    'Dipilih',
                                    style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w500),
                                  )
                                else
                                  Text(
                                    'Kosong',
                                    style: TextStyle(fontSize: 9, color: textColor.withOpacity(0.5)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'HAPUS'),
                child: const Text('Tanpa Meja', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, tempSelected),
                child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );

    if (result != null) {
      setState(() {
        if (result == 'HAPUS') {
          _selectedMeja = null;
        } else {
          _selectedMeja = result;
        }
      });
      if (onUpdate != null) onUpdate();
    }
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
          initialMeja: _selectedMeja,
        ),
      ),
    );

    if (result == true) {
      // Performa: Gunakan batch update jika produk banyak (opsional, tapi bagus)
      // Stok produk manual sudah tidak diupdate di sini (sudah otomatis lewat Bahan Baku)

      if (mounted) {
        setState(() {
          _cart.clear(); // Bersihkan keranjang
          _diskonValue = 0; // Bersihkan diskon
          _isDiskonPersen = false;
          _pajakValue = 0;
          _isPajakAktif = false;
          _selectedMeja = null;
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
    final mejaRepo = MejaRepository();
    final allMeja = await mejaRepo.getActive();
    if (!mounted) return;

    // Pastikan meja dipilih
    if (_selectedMeja == null) {
      await _pilihMeja();
    }
    
    // Jika masih null (dibatalkan/tanpa meja), tanya nama pelanggan saja
    String? selectedMeja = _selectedMeja;
    if (selectedMeja == null) return;

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
        _selectedMeja = null;
      });
      _loadProduk();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan Meja $selectedMeja disimpan! Silakan cek di menu Pesanan Aktif.'))
      );
    }
  }

  Color _getCategoryColor(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'makanan':
        return const Color(0xFFFEE2E2); // Rose 100
      case 'minuman':
        return const Color(0xFFE0F2FE); // Sky 100
      case 'cemilan':
        return const Color(0xFFFEF3C7); // Amber 100
      default:
        return const Color(0xFFF1F5F9); // Slate 100
    }
  }

  Color _getCategoryIconColor(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'makanan':
        return const Color(0xFFEF4444); // Rose 500
      case 'minuman':
        return const Color(0xFF0EA5E9); // Sky 500
      case 'cemilan':
        return const Color(0xFFD97706); // Amber 600
      default:
        return const Color(0xFF64748B); // Slate 500
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 750;
    final isDesktop = screenWidth >= 1100;

    final categories = ['Semua', ..._allProduk.map((p) => p.kategori).toSet()];

    final filteredProduk = _allProduk.where((p) {
      final matchKategori = _selectedKategori == 'Semua' || p.kategori == _selectedKategori;
      final matchSearch = p.nama.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchKategori && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Sistem Kasir',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
        actions: [
          if (!isWideScreen) ...[
            IconButton(
              icon: const Icon(Icons.assignment_outlined, color: Color(0xFFF59E0B)),
              onPressed: _showPendingOrdersDialog,
              tooltip: 'Pesanan Belum Bayar',
            ),
            IconButton(
              icon: const Icon(Icons.table_bar_outlined, color: Color(0xFF4F46E5)),
              onPressed: _showMejaManagementDialog,
              tooltip: 'Manajemen Kursi/Meja',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _loadProduk,
            tooltip: 'Sinkronisasi Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KIRI: Daftar Kategori, Pencarian, dan Grid Produk
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndCategoryHeader(categories),
                Expanded(
                  child: filteredProduk.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Produk tidak ditemukan',
                                style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
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
          
          // KANAN: Detail Keranjang (Terlihat di Layar Lebar)
          if (isWideScreen) 
            Container(
              width: isDesktop ? 400 : 340,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: _buildCartPanel(),
            ),
        ],
      ),
      
      // BAWAH: Floating Cart Footer (Hanya terlihat di Layar Kecil/Mobile)
      bottomNavigationBar: (!isWideScreen && _cart.isNotEmpty) ? _buildMobileCartFooter() : null,
    );
  }

  Widget _buildSearchAndCategoryHeader(List<String> categories) {
    IconData getCategoryIcon(String cat) {
      switch (cat.toLowerCase()) {
        case 'semua':
          return Icons.grid_view_rounded;
        case 'makanan':
          return Icons.restaurant_rounded;
        case 'minuman':
          return Icons.local_drink_rounded;
        case 'cemilan':
          return Icons.cookie_rounded;
        default:
          return Icons.restaurant_menu_rounded;
      }
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar with Barcode Scanner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Cari menu masakan atau minuman...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 20),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: Color(0xFFCBD5E1)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur Barcode Scanner akan segera hadir!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal Category Chips with Icons
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedKategori == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedKategori = cat);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getCategoryIcon(cat),
                              size: 15,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Produk produk) {
    if (produk.id == null) return const SizedBox.shrink();
    final qty = _cart[produk.id!] ?? 0;
    final isSelected = qty > 0;
    
    return GestureDetector(
      onTap: () => _tambahKeKeranjang(produk.id!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image / Icon container
              Expanded(
                child: Container(
                  color: _getCategoryColor(produk.kategori),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        produk.gambar,
                        size: 44,
                        color: _getCategoryIconColor(produk.kategori),
                      ),
                      // Top stock badge or category
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            produk.kategori,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                      // Cart Qty Badge
                      if (qty > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$qty',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Info Area
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produk.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rp ${formatRupiah(produk.harga)}',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        _buildStockBadge(produk.id!),
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

  Widget _buildStockBadge(String produkId) {
    final sisa = _estimasiStok[produkId];
    if (sisa == null) return const SizedBox.shrink();

    Color color = const Color(0xFF10B981); // Green
    String text = '$sisa Porsi';
    if (sisa <= 0) {
      color = const Color(0xFFEF4444); // Red
      text = 'Habis';
    } else if (sisa <= 5) {
      color = const Color(0xFFF59E0B); // Amber
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCartPanel({VoidCallback? onUpdate}) {
    return Column(
      children: [
        // Cart Header with structured controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart_outlined, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  const Text(
                    'Detail Transaksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalItem Item',
                      style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Moved controls (Meja, Pending Orders, Clear Cart)
              Row(
                children: [
                  // Meja Selector Chip
                  Expanded(
                    child: InkWell(
                      onTap: () => _pilihMeja(onUpdate: onUpdate),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedMeja != null ? const Color(0xFFEEF2F6) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedMeja != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_restaurant_rounded,
                              size: 14,
                              color: _selectedMeja != null ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _selectedMeja != null ? 'Meja $_selectedMeja' : 'Pilih Meja',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMeja != null ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Pending Orders Chip with Counter Badge
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _showPendingOrdersDialog();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _pendingCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _pendingCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 14,
                              color: _pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _pendingCount > 0 ? 'Pending ($_pendingCount)' : 'Pending',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Clear/Reset Cart Button
                  InkWell(
                    onTap: () {
                      if (_cart.isEmpty) return;
                      setState(() {
                        _cart.clear();
                        _diskonValue = 0;
                        _isDiskonPersen = false;
                        _pajakValue = 0;
                        _isPajakAktif = false;
                        _selectedMeja = null;
                      });
                      if (onUpdate != null) onUpdate();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Keranjang berhasil dibersihkan'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cart items list
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Keranjang masih kosong', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    produk.nama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Rp ${formatRupiah(produk.harga * qty)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${qty} x Rp ${formatRupiah(produk.harga)}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                                // Pill Qty Adjuster
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.remove_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _kurangiDariKeranjang(id);
                                          if (onUpdate != null) onUpdate();
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF4F46E5)),
                                        onPressed: () {
                                          _tambahKeKeranjang(id);
                                          if (onUpdate != null) onUpdate();
                                        },
                                      ),
                                    ],
                                  ),
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

        // Checkout & Billing Info Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))],
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  Text(
                    'Rp ${formatRupiah(_subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clickable Discount Pill
                  InkWell(
                    onTap: () {
                      int tempValue = _diskonValue;
                      bool tempIsPersen = _isDiskonPersen;
                      final controller = TextEditingController(
                        text: tempValue == 0 ? '' : (tempIsPersen ? tempValue.toString() : formatRupiah(tempValue))
                      );
                      
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
                                    inputFormatters: tempIsPersen ? [] : [RibuanInputFormatter()],
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
                                  child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444))),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _diskonValue = int.tryParse(controller.text.replaceAll('.', '')) ?? 0;
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
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.discount_outlined, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            _diskonValue > 0 
                                ? 'Diskon ($_diskonValue${_isDiskonPersen ? '%' : ' Rp'})' 
                                : '+ Diskon',
                            style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '- Rp ${formatRupiah(_diskonNominalKalkulasi)}',
                    style: TextStyle(
                      color: _diskonValue > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      fontWeight: _diskonValue > 0 ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clickable Tax Pill
                  InkWell(
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
                              child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444))),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _pajakValue = int.tryParse(controller.text) ?? 0;
                                  _isPajakAktif = _pajakValue > 0;
                                });
                                if (onUpdate != null) onUpdate();
                                Navigator.pop(context);
                              },
                              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            _isPajakAktif ? 'Pajak ($_pajakValue%)' : '+ Pajak PPN',
                            style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '+ Rp ${formatRupiah(_pajakNominalKalkulasi)}',
                    style: TextStyle(
                      color: _isPajakAktif ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                      fontWeight: _isPajakAktif ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text(
                    'Rp ${formatRupiah(_totalHarga)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cart Actions Buttons
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _prosesPembayaran,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // Emerald/Green checkout button
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _cart.isEmpty
                          ? 'Bayar Sekarang'
                          : 'Bayar • Rp ${formatRupiah(_totalHarga)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _cart.isEmpty ? null : _simpanBayarNanti,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _cart.isEmpty ? const Color(0xFFE2E8F0) : const Color(0xFF4F46E5),
                        width: 1.5,
                      ),
                      foregroundColor: const Color(0xFF4F46E5),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan / Bayar Nanti', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
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
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_totalItem Item di Keranjang', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${formatRupiah(_totalHarga)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => StatefulBuilder(
                      builder: (context, setModalState) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.8,
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
                                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
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
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: Colors.white),
                label: Text('Keranjang ($_totalItem)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMejaManagementDialog() {
    final txRepo = TransaksiRepository();
    final mejaRepo = MejaRepository();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<Map<String, dynamic>>(
            future: Future.wait([
              txRepo.getOccupiedSeatsWithCustomer(),
              mejaRepo.getActive(),
            ]).then((values) => {
              'occupiedMap': values[0] as Map<String, String>,
              'allMeja': values[1] as List<Meja>,
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
              }

              final occupiedMap = snapshot.data?['occupiedMap'] as Map<String, String>? ?? {};
              final allMeja = snapshot.data?['allMeja'] as List<Meja>? ?? [];
              
              // We need a local toClear that persists within the StatefulBuilder's scope
              // but can be cleared. We can use a static/instance variable or just handle it carefully.
              // Since this is inside a dialog, let's use a variable outside the FutureBuilder but inside StatefulBuilder.
              
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded, color: Colors.blue),
                    const SizedBox(width: 12),
                    const Text('Status Meja', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, size: 22, color: Colors.grey),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MejaScreen())).then((_) => _loadProduk());
                      },
                      tooltip: 'Manajemen Data Meja',
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildLegendItem(Colors.green[400]!, 'Tersedia'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.red[400]!, 'Terisi'),
                            const SizedBox(width: 16),
                            _buildLegendItem(Colors.blue, 'Dipilih'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        
                        if (allMeja.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Belum ada data meja aktif.'),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: allMeja.length,
                            itemBuilder: (context, index) {
                              final meja = allMeja[index];
                              final no = meja.id;
                              final customerName = occupiedMap[no];
                              final isOccupied = customerName != null;
                              final isTarget = _selectedMejaToClear == no;

                              Color bgColor;
                              Color borderColor;
                              Color textColor;

                              if (isTarget) {
                                bgColor = Colors.blue[50]!;
                                borderColor = Colors.blue;
                                textColor = Colors.blue[900]!;
                              } else if (isOccupied) {
                                bgColor = Colors.red[50]!;
                                borderColor = Colors.red[200]!;
                                textColor = Colors.red[900]!;
                              } else {
                                bgColor = Colors.green[50]!;
                                borderColor = Colors.green[200]!;
                                textColor = Colors.green[900]!;
                              }

                              return InkWell(
                                onTap: !isOccupied ? null : () {
                                  setDialogState(() => _selectedMejaToClear = isTarget ? null : no);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border.all(color: borderColor, width: isTarget ? 2 : 1),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isTarget ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8)] : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        no,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (isOccupied)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7), fontWeight: FontWeight.w500),
                                          ),
                                        )
                                      else
                                        Text(
                                          'Kosong',
                                          style: TextStyle(fontSize: 9, color: textColor.withOpacity(0.5)),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedMejaToClear != null 
                              ? 'Klik tombol "Kosongkan" di bawah untuk melepaskan Meja $_selectedMejaToClear.' 
                              : 'Pilih meja berwarna MERAH untuk mengosongkan statusnya.',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() => _selectedMejaToClear = null);
                      Navigator.pop(context);
                    },
                    child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMejaToClear != null ? Colors.red : Colors.grey[200],
                      foregroundColor: _selectedMejaToClear != null ? Colors.white : Colors.grey[600],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _selectedMejaToClear == null ? null : () async {
                      final target = _selectedMejaToClear!;
                      await txRepo.clearSeat(target);
                      setDialogState(() {
                        _selectedMejaToClear = null;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Meja $target telah dikosongkan'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green[700],
                          ),
                        );
                      }
                    },
                    child: Text(_selectedMejaToClear != null ? 'Kosongkan Meja $_selectedMejaToClear' : 'Pilih Meja', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        }
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
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
                                                    _loadProduk();
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
