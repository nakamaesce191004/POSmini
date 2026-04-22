import 'package:flutter/material.dart';
import '../database/produk_repository.dart';
import '../models/produk_model.dart';
import '../database/resep_repository.dart';
import '../models/resep_model.dart';
import 'kalkulator_hpp_screen.dart';
import 'dart:math';

class TambahProdukScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const TambahProdukScreen({super.key, this.initialData});

  @override
  State<TambahProdukScreen> createState() => _TambahProdukScreenState();
}

class _TambahProdukScreenState extends State<TambahProdukScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _skuController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _hargaJualController = TextEditingController();
  final _hargaBeliController = TextEditingController();
  final _profitMarginController = TextEditingController(text: '100');
  final _stokController = TextEditingController();
  final _kategoriController = TextEditingController();

  final Color _primaryRed = const Color(0xFFFF5252);
  final Color _fillColor = const Color(0xFFF5F6F8);
  
  List<Produk> _allProduk = [];
  final ProdukRepository _repo = ProdukRepository();
  final _resepRepo = ResepRepository();
  List<Resep> _currentRecipe = [];

  @override
  void initState() {
    super.initState();
    _loadProduk();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _namaController.text = data['nama']?.toString() ?? '';
      _skuController.text = data['sku']?.toString() ?? '';
      _deskripsiController.text = data['deskripsi']?.toString() ?? '';
      _hargaJualController.text = data['harga']?.toString() ?? '';
      _hargaBeliController.text = data['harga_beli']?.toString() ?? '0';
      _stokController.text = data['stok']?.toString() ?? '';
      _kategoriController.text = data['kategori']?.toString() ?? '';
      _updateProfitMarginFromPrices();
      _loadRecipe(data['id']);
    }
  }

  void _updateProfitMarginFromPrices() {
    final hpp = double.tryParse(_hargaBeliController.text) ?? 0;
    final jual = double.tryParse(_hargaJualController.text) ?? 0;
    if (hpp > 0) {
      final profit = ((jual - hpp) / hpp) * 100;
      _profitMarginController.text = profit.round().toString();
    }
  }

  void _updateSellingPriceFromProfit() {
    final hpp = double.tryParse(_hargaBeliController.text) ?? 0;
    final profit = double.tryParse(_profitMarginController.text) ?? 0;
    if (hpp > 0) {
      final jual = hpp * (1 + (profit / 100));
      _hargaJualController.text = jual.round().toString();
    }
  }

  Future<void> _loadRecipe(String? produkId) async {
    if (produkId == null) return;
    final recipe = await _resepRepo.getResepByProduk(produkId);
    setState(() {
      _currentRecipe = recipe;
    });
  }

  Future<void> _loadProduk() async {
    final data = await _repo.getAll();
    if (mounted) {
      setState(() {
        _allProduk = data;
      });
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _skuController.dispose();
    _deskripsiController.dispose();
    _hargaJualController.dispose();
    _hargaBeliController.dispose();
    _profitMarginController.dispose();
    _stokController.dispose();
    _kategoriController.dispose();
    super.dispose();
  }



  void _calculateHppFromRecipe() {
    double total = 0;
    for (var r in _currentRecipe) {
      total += r.totalHppContribution;
    }
    _hargaBeliController.text = total.round().toString();
    _updateSellingPriceFromProfit();
  }

  Future<void> _openHppCalculator() async {
    final List<RecipeIngredient> mappedIngredients = _currentRecipe.map((r) => RecipeIngredient(
      name: r.namaBahan ?? 'Bahan',
      purchaseCost: ((r.hargaPerSatuan ?? 0) * r.qty).round(), 
      totalAmount: r.qty, 
      usedAmount: r.qty,
      unit: r.satuan ?? 'gram',
    )).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KalkulatorHppScreen(
          productId: widget.initialData?['id'],
          productName: _namaController.text,
          initialProfit: double.tryParse(_profitMarginController.text),
          initialIngredients: mappedIngredients,
        ),
      ),
    );

    if (result == true) {
      if (widget.initialData?['id'] != null) {
        await _loadRecipe(widget.initialData!['id']);
        final p = await _repo.getById(widget.initialData!['id']);
        if (p != null) {
          setState(() {
            _hargaBeliController.text = p.hargaBeli.toString();
            _hargaJualController.text = p.harga.toString();
            _updateProfitMarginFromPrices();
          });
        }
      }
    }
  }

  Future<void> _simpanProduk() async {
    if (_formKey.currentState!.validate()) {
      IconData iconGambar;
      if (_kategoriController.text.toLowerCase().contains('makanan')) {
        iconGambar = Icons.restaurant;
      } else if (_kategoriController.text.toLowerCase().contains('minuman')) {
        iconGambar = Icons.local_drink;
      } else {
        iconGambar = Icons.fastfood;
      }

      int stok = int.tryParse(_stokController.text) ?? 0;
      if (stok < 0) stok = 0;

      final pId = widget.initialData?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();

      final produk = Produk(
        id: pId,
        nama: _namaController.text,
        kategori: _kategoriController.text.isEmpty ? '' : _kategoriController.text,
        harga: int.tryParse(_hargaJualController.text) ?? 0,
        hargaBeli: int.tryParse(_hargaBeliController.text) ?? 0,
        stok: stok,
        gambar: iconGambar,
      );

      if (widget.initialData != null) {
        await _repo.update(produk);
      } else {
        await _repo.insert(produk);
      }

      // Save Recipe
      await _resepRepo.deleteResepByProduk(pId);
      for (var r in _currentRecipe) {
        await _resepRepo.insertResep(Resep(
          produkId: pId,
          bahanId: r.bahanId,
          qty: r.qty,
        ));
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  InputDecoration _customInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black45),
      filled: true,
      fillColor: _fillColor,
      prefixIcon: Icon(prefixIcon, color: _primaryRed),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.initialData != null ? 'Edit Produk' : 'Tambah Produk',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
            children: [
              // Nama Produk
              TextFormField(
                controller: _namaController,
                decoration: _customInputDecoration(
                  hint: 'Nama Produk',
                  prefixIcon: Icons.fastfood,
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // SKU & Kategori Row
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _skuController,
                      decoration: _customInputDecoration(
                        hint: 'SKU (Opsional)',
                        prefixIcon: Icons.qr_code,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _kategoriController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _allProduk
                            .map((p) => p.kategori)
                            .toSet()
                            .where((String option) =>
                                option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        _kategoriController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: (val) => _kategoriController.text = val,
                          decoration: _customInputDecoration(
                            hint: 'Kategori',
                            prefixIcon: Icons.category,
                          ),
                          validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: _customInputDecoration(
                  hint: 'Deskripsi',
                  prefixIcon: Icons.description,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hargaBeliController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _updateSellingPriceFromProfit(),
                      decoration: _customInputDecoration(
                        hint: 'HPP / Modal',
                        prefixIcon: Icons.inventory_2_outlined,
                      ),
                      validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _profitMarginController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _updateSellingPriceFromProfit(),
                      decoration: _customInputDecoration(
                        hint: 'Profit (%)',
                        prefixIcon: Icons.trending_up,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openHppCalculator,
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Edit HPP'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                ),
              ),
              const SizedBox(height: 8),

              // Harga Jual
              TextFormField(
                controller: _hargaJualController,
                keyboardType: TextInputType.number,
                onChanged: (val) => _updateProfitMarginFromPrices(),
                decoration: _customInputDecoration(
                  hint: 'Harga Jual Akhir',
                  prefixIcon: Icons.attach_money,
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // Stok Field
              TextFormField(
                controller: _stokController,
                keyboardType: TextInputType.number,
                decoration: _customInputDecoration(
                  hint: 'Stok Produk',
                  prefixIcon: Icons.inventory_2,
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 32),

              // Simpan Produk Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpanProduk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              
              if (widget.initialData != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      if (widget.initialData!['id'] != null) {
                         await _repo.delete(widget.initialData!['id']);
                         if (context.mounted) {
                            Navigator.pop(context, true);
                         }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryRed,
                      side: BorderSide(color: _primaryRed),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Hapus Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}
