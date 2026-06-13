import 'package:flutter/material.dart';
import '../database/transaksi_repository.dart';
import '../database/metode_repository.dart';
import '../database/produk_repository.dart';
import '../database/meja_repository.dart';
import '../models/transaksi_model.dart';
import '../models/produk_model.dart';
import '../models/metode_pembayaran_model.dart';
import '../models/meja_model.dart';
import '../utils/formatters.dart';
import '../widgets/app_image_view.dart';
import '../services/printer_service.dart';
import 'printer_settings_screen.dart';

class PembayaranScreen extends StatefulWidget {
  final int totalHarga;
  final Map<String, int> cart;
  final int diskon;
  final int pajak;
  final String? diskonInfo;
  final String? pajakInfo;
  final String? initialMeja;
  final Transaksi? existingTrx;

  const PembayaranScreen({
    super.key,
    required this.totalHarga,
    required this.cart,
    required this.diskon,
    required this.pajak,
    this.diskonInfo,
    this.pajakInfo,
    this.initialMeja,
    this.existingTrx,
  });

  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  String _selectedMetode = 'Tunai';
  late final TextEditingController _namaPelangganController;
  
  final TextEditingController _bayarController = TextEditingController();
  int _kembalian = 0;

  final MetodeRepository _metodeRepo = MetodeRepository();
  final TransaksiRepository _transaksiRepo = TransaksiRepository();
  final ProdukRepository _produkRepo = ProdukRepository();
  
  List<MetodePembayaran> _allMetode = [];
  String? _selectedMeja;
  String? _tempMejaSelection;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _namaPelangganController = TextEditingController(text: widget.existingTrx?.pelanggan ?? '');
    _selectedMeja = widget.existingTrx?.noMeja ?? widget.initialMeja;
    _bayarController.addListener(_hitungKembalian);
    _loadData();
  }

  Future<void> _loadData() async {
    final metode = await _metodeRepo.getAll();
    if (mounted) {
      setState(() {
        _allMetode = metode;
        _isLoading = false;
      });
    }
  }

  void _hitungKembalian() {
    final bayar = int.tryParse(_bayarController.text.replaceAll('.', '')) ?? 0;
    setState(() {
      _kembalian = bayar - widget.totalHarga;
    });
  }

  void _onKeyboardTap(String value) {
    String currentText = _bayarController.text.replaceAll('.', '');
    if (value == 'clear') {
      _bayarController.text = '';
    } else if (value == 'backspace') {
      if (currentText.isNotEmpty) {
        String newText = currentText.substring(0, currentText.length - 1);
        _bayarController.text = newText.isEmpty ? '' : formatRupiah(int.parse(newText));
      }
    } else {
      if (currentText.length < 12) {
        String newText = currentText + value;
        _bayarController.text = formatRupiah(int.parse(newText));
      }
    }
  }

  void _setAmount(int amount) {
    _bayarController.text = formatRupiah(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final semuaMetode = ['Tunai', ..._allMetode.where((m) => m.isActive).map((m) => m.nama)];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KIRI: Summary & Input Dasar
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryHeader(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Nama Pelanggan'),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _namaPelangganController,
                          hintText: 'Masukkan nama pelanggan',
                          icon: Icons.person_outline,
                        ),
                         const SizedBox(height: 32),
                        _buildSectionTitle('Pilih Meja/Kursi'),
                        const SizedBox(height: 12),
                        _buildMejaButton(),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Pilih Metode Pembayaran'),
                        const SizedBox(height: 12),
                        _buildMetodeSelection(semuaMetode),
                        const SizedBox(height: 48),
                        _buildActionButton(),
                      ],
                    ),
                  ),
                ),
                
                // KANAN: Detail Pembayaran & Numpad
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: const Border(left: BorderSide(color: Colors.black12)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedMetode == 'Tunai') ...[
                            _buildSectionTitle('Nominal Bayar'),
                            const SizedBox(height: 12),
                            _buildPaymentInput(),
                            const SizedBox(height: 16),
                            _buildQuickAmounts(),
                            const SizedBox(height: 16),
                            _buildNumpad(),
                            _buildChangeInfo(),
                          ] else ...[
                            _buildSectionTitle('Detail Metode'),
                            const SizedBox(height: 16),
                            _buildMetodeDetail(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // MOBILE LAYOUT
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeader(),
                const SizedBox(height: 32),
                _buildSectionTitle('Nama Pelanggan'),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _namaPelangganController,
                  hintText: 'Masukkan nama pelanggan',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Pilih Meja/Kursi'),
                const SizedBox(height: 12),
                _buildMejaButton(),
                const SizedBox(height: 24),
                _buildSectionTitle('Pilih Metode Pembayaran'),
                const SizedBox(height: 12),
                _buildMetodeSelection(semuaMetode),
                const SizedBox(height: 24),
                if (_selectedMetode == 'Tunai') ...[
                  _buildSectionTitle('Nominal Bayar'),
                  const SizedBox(height: 12),
                  _buildPaymentInput(),
                  const SizedBox(height: 16),
                  _buildQuickAmounts(),
                  const SizedBox(height: 16),
                  _buildNumpad(),
                  _buildChangeInfo(),
                ] else ...[
                  _buildMetodeDetail(),
                ],
                const SizedBox(height: 48),
                _buildActionButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Text('Total Tagihan', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Rp ${formatRupiah(widget.totalHarga)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFF25700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodeSelection(List<String> semuaMetode) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: semuaMetode.map((metode) {
        final isSelected = _selectedMetode == metode;
        return GestureDetector(
          onTap: () => setState(() => _selectedMetode = metode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF1EB) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFF25700) : Colors.grey[300]!,
              ),
            ),
            child: Text(
              metode,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFF25700) : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentInput() {
    return _buildTextField(
      controller: _bayarController,
      hintText: '0',
      icon: Icons.money,
      readOnly: true,
      prefixText: 'Rp ',
    );
  }

  Widget _buildChangeInfo() {
    if (_kembalian < 0 || _bayarController.text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Kembalian:', style: TextStyle(color: Colors.grey)),
          Text(
            'Rp ${formatRupiah(_kembalian)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _selesaikanPembayaran,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF25700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text(
          'Selesaikan & Cetak Struk',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hintText,
          prefixText: prefixText,
          prefixIcon: Icon(icon, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  void _selesaikanPembayaran() async {
    if (_selectedMetode == 'Tunai') {
      final bayar = int.tryParse(_bayarController.text.replaceAll('.', '')) ?? 0;
      if (bayar < widget.totalHarga) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nominal bayar kurang!')),
        );
        return;
      }
    }

    // Ambil detail produk untuk struk
    List<TransaksiItem> txItems = [];
    for (var entry in widget.cart.entries) {
      try {
        final p = await _produkRepo.getById(entry.key);
        if (p != null) {
          txItems.add(TransaksiItem(
            transaksiId: '',
            produkId: p.id ?? '',
            qty: entry.value,
            hargaSaatIni: p.harga,
            namaProduk: p.nama,
          ));
        }
      } catch (e) {
        debugPrint("Gagal ambil detail produk: $e");
      }
    }

    final trx = Transaksi(
      id: widget.existingTrx?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      jenis: 'pemasukan',
      nominal: widget.totalHarga,
      tanggal: widget.existingTrx?.tanggal ?? DateTime.now(),
      deskripsi: 'Penjualan Kasir',
      pelanggan: _namaPelangganController.text,
      metode: _selectedMetode,
      diskon: widget.diskon,
      pajak: widget.pajak,
      diskonInfo: widget.diskonInfo,
      pajakInfo: widget.pajakInfo,
      noMeja: _selectedMeja,
      items: txItems,
      status: 'Selesai',
    );

    if (widget.existingTrx != null) {
      await _transaksiRepo.update(trx);
    } else {
      await _transaksiRepo.insert(trx);
    }
    
    // Auto-print if enabled
    if (PrinterService().autoPrint && PrinterService().isConnected) {
      final ok = await PrinterService().printReceipt(trx, PrinterService().storeName);
      if (ok && trx.id != null) {
        await _transaksiRepo.updatePrintedStatus(trx.id!, true);
      }
    }

    if (mounted) _showReceiptDialog(trx);
  }

  void _showReceiptDialog(Transaksi trx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  SizedBox(height: 16),
                  Text('Transaksi Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _receiptRow('Pelanggan', _namaPelangganController.text),
                  if (_selectedMeja != null) _receiptRow('Meja/Kursi', _selectedMeja!),
                  _receiptRow('Metode', _selectedMetode),
                  if (widget.diskon > 0) _receiptRow('Diskon ${widget.diskonInfo != null ? "(${widget.diskonInfo})" : ""}', '-Rp ${formatRupiah(widget.diskon)}'),
                  if (widget.pajak > 0) _receiptRow('Pajak ${widget.pajakInfo != null ? "(${widget.pajakInfo})" : ""}', '+Rp ${formatRupiah(widget.pajak)}'),
                  _receiptRow('Total', 'Rp ${formatRupiah(widget.totalHarga)}'),
                  if (_selectedMetode == 'Tunai') _receiptRow('Bayar', 'Rp ${_bayarController.text.isEmpty ? '0' : _bayarController.text}'),
                  if (_selectedMetode == 'Tunai') _receiptRow('Kembali', 'Rp ${formatRupiah(_kembalian)}'),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('Cetak Struk Physical', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  final ok = await PrinterService().printReceipt(trx, PrinterService().storeName);
                  
                  if (ok && mounted) {
                    if (trx.id != null) {
                      await _transaksiRepo.updatePrintedStatus(trx.id!, true);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Struk berhasil dicetak'), backgroundColor: Colors.green),
                    );
                    Navigator.pop(context); // Close dialog after print? Or just stay? 
                    // User said "sudah tidak bisa di print", so maybe closing is good.
                    Navigator.pop(context, true);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal mencetak. Pastikan printer sudah terhubung!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Return success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Kembali ke Kasir', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    final List<int> denominations = [10000, 20000, 50000, 100000];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Saran Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            TextButton(
              onPressed: () => _onKeyboardTap('clear'),
              child: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickAmountButton('Uang Pas', widget.totalHarga, isPrimary: true),
              ...denominations.map((d) => _quickAmountButton('Rp ${formatRupiah(d)}', d)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickAmountButton(String label, int amount, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => _setAmount(amount),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFFF25700) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isPrimary ? const Color(0xFFF25700) : Colors.grey[300]!),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _numpadRow(['1', '2', '3']),
        _numpadRow(['4', '5', '6']),
        _numpadRow(['7', '8', '9']),
        _numpadRow(['000', '0', 'backspace']),
      ],
    );
  }

  Widget _numpadRow(List<String> values) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: values.map((val) => _numpadButton(val)).toList(),
      ),
    );
  }

  Widget _numpadButton(String value) {
    Widget child;
    if (value == 'backspace') {
      child = const Icon(Icons.backspace_outlined, size: 24, color: Colors.black87);
    } else {
      child = Text(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: InkWell(
            onTap: () => _onKeyboardTap(value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetodeDetail() {
    MetodePembayaran? metode;
    try {
      metode = _allMetode.firstWhere((m) => m.nama == _selectedMetode);
    } catch (e) {
      metode = null;
    }

    if (metode == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metode.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    metode.atasNama,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'No: ${metode.nomor}',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Icon(
                metode.tipe == 'QRIS' ? Icons.qr_code_scanner : Icons.account_balance_wallet,
                color: const Color(0xFFF25700),
                size: 40,
              ),
            ],
          ),
          if (metode.tipe == 'QRIS') ...[
            const SizedBox(height: 20),
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (metode.gambar.isNotEmpty)
                    ? AppImageView(
                        path: metode.gambar,
                        fit: BoxFit.contain,
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, size: 100, color: Colors.black87),
                            SizedBox(height: 8),
                            Text('[ Gambar QRIS ]', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildMejaButton() {
    return InkWell(
      onTap: _showMejaDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _selectedMeja != null ? Colors.blue : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.chair_outlined, color: _selectedMeja != null ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedMeja != null ? 'Meja/Kursi: $_selectedMeja' : 'Belum ada kursi yang dipilih',
                style: TextStyle(
                  color: _selectedMeja != null ? Colors.blue : Colors.grey[600],
                  fontWeight: _selectedMeja != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (_selectedMeja != null)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20)
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMejaDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<Map<String, dynamic>>(
            future: Future.wait([
              _transaksiRepo.getOccupiedSeatsWithCustomer(),
              MejaRepository().getActive(),
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
              
              final isCurrentSelectedOccupied = _tempMejaSelection != null && occupiedMap.containsKey(_tempMejaSelection);

              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.table_restaurant_rounded, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Pilih Meja', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            final customerAtTable = occupiedMap[no];
                            
                            final isOccupied = customerAtTable != null;
                            final isSelected = _tempMejaSelection == no;

                            Color bgColor;
                            Color borderColor;
                            Color textColor;

                            if (isSelected) {
                              bgColor = Colors.blue;
                              borderColor = Colors.blue[700]!;
                              textColor = Colors.white;
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
                              onTap: () {
                                setDialogState(() => _tempMejaSelection = isSelected ? null : no);
                              },
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
                                     if (isOccupied && !isSelected)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          customerAtTable!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 9, color: textColor.withOpacity(0.7), fontWeight: FontWeight.w500),
                                        ),
                                      )
                                    else if (isSelected)
                                      Text(
                                        isOccupied ? customerAtTable! : 'Dipilih',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w500),
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
                  if (isCurrentSelectedOccupied)
                    TextButton(
                      onPressed: () async {
                        final target = _tempMejaSelection!;
                        await _transaksiRepo.clearSeat(target);
                        setDialogState(() {
                          _tempMejaSelection = null;
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
                      child: Text('Kosongkan Meja $_tempMejaSelection', style: const TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setDialogState(() => _tempMejaSelection = null);
                      setState(() => _selectedMeja = null);
                      Navigator.pop(context);
                    },
                    child: const Text('Hapus Pilihan', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() => _selectedMeja = _tempMejaSelection);
                      Navigator.pop(context);
                    },
                    child: const Text('Pilih Meja (OK)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                actionsAlignment: MainAxisAlignment.spaceBetween,
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
}
