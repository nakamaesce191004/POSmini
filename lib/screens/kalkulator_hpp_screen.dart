import 'package:flutter/material.dart';
import '../database/resep_repository.dart';
import '../database/produk_repository.dart';
import '../models/resep_model.dart';
import '../models/produk_model.dart';
import '../utils/formatters.dart';

class KalkulatorHppScreen extends StatefulWidget {
  final String? productId; // Jika dikirim, berarti mode Edit Produk
  final String? productName;
  final List<RecipeIngredient>? initialIngredients;
  final double? initialProfit;

  const KalkulatorHppScreen({
    super.key,
    this.productId,
    this.productName,
    this.initialIngredients,
    this.initialProfit,
  });

  @override
  State<KalkulatorHppScreen> createState() => _KalkulatorHppScreenState();
}

class _KalkulatorHppScreenState extends State<KalkulatorHppScreen> {
  late final TextEditingController _namaMenuController;
  late final TextEditingController _profitMenuController;
  
  final TextEditingController _namaBahanController = TextEditingController();
  final TextEditingController _totalBelanjaController = TextEditingController();
  final TextEditingController _biayaTambahanController = TextEditingController();
  final TextEditingController _totalBahanController = TextEditingController();
  final TextEditingController _pemakaianController = TextEditingController();
  List<RecipeIngredient> _recipeIngredients = [];
  List<BahanBaku> _allBahanBaku = [];
  String _selectedUnit = 'gram';
  final _resepRepo = ResepRepository();
  final _produkRepo = ProdukRepository();
  bool _isSaved = false;
  bool _isRecipeSaved = false;

  @override
  void initState() {
    super.initState();
    _namaMenuController = TextEditingController(text: widget.productName ?? '');
    _profitMenuController = TextEditingController(text: (widget.initialProfit ?? 100).round().toString());
    
    if (widget.initialIngredients != null) {
      _recipeIngredients = List.from(widget.initialIngredients!);
    }
    _loadAllBahanBaku();
  }

  Future<void> _loadAllBahanBaku() async {
    final data = await _resepRepo.getAllBahan();
    setState(() {
      _allBahanBaku = data;
    });
  }

  @override
  void dispose() {
    _namaMenuController.dispose();
    _profitMenuController.dispose();
    _namaBahanController.dispose();
    _totalBelanjaController.dispose();
    _biayaTambahanController.dispose();
    _totalBahanController.dispose();
    _pemakaianController.dispose();
    super.dispose();
  }

  int get _totalBelanja => int.tryParse(_totalBelanjaController.text.replaceAll('.', '')) ?? 0;
  int get _totalModal => _totalBelanja + _biayaTambahan;
  int get _biayaTambahan => int.tryParse(_biayaTambahanController.text.replaceAll('.', '')) ?? 0;
  double get _totalBahan => double.tryParse(_totalBahanController.text) ?? 0;
  double get _pemakaianResep => double.tryParse(_pemakaianController.text) ?? 0;
  int get _hppPerUnit => _totalBahan <= 0 ? 0 : (_totalModal / _totalBahan).round();
  int get _hppPerResep => (_totalBahan <= 0 || _pemakaianResep <= 0)
      ? 0
      : ((_totalModal / _totalBahan) * _pemakaianResep).round();
  int get _totalHppResep => _recipeIngredients.fold(
        0,
        (sum, item) => sum + item.totalCostForRecipe,
      );
  
  double get _suggestedSellingPrice {
    final profit = double.tryParse(_profitMenuController.text) ?? 0;
    return _totalHppResep * (1 + (profit / 100));
  }

  void _updateResult() {
    setState(() {
      _isSaved = false;
      _isRecipeSaved = false;
    });
  }

  Future<void> _saveToBahanBaku() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    if (_isSaved) return;

    final nama = _namaBahanController.text.trim();
    if (nama.isEmpty || _totalModal <= 0 || _totalBahan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi Nama Bahan, Total Belanja, dan Total Isi terlebih dahulu.')),
      );
      return;
    }

    final newBahan = BahanBaku(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nama: nama,
      totalBelanja: _totalModal,
      totalBahan: _totalBahan,
      satuan: _selectedUnitLabel,
      hargaPerSatuan: _totalModal / _totalBahan,
    );

    await _resepRepo.insertBahan(newBahan);
    
    if (mounted) {
      setState(() {
        _isSaved = true;
      });
    }
  }

  Future<void> _saveRecipeAsProduct() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    if (_isRecipeSaved) return;

    if (_recipeIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan bahan ke resep terlebih dahulu.')),
      );
      return;
    }

    final namaMenu = _namaMenuController.text.trim();
    if (namaMenu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi Nama Menu Jualan terlebih dahulu di bagian atas.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final profitPercent = double.tryParse(_profitMenuController.text) ?? 0;
    final suggestedPrice = _totalHppResep * (1 + (profitPercent / 100));

    if (widget.productId != null) {
      // MODE UPDATE: Perbarui produk yang sudah ada
      final existingProduct = await _produkRepo.getById(widget.productId!);
      if (existingProduct != null) {
        final updatedProduct = existingProduct.copyWith(
          nama: namaMenu,
          harga: suggestedPrice.round(),
          hargaBeli: _totalHppResep,
        );
        await _produkRepo.update(updatedProduct);
        await _saveRecipeMappings(widget.productId!);
        
        if (mounted) {
          Navigator.pop(context, true); // Kembali dengan status true agar TambahProdukScreen merefresh
          return;
        }
      }
    }

    // MODE BARU: Simpan sebagai produk baru
    final productId = DateTime.now().millisecondsSinceEpoch.toString();
    final newProduct = Produk(
      id: productId,
      nama: namaMenu,
      harga: suggestedPrice.round(),
      hargaBeli: _totalHppResep,
      stok: 0,
      kategori: 'Minuman/Makanan',
      gambar: Icons.restaurant, 
    );
    await _produkRepo.insert(newProduct);
    await _saveRecipeMappings(productId);

    if (mounted) {
      setState(() {
        _isRecipeSaved = true;
      });
    }
  }

  Future<void> _saveRecipeMappings(String pid) async {
    // Save its Ingredients to resep table
    final dbBahan = await _resepRepo.getAllBahan();
    
    // Clear old recipe for this product if any
    await _resepRepo.deleteResepByProduk(pid);

    for (var item in _recipeIngredients) {
      var existing = dbBahan.where((b) => b.nama.toLowerCase() == item.name.toLowerCase()).firstOrNull;
      String bahanId;
      if (existing != null) {
        bahanId = existing.id!;
      } else {
        bahanId = DateTime.now().millisecondsSinceEpoch.toString() + item.name.hashCode.toString();
        await _resepRepo.insertBahan(BahanBaku(
          id: bahanId,
          nama: item.name,
          totalBelanja: item.purchaseCost,
          totalBahan: item.totalAmount,
          satuan: item.unit,
          hargaPerSatuan: item.costPerUnit.toDouble(),
        ));
      }
      await _resepRepo.insertResep(Resep(
        produkId: pid,
        bahanId: bahanId,
        qty: item.usedAmount,
      ));
    }
  }

  void _addCurrentIngredientToRecipe() {
    ScaffoldMessenger.of(context).clearSnackBars();
    final nama = _namaBahanController.text.trim();
    if (nama.isEmpty || _totalModal <= 0 || _totalBahan <= 0 || _pemakaianResep <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nama bahan, total modal, total bahan, dan pemakaian resep terlebih dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _recipeIngredients.add(
        RecipeIngredient(
          name: nama,
          purchaseCost: _totalModal,
          totalAmount: _totalBahan,
          usedAmount: _pemakaianResep,
          unit: _selectedUnit,
        ),
      );
      
      // Bersihkan input setelah tambah
      _namaBahanController.clear();
      _totalBelanjaController.clear();
      _biayaTambahanController.clear();
      _totalBahanController.clear();
      _pemakaianController.clear();
      _isRecipeSaved = false;
      _isSaved = false;
    });
  }

  void _editRecipeIngredient(int index) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final item = _recipeIngredients[index];
    
    setState(() {
      _namaBahanController.text = item.name;
      _totalBelanjaController.text = item.purchaseCost.toString();
      _biayaTambahanController.text = "0"; 
      _totalBahanController.text = item.totalAmount.toString();
      _pemakaianController.text = item.usedAmount.toString();
      _selectedUnit = item.unit;
      
      _recipeIngredients.removeAt(index);
      _isRecipeSaved = false;
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _recipeIngredients.removeAt(index);
    });
  }

  void _showBahanSelector(TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Bahan Sebelumnya'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allBahanBaku.length,
            itemBuilder: (context, index) {
              final b = _allBahanBaku[index];
              return ListTile(
                title: Text(b.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Rp ${formatRupiah(b.totalBelanja.round())} / ${b.totalBahan} ${b.satuan}'),
                onTap: () {
                  setState(() {
                    _namaBahanController.text = b.nama;
                    controller.text = b.nama;
                    _totalBelanjaController.text = b.totalBelanja.round().toString();
                    _totalBahanController.text = b.totalBahan.toString();
                    _biayaTambahanController.text = '0';
                    _selectedUnit = b.satuan?.toLowerCase() == 'ml' ? 'ml' : (b.satuan?.toLowerCase() == 'pcs' ? 'pcs' : 'gram');
                    _updateResult();
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Kalkulator HPP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildMenuInfoCard(),
          const SizedBox(height: 16),
          _buildFormCard(),
          const SizedBox(height: 16),
          _buildResultCard(),
          const SizedBox(height: 16),
          _buildRecipeComposerCard(),
          const SizedBox(height: 16),
          _buildGuideCard(),
        ],
      ),
    );
  }

  Widget _buildMenuInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Menu Baru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tentukan nama menu jualan dan target profit Anda.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _namaMenuController,
            onChanged: (val) => setState(() => _isRecipeSaved = false),
            decoration: _inputDecoration(
              label: 'Nama Menu Jualan',
              hint: 'Contoh: Kopi Susu Aren',
              icon: Icons.restaurant_menu,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _profitMenuController,
            keyboardType: TextInputType.number,
            onChanged: (val) => setState(() {
              _isRecipeSaved = false;
            }),
            decoration: _inputDecoration(
              label: 'Target Profit (%)',
              hint: 'Contoh: 100',
              icon: Icons.trending_up,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9A3412), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hitung HPP per gram atau ml',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Cocok untuk kopi, susu, sirup, atau bahan racikan lain. Masukkan total modal dan total isi bahan, lalu sistem hitung biaya per gram atau per ml.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Input Perhitungan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Autocomplete<BahanBaku>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<BahanBaku>.empty();
              }
              return _allBahanBaku.where((BahanBaku option) {
                return option.nama.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (BahanBaku option) => option.nama,
            onSelected: (BahanBaku selection) {
              setState(() {
                _namaBahanController.text = selection.nama;
                _totalBelanjaController.text = selection.totalBelanja.round().toString();
                _totalBahanController.text = selection.totalBahan.toString();
                _biayaTambahanController.text = '0';
                
                // Map unit string back to internal gram/ml/pcs
                final s = selection.satuan?.toLowerCase() ?? 'gram';
                if (s == 'gram' || s == 'ml' || s == 'pcs') {
                  _selectedUnit = s;
                } else if (s == 'kg' || s == 'liter') {
                  // Conversion if needed, but let's stick to base units for simplicity 
                  // based on our previous logic. 
                  _selectedUnit = 'gram';
                }
                _updateResult();
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Sync our controller with the autocompletes controller
              if (controller.text != _namaBahanController.text && _namaBahanController.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _namaBahanController.text;
              }
              
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (val) {
                  _namaBahanController.text = val;
                  _updateResult();
                },
                decoration: _inputDecoration(
                  label: 'Nama Bahan',
                  hint: 'Cari bahan lama atau ketik baru',
                  icon: Icons.label_outline,
                ).copyWith(
                  suffixIcon: _allBahanBaku.isEmpty 
                    ? null 
                    : IconButton(
                        icon: const Icon(Icons.manage_search, color: Color(0xFF9A3412)),
                        onPressed: () => _showBahanSelector(controller),
                        tooltip: 'Lihat Daftar Bahan',
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _totalBelanjaController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateResult(),
            inputFormatters: [RibuanInputFormatter()],
            decoration: _inputDecoration(
              label: 'Total Belanja',
              hint: 'Contoh: 500.000',
              icon: Icons.payments_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _biayaTambahanController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateResult(),
            inputFormatters: [RibuanInputFormatter()],
            decoration: _inputDecoration(
              label: 'Biaya Tambahan',
              hint: 'Contoh: 20.000',
              icon: Icons.local_shipping_outlined,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _totalBahanController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _updateResult(),
                  decoration: _inputDecoration(
                    label: 'Total Bahan',
                    hint: _selectedUnit == 'gram' ? 'Contoh: 1000' : 'Contoh: 1000',
                    icon: Icons.scale_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: _inputDecoration(
                    label: 'Satuan',
                    hint: 'Pilih satuan',
                    icon: Icons.straighten_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gram', child: Text('Gram')),
                    DropdownMenuItem(value: 'ml', child: Text('Ml')),
                    DropdownMenuItem(value: 'pcs', child: Text('Pcs')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedUnit = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pemakaianController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _updateResult(),
            decoration: _inputDecoration(
              label: 'Pemakaian per Resep',
              hint: _selectedHintForUsage,
              icon: Icons.coffee_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hasil Perhitungan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total Belanja', 'Rp ${formatRupiah(_totalBelanja)}'),
          _buildStatRow('Biaya Tambahan', 'Rp ${formatRupiah(_biayaTambahan)}'),
          _buildStatRow('Total Modal', 'Rp ${formatRupiah(_totalModal)}'),
          _buildStatRow(
            'Total Bahan',
            '${_formatDecimal(_totalBahan)} $_selectedUnitLabel',
          ),
          const Divider(height: 28),
          Text(
            'HPP per $_selectedUnitLabel',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${formatRupiah(_hppPerUnit)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'HPP per Resep',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${formatRupiah(_hppPerResep)}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9A3412),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeComposerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Komposer Resep',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addCurrentIngredientToRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9A3412),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan bahan satu per satu dari kalkulator di atas. Cocok untuk kopi, susu, gula, cup, dan topping.',
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_recipeIngredients.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Belum ada bahan di resep. Isi bahan di atas lalu tekan Tambah.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            )
          else
            ...List.generate(_recipeIngredients.length, (index) {
              final item = _recipeIngredients[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == _recipeIngredients.length - 1 ? 0 : 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8EAF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editRecipeIngredient(index),
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            tooltip: 'Edit Bahan',
                          ),
                          IconButton(
                            onPressed: () => _removeIngredient(index),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Hapus Bahan',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Biaya per ${item.unitLabel}',
                        'Rp ${formatRupiah(item.costPerUnit)}',
                      ),
                      _buildStatRow(
                        'Pakai per resep',
                        '${_formatDecimal(item.usedAmount)} ${item.unitLabel}',
                      ),
                      _buildStatRow(
                        'Total bahan ini',
                        'Rp ${formatRupiah(item.totalCostForRecipe)}',
                      ),
                    ],
                  ),
                ),
              );
            }),
          const Divider(height: 28),
          Text(
            'Total HPP Resep',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Text(
            'Rp ${formatRupiah(_totalHppResep)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimasi Jual (Profit ${_profitMenuController.text}%):',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                'Rp ${formatRupiah(_suggestedSellingPrice.round())}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRecipeSaved ? null : (_recipeIngredients.isEmpty ? null : _saveRecipeAsProduct),
              icon: Icon(_isRecipeSaved ? Icons.check_circle : Icons.restaurant_menu),
              label: Text(_isRecipeSaved 
                  ? 'Berhasil Disimpan' 
                  : (widget.productId != null ? 'Perbarui HPP ke Produk' : 'Simpan Sebagai Produk Menu')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecipeSaved ? Colors.green : const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                disabledBackgroundColor: Colors.green.withValues(alpha: 0.8),
                disabledForegroundColor: Colors.white,
              ),
            ),
          ),
          if (_recipeIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _isRecipeSaved 
                  ? 'Menu berhasil ditambahkan ke Katalog Produk!'
                  : (widget.productId != null 
                     ? 'Klik tombol di atas untuk memperbarui data HPP dan resep produk ini.'
                     : 'Klik tombol di atas untuk menjadikan seluruh racikan ini sebagai menu jualan.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isRecipeSaved ? Colors.green[700] : Colors.grey[600], 
                  fontSize: 13, 
                  fontStyle: FontStyle.italic,
                  fontWeight: _isRecipeSaved ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFCDDA8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Cara Pakai',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text('1. Isi total belanja dari supplier.'),
          SizedBox(height: 6),
          Text('2. Tambahkan ongkir, packing, atau biaya lain jika ada.'),
          SizedBox(height: 6),
          Text('3. Isi total bahan yang Anda dapat, misalnya 1000 gram, 1000 ml, atau 50 pcs.'),
          SizedBox(height: 6),
          Text('4. Isi pemakaian resep, misalnya 18 gram kopi atau 150 ml susu.'),
          SizedBox(height: 6),
          Text('5. Tekan Tambah untuk memasukkan bahan ke resep. Ulangi untuk bahan lain.'),
          SizedBox(height: 10),
          Text(
            'Rumus per unit: (Total Belanja + Biaya Tambahan) / Total Bahan',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Rumus per resep: HPP per unit x Pemakaian Resep',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDecimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String get _selectedUnitLabel {
    switch (_selectedUnit) {
      case 'ml':
        return 'ml';
      case 'pcs':
        return 'pcs';
      default:
        return 'gram';
    }
  }

  String get _selectedHintForUsage {
    switch (_selectedUnit) {
      case 'ml':
        return 'Contoh: 150';
      case 'pcs':
        return 'Contoh: 1';
      default:
        return 'Contoh: 18';
    }
  }
}

class RecipeIngredient {
  final String name;
  final int purchaseCost;
  final double totalAmount;
  final double usedAmount;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.purchaseCost,
    required this.totalAmount,
    required this.usedAmount,
    required this.unit,
  });

  int get costPerUnit => totalAmount <= 0 ? 0 : (purchaseCost / totalAmount).round();
  int get totalCostForRecipe => (totalAmount <= 0 || usedAmount <= 0)
      ? 0
      : ((purchaseCost / totalAmount) * usedAmount).round();

  String get unitLabel {
    switch (unit) {
      case 'ml':
        return 'ml';
      case 'pcs':
        return 'pcs';
      default:
        return 'gram';
    }
  }
}
