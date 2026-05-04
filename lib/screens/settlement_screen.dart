import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/transaksi_repository.dart';
import '../models/transaksi_model.dart';
import '../database/produk_repository.dart';
import '../services/printer_service.dart';
import '../utils/formatters.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final TransaksiRepository _transaksiRepo = TransaksiRepository();

  String _selectedFilter = 'Semua'; // 'Hari Ini', 'Bulan Ini', 'Pilih Tanggal', 'Semua'
  DateTimeRange? _customDateRange;
  DashboardSummary? _summary;
  List<DashboardTrendPoint> _trend = [];
  List<Transaksi> _allTransaksi = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    
    String? startIso;
    String? endIso;
    int trendDays = 7;

    final now = DateTime.now();
    if (_selectedFilter == 'Hari Ini') {
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
      startIso = start.toIso8601String();
      endIso = end.toIso8601String();
      trendDays = 1;
    } else if (_selectedFilter == 'Bulan Ini') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
      startIso = start.toIso8601String();
      endIso = end.toIso8601String();
      trendDays = 30;
    } else if (_selectedFilter == 'Pilih Tanggal' && _customDateRange != null) {
      startIso = _customDateRange!.start.toIso8601String();
      endIso = _customDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)).toIso8601String();
      trendDays = _customDateRange!.duration.inDays + 1;
    }

    final summary = await _transaksiRepo.getDashboardSummary(startDate: startIso, endDate: endIso);
    final trend = await _transaksiRepo.getDashboardTrend(days: trendDays, customStartDate: startIso);
    final history = await _transaksiRepo.getAll(limit: 100, startDate: startIso, endDate: endIso);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _trend = trend;
      _allTransaksi = history;
      _isLoading = false;
    });
  }

  void _pilihTanggalCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'Pilih Tanggal';
        _customDateRange = picked;
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _summary == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _summary!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Settlement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _cetakStrukSettlement,
            icon: const Icon(Icons.print_outlined, color: Colors.blue),
            tooltip: 'Cetak Struk Settlement',
          ),
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilterSection(),
            const SizedBox(height: 16),
            _buildHeroCard(summary),
            const SizedBox(height: 16),
            _buildSummaryGrid(summary),
            const SizedBox(height: 20),
            _buildChartCard(),

            const SizedBox(height: 32),
            _buildHistorySection(),
            const SizedBox(height: 100), // Extra space for scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_allTransaksi.length} Struk',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_allTransaksi.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Belum ada transaksi', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allTransaksi.length > 20 ? 20 : _allTransaksi.length, // Show latest 20
            itemBuilder: (context, index) {
              return _buildHistoryItem(_allTransaksi[index]);
            },
          ),
      ],
    );
  }

  Widget _buildHistoryItem(Transaksi trx) {
    final bool isPemasukan = trx.jenis == 'pemasukan';
    final String timeStr = trx.tanggal.toString().substring(11, 16);
    final String dateStr = trx.tanggal.toString().substring(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF4)),
      ),
      child: ListTile(
        onTap: () => _showTrxDetail(trx),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPemasukan ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPemasukan ? Icons.add : Icons.remove,
            color: isPemasukan ? Colors.green[700] : Colors.red[700],
          ),
        ),
        title: Text(
          trx.pelanggan.isEmpty ? 'Umum' : trx.pelanggan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateStr • $timeStr • ${trx.metode}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            if (trx.deskripsi.isNotEmpty)
              Text(
                trx.deskripsi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[800], fontStyle: FontStyle.italic),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Rp ${formatRupiah(trx.nominal)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isPemasukan ? Colors.green[700] : Colors.red[700],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trx.isPrinted)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Sudah Dicetak',
                      style: TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTrxDetail(Transaksi trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              height: 4, width: 40,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Detail Transaksi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDelete(trx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _detailRow('ID Transaksi', trx.id ?? '-'),
                    _detailRow('Waktu', trx.tanggal.toString().substring(0, 19)),
                    _detailRow(trx.jenis == 'pengeluaran' ? 'Supplier' : 'Pelanggan', trx.pelanggan.isEmpty ? 'Umum' : trx.pelanggan),
                    if (trx.noMeja != null && trx.noMeja!.isNotEmpty) _detailRow('Meja/Kursi', trx.noMeja!),
                    _detailRow('Metode', trx.metode),
                    _detailRow('Jenis', trx.jenis.toUpperCase()),
                    if (trx.deskripsi.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Keterangan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      Text(trx.deskripsi, style: const TextStyle(fontSize: 15)),
                    ],
                    const Divider(height: 48),
                    if (trx.items.isNotEmpty) ...[
                      const Text('Daftar Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                    ],
                    ...trx.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.namaProduk ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${item.qty} x Rp ${formatRupiah(item.hargaSaatIni)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                          Text('Rp ${formatRupiah(item.qty * item.hargaSaatIni)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(height: 48),
                    if (trx.diskon > 0 || trx.pajak > 0)
                      _detailRow('Subtotal', 'Rp ${formatRupiah(trx.nominal + trx.diskon - trx.pajak)}'),
                    if (trx.diskon > 0) _detailRow('Diskon ${trx.diskonInfo != null ? "(${trx.diskonInfo})" : ""}', '-Rp ${formatRupiah(trx.diskon)}', valueColor: Colors.red),
                    if (trx.pajak > 0) _detailRow('Pajak ${trx.pajakInfo != null ? "(${trx.pajakInfo})" : ""}', '+Rp ${formatRupiah(trx.pajak)}', valueColor: Colors.orange),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Rp ${formatRupiah(trx.nominal)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Cetak Struk Transaksi'),
                        onPressed: () => _printStruk(trx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Informasi Struk'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditDialog(trx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[50],
                          foregroundColor: Colors.blue[800],
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  void _confirmDelete(Transaksi trx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Data transaksi akan dihapus dari riwayat. Stok produk yang telah terpotong tidak akan kembali secara otomatis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await _transaksiRepo.delete(trx.id!);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close detail sheet
                _loadDashboard();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Transaksi trx) {
    final nameController = TextEditingController(text: trx.pelanggan);
    
    // Check if original record was percent
    bool initialDiskonPersen = trx.diskonInfo != null && trx.diskonInfo!.contains('%');
    bool initialPajakPersen = trx.pajakInfo != null && trx.pajakInfo!.contains('%');
    String? selectedMeja = trx.noMeja;

    // Extract original input values (remove % or Rp prefix for editing)
    String initialDiskonVal = trx.diskon == 0 ? '' : trx.diskon.toString();
    if (initialDiskonPersen) {
      initialDiskonVal = trx.diskonInfo!.replaceAll('%', '');
      if (initialDiskonVal == '0') initialDiskonVal = '';
    }
    String initialPajakVal = trx.pajak == 0 ? '' : trx.pajak.toString();
    if (initialPajakPersen) {
      initialPajakVal = trx.pajakInfo!.replaceAll('%', '');
      if (initialPajakVal == '0') initialPajakVal = '';
    }

    final diskonController = TextEditingController(text: initialDiskonVal);
    final pajakController = TextEditingController(text: initialPajakVal);
    final selectedMetode = ValueNotifier<String>(trx.metode);

    int subtotal = 0;
    for (var item in trx.items) {
      subtotal += item.qty * item.hargaSaatIni;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Informasi Struk'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pelanggan',
                      hintText: 'Umum',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Pilihan Metode
                  ValueListenableBuilder<String>(
                    valueListenable: selectedMetode,
                    builder: (context, value, _) {
                      return DropdownButtonFormField<String>(
                        value: value,
                        decoration: const InputDecoration(
                          labelText: 'Metode Pembayaran',
                          prefixIcon: Icon(Icons.payment_outlined),
                        ),
                        items: ['Tunai', 'QRIS', 'Transfer', 'Lainnya'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) => selectedMetode.value = val!,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // PILIH MEJA BUTTON
                  InkWell(
                    onTap: () async {
                      final usedSeats = await _transaksiRepo.getUsedSeatsToday();
                      if (!mounted) return;
                      
                      showDialog(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setInnerState) {
                            return AlertDialog(
                              title: const Text('Pilih Meja/Kursi'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8,
                                  ),
                                  itemCount: 20,
                                  itemBuilder: (context, index) {
                                    final no = (index + 1).toString();
                                    final isSelected = selectedMeja == no;
                                    final isOccupied = usedSeats.contains(no) && no != trx.noMeja;

                                    return InkWell(
                                      onTap: isOccupied ? null : () {
                                        setDialogState(() => selectedMeja = no);
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isOccupied ? Colors.green[100] : (isSelected ? Colors.blue : Colors.white),
                                          border: Border.all(color: isOccupied ? Colors.green : (isSelected ? Colors.blue : Colors.grey[300]!)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(no, style: TextStyle(color: isOccupied ? Colors.green[900] : (isSelected ? Colors.white : Colors.black), fontWeight: FontWeight.bold)),
                                            if (isOccupied) const Text('Isi', style: TextStyle(fontSize: 8, color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () { setDialogState(() => selectedMeja = null); Navigator.pop(context); }, child: const Text('Hapus')),
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
                              ],
                            );
                          }
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.chair_outlined, color: selectedMeja != null ? Colors.blue : Colors.grey),
                          const SizedBox(width: 8),
                          Text(selectedMeja != null ? 'Meja: $selectedMeja' : 'Pilih Meja/Kursi', style: TextStyle(color: selectedMeja != null ? Colors.blue : Colors.black87)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  // DISKON SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Diskon', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('%'),
                            selected: initialDiskonPersen,
                            onSelected: (val) => setDialogState(() => initialDiskonPersen = true),
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('Rp'),
                            selected: !initialDiskonPersen,
                            onSelected: (val) => setDialogState(() => initialDiskonPersen = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextField(
                    controller: diskonController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: initialDiskonPersen ? 'Input Persen (%)' : 'Input Nominal (Rp)',
                      prefixText: initialDiskonPersen ? '' : 'Rp ',
                      suffixText: initialDiskonPersen ? '%' : '',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // PAJAK SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pajak (PPN)', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('%'),
                            selected: initialPajakPersen,
                            onSelected: (val) => setDialogState(() => initialPajakPersen = true),
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('Rp'),
                            selected: !initialPajakPersen,
                            onSelected: (val) => setDialogState(() => initialPajakPersen = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextField(
                    controller: pajakController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: initialPajakPersen ? 'Input Persen (%)' : 'Input Nominal (Rp)',
                      prefixText: initialPajakPersen ? '' : 'Rp ',
                      suffixText: initialPajakPersen ? '%' : '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Subtotal Transaksi: Rp ${formatRupiah(subtotal)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final inputDiskon = int.tryParse(diskonController.text) ?? 0;
                  final inputPajak = int.tryParse(pajakController.text) ?? 0;
                  
                  int calcDiskonNominal = inputDiskon;
                  int calcPajakNominal = inputPajak;
                  String? newDiskonInfo;
                  String? newPajakInfo;

                  if (initialDiskonPersen) {
                    calcDiskonNominal = (subtotal * inputDiskon / 100).round();
                    newDiskonInfo = "$inputDiskon%";
                  } else if (inputDiskon > 0) {
                    newDiskonInfo = "Rp ${formatRupiah(inputDiskon)}";
                  }

                  if (initialPajakPersen) {
                    calcPajakNominal = (subtotal * inputPajak / 100).round();
                    newPajakInfo = "$inputPajak%";
                  } else if (inputPajak > 0) {
                    newPajakInfo = "Rp ${formatRupiah(inputPajak)}";
                  }
                  
                  final newNominal = subtotal - calcDiskonNominal + calcPajakNominal;

                  final updatedTrx = Transaksi(
                    id: trx.id,
                    jenis: trx.jenis,
                    nominal: newNominal < 0 ? 0 : newNominal,
                    tanggal: trx.tanggal,
                    deskripsi: trx.deskripsi,
                    pelanggan: nameController.text,
                    metode: selectedMetode.value,
                    diskon: calcDiskonNominal,
                    pajak: calcPajakNominal,
                    diskonInfo: newDiskonInfo,
                    pajakInfo: newPajakInfo,
                    noMeja: selectedMeja,
                    items: trx.items,
                  );
                  
                  await _transaksiRepo.update(updatedTrx);
                  if (mounted) {
                    Navigator.pop(context); // Close Dialog
                    _loadDashboard();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil diperbarui')));
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildHeroCard(DashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF173B6D), Color(0xFF2F6FD3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33173B6D),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ringkasan Keuangan Real-time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Rp ${formatRupiah(summary.laba)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Laba dihitung dari penjualan Rp ${formatRupiah(summary.totalPenjualan)} dikurangi HPP Rp ${formatRupiah(summary.totalHpp)}.',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildMetricCard(
            title: 'Total Penjualan',
            value: 'Rp ${formatRupiah(summary.totalPenjualan)}',
            subtitle: 'Semua transaksi pemasukan',
            icon: Icons.payments_outlined,
            accent: const Color(0xFF0C9B63),
          ),
          _buildMetricCard(
            title: 'HPP',
            value: 'Rp ${formatRupiah(summary.totalHpp)}',
            subtitle: 'Modal barang terjual',
            icon: Icons.inventory_2_outlined,
            accent: const Color(0xFFD9485F),
          ),
          _buildMetricCard(
            title: 'Laba',
            value: 'Rp ${formatRupiah(summary.laba)}',
            subtitle: 'Penjualan dikurangi HPP',
            icon: Icons.trending_up_rounded,
            accent: const Color(0xFF3C64F4),
          ),
          _buildMetricCard(
            title: 'Produk Terjual',
            value: '${formatRupiah(summary.totalProdukTerjual)} item',
            subtitle: 'Total qty transaksi penjualan',
            icon: Icons.shopping_bag_outlined,
            accent: const Color(0xFFB77212),
          ),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          );
        }

        if (constraints.maxWidth >= 560) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
            const SizedBox(height: 12),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EBF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final maxY = _chartMaxY();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EBF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik 7 Hari Terakhir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Membandingkan total penjualan dan laba harian.',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 0 ? 1 : maxY / 4,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFEAEFF7),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _compactCurrency(value),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _trend.length) {
                          return const SizedBox.shrink();
                        }
                        final date = _trend[index].tanggal;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 16,
                    getTooltipColor: (_) => const Color(0xFF1F2A44),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final point = _trend[spot.x.toInt()];
                        final label = spot.barIndex == 0 ? 'Penjualan' : 'Laba';
                        final amount = spot.barIndex == 0
                            ? point.totalPenjualan
                            : point.laba;
                        return LineTooltipItem(
                          '$label\nRp ${formatRupiah(amount)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      _trend.length,
                      (index) => FlSpot(index.toDouble(), _trend[index].totalPenjualan.toDouble()),
                    ),
                    isCurved: true,
                    barWidth: 4,
                    color: const Color(0xFF0C9B63),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x220C9B63),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      _trend.length,
                      (index) => FlSpot(index.toDouble(), _trend[index].laba.toDouble()),
                    ),
                    isCurved: true,
                    barWidth: 4,
                    color: const Color(0xFF3C64F4),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x223C64F4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: const [
              _ChartLegend(
                color: Color(0xFF0C9B63),
                label: 'Penjualan',
              ),
              _ChartLegend(
                color: Color(0xFF3C64F4),
                label: 'Laba',
              ),
            ],
          ),
        ],
      ),
    );
  }



  double _chartMaxY() {
    var maxValue = 0;
    for (final item in _trend) {
      if (item.totalPenjualan > maxValue) {
        maxValue = item.totalPenjualan;
      }
      if (item.laba > maxValue) {
        maxValue = item.laba;
      }
    }

    if (maxValue <= 0) return 10;
    return maxValue * 1.2;
  }

  String _compactCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}jt';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
  }

  Future<void> _printStruk(Transaksi trx) async {
    if (trx.isPrinted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Struk ini sudah pernah dicetak sebelumnya!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdf = await PrinterService().generateReceiptPdf(trx, PrinterService().storeName);
    _showPreviewDialog(pdf, 'Struk_${trx.id}', trx.id);
  }

  void _showPreviewDialog(pw.Document pdf, String fileName, [String? trxId]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 450,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pratinjau Struk',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PdfPreview(
                    build: (format) => pdf.save(),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    initialPageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
                    pdfFileName: '$fileName.pdf',
                    actions: [
                      PdfPreviewAction(
                        icon: const Icon(Icons.print),
                        onPressed: (context, build, format) async {
                          final ok = await PrinterService().printPdfDocument(pdf, fileName);
                          if (ok && trxId != null) {
                            await TransaksiRepository().updatePrintedStatus(trxId, true);
                            _loadDashboard(); // Refresh list to update icons/status
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await PrinterService().printPdfDocument(pdf, fileName);
                    if (ok) {
                      if (trxId != null) {
                        await TransaksiRepository().updatePrintedStatus(trxId, true);
                        _loadDashboard();
                      }
                      if (context.mounted) Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Struk berhasil dicetak'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
  }
  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Semua'),
          const SizedBox(width: 8),
          _buildFilterChip('Hari Ini'),
          const SizedBox(width: 8),
          _buildFilterChip('Bulan Ini'),
          const SizedBox(width: 8),
          _buildFilterChip('Pilih Tanggal', isCalendar: true),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isCalendar = false}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: isCalendar ? _pilihTanggalCustom : () {
        setState(() => _selectedFilter = label);
        _loadDashboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF173B6D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF173B6D) : const Color(0xFFE6EBF4)),
        ),
        child: Row(
          children: [
            if (isCalendar) ...[
              Icon(Icons.calendar_today, size: 14, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cetakStrukSettlement() async {
    final pdf = await _generateSettlementPdf();
    _showPreviewDialog(pdf, 'Settlement_Report_${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<pw.Document> _generateSettlementPdf() async {
    final produkRepo = ProdukRepository();
    final allProducts = await produkRepo.getAll();
    final Map<String, String> productCategoryMap = {};
    for (var p in allProducts) {
      if (p.id != null) productCategoryMap[p.id!] = p.kategori;
    }

    final Map<String, int> orderTypeSummary = {'Dine In': 0, 'Take Away / Umum': 0};
    final Map<String, int> paymentMethodSummary = {};
    final Map<String, Map<String, int>> categorySales = {};

    for (final trx in _allTransaksi) {
      if (trx.jenis == 'pemasukan') {
        // Summary Order Type
        if (trx.noMeja != null && trx.noMeja!.isNotEmpty) {
          orderTypeSummary['Dine In'] = orderTypeSummary['Dine In']! + 1;
        } else {
          orderTypeSummary['Take Away / Umum'] = orderTypeSummary['Take Away / Umum']! + 1;
        }

        // Summary Payment Method
        paymentMethodSummary.update(trx.metode, (val) => val + trx.nominal, ifAbsent: () => trx.nominal);

        for (final item in trx.items) {
          final cat = productCategoryMap[item.produkId] ?? 'Lainnya';
          final prodName = item.namaProduk ?? 'Produk';
          
          categorySales.putIfAbsent(cat, () => {});
          categorySales[cat]!.update(prodName, (val) => val + item.qty, ifAbsent: () => item.qty);
        }
      }
    }

    final pdf = pw.Document();
    final summary = _summary!;
    
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('SETTLEMENT REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 2),
              pw.Text('Kasir Pintar POS', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              
              _receiptRow('Periode', _selectedFilter),
              _receiptRow('Tgl Cetak', DateTime.now().toString().substring(0, 16)),
              
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              
              pw.Text('RINGKASAN KEUANGAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 4),
              _receiptRow('Penjualan', 'Rp ${formatRupiah(summary.totalPenjualan)}'),
              _receiptRow('HPP', 'Rp ${formatRupiah(summary.totalHpp)}'),
              _receiptRow('Laba', 'Rp ${formatRupiah(summary.laba)}'),
              
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              
              pw.Text('JENIS PEMESANAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 4),
              _receiptRow('Dine In', '${orderTypeSummary['Dine In']} Transaksi'),
              _receiptRow('Take Away', '${orderTypeSummary['Take Away / Umum']} Transaksi'),
              
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              pw.Text('METODE PEMBAYARAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 4),
              ...paymentMethodSummary.entries.map((e) => _receiptRow(e.key, 'Rp ${formatRupiah(e.value)}')).toList(),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              
              pw.Text('DETAIL PENJUALAN PRODUK', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 4),
              
              ...categorySales.entries.map((catEntry) {
                final catName = catEntry.key;
                final productsMap = catEntry.value;
                
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Kategori: $catName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.SizedBox(height: 2),
                    ...productsMap.entries.map((prodEntry) {
                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('- ${prodEntry.key}', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('${prodEntry.value} terjual', style: const pw.TextStyle(fontSize: 7)),
                        ],
                      );
                    }).toList(),
                    pw.SizedBox(height: 4),
                  ]
                );
              }).toList(),
              
              if (categorySales.isEmpty)
                pw.Text('Tidak ada data penjualan.', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
              
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              pw.Text('Terima Kasih', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}


class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }
}
