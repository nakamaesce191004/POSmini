import 'package:flutter/material.dart';
import '../database/transaksi_repository.dart';
import '../database/produk_repository.dart';
import '../models/transaksi_model.dart';
import '../models/produk_model.dart';
import '../utils/formatters.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/printer_service.dart';

class UangScreen extends StatefulWidget {
  const UangScreen({super.key});

  @override
  State<UangScreen> createState() => _UangScreenState();
}

class _UangScreenState extends State<UangScreen> {
  String _selectedFilter = 'Bulan Ini'; // 'Hari Ini', 'Bulan Ini', 'Tahun Ini', 'Pilih Tanggal'
  DateTimeRange? _customDateRange;

  final TransaksiRepository _transaksiRepo = TransaksiRepository();
  final ProdukRepository _produkRepo = ProdukRepository();
  
  List<Transaksi> _allTransaksi = [];
  List<Produk> _allProduk = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trx = await _transaksiRepo.getAll();
    final prd = await _produkRepo.getAll();
    if (mounted) {
      setState(() {
        _allTransaksi = trx;
        _allProduk = prd;
        _isLoading = false;
      });
    }
  }

  List<Transaksi> get _filteredTransaksi {
    final now = DateTime.now();
    return _allTransaksi.where((tx) {
      final date = tx.tanggal;
      
      if (_selectedFilter == 'Hari Ini') {
        return date.year == now.year && date.month == now.month && date.day == now.day;
      } else if (_selectedFilter == 'Bulan Ini') {
        return date.year == now.year && date.month == now.month;
      } else if (_selectedFilter == 'Tahun Ini') {
        return date.year == now.year;
      } else if (_selectedFilter == 'Pilih Tanggal' && _customDateRange != null) {
        // Cek apakah tanggal berada dalam range
        final start = _customDateRange!.start;
        final end = _customDateRange!.end.add(const Duration(days: 1)); // inclusive end day
        return date.isAfter(start) && date.isBefore(end);
      }
      return true; // Fallback
    }).toList();
  }

  int get _pemasukan {
    int total = 0;
    for (var tx in _filteredTransaksi) {
      if (tx.jenis == 'pemasukan') total += tx.nominal;
    }
    return total;
  }

  int get _pengeluaran {
    int total = 0;
    for (var tx in _filteredTransaksi) {
      if (tx.jenis == 'pengeluaran') total += tx.nominal;
    }
    return total;
  }

  int get _labaBersih => _pemasukan - _pengeluaran;

  String _formatDateInfo() {
    final now = DateTime.now();
    if (_selectedFilter == 'Hari Ini') {
      return "${now.day}/${now.month}/${now.year}";
    } else if (_selectedFilter == 'Bulan Ini') {
      return "Bulan ${now.month} ${now.year}";
    } else if (_selectedFilter == 'Tahun Ini') {
      return "Tahun ${now.year}";
    } else if (_selectedFilter == 'Pilih Tanggal' && _customDateRange != null) {
      final start = _customDateRange!.start;
      final end = _customDateRange!.end;
      return "${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}";
    }
    return '';
  }

  void _pilihTanggalCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.orange[800]!),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'Pilih Tanggal';
        _customDateRange = picked;
      });
    }
  }

  void _tambahTransaksiManual() {
    final formKey = GlobalKey<FormState>();
    String jenis = 'pengeluaran';
    String deskripsi = '';
    int nominal = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Tambah Transaksi Baru'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pengeluaran')),
                          selected: jenis == 'pengeluaran',
                          onSelected: (val) => setDialogState(() => jenis = 'pengeluaran'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pemasukan')),
                          selected: jenis == 'pemasukan',
                          onSelected: (val) => setDialogState(() => jenis = 'pemasukan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
                    validator: (val) => val == null || val.isEmpty ? 'Isi deskripsi' : null,
                    onSaved: (val) => deskripsi = val!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixText: 'Rp ', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || int.tryParse(val) == null ? 'Isi nominal valid' : null,
                    onSaved: (val) => nominal = int.parse(val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    
                    final newTx = Transaksi(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      jenis: jenis,
                      nominal: nominal,
                      tanggal: DateTime.now(),
                      deskripsi: deskripsi,
                      pelanggan: '',
                      metode: 'Tunai',
                      items: [],
                    );
                    
                    await _transaksiRepo.insert(newTx);
                    _loadData();
                    
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
           body: Center(child: CircularProgressIndicator())
       );
    }

    final sortedTransaksi = List<Transaksi>.from(_filteredTransaksi)
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Keuangan Toko', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.blue),
            onPressed: _generateReportPDF,
            tooltip: 'Download Laporan PDF',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.orange),
            onPressed: _tambahTransaksiManual,
            tooltip: 'Tambah Transaksi',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                children: [
                   const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                   const SizedBox(width: 8),
                   Text('Periode Laporan', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('Hari Ini'),
                    const SizedBox(width: 8),
                    _buildChip('Bulan Ini'),
                    const SizedBox(width: 8),
                    _buildChip('Tahun Ini'),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pilihTanggalCustom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedFilter == 'Pilih Tanggal' ? Colors.orange[800] : Colors.white,
                          border: Border.all(color: _selectedFilter == 'Pilih Tanggal' ? Colors.orange[800]! : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.date_range, size: 16, color: _selectedFilter == 'Pilih Tanggal' ? Colors.white : Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              'Pilih Tanggal',
                              style: TextStyle(
                                color: _selectedFilter == 'Pilih Tanggal' ? Colors.white : Colors.black87,
                                fontWeight: _selectedFilter == 'Pilih Tanggal' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatDateInfo(),
                    style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                  )
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              const Text(
                'Detail Transaksi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTransactionList(sortedTransaksi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[800] : Colors.white,
          border: Border.all(color: isSelected ? Colors.orange[800]! : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (isSelected) const Icon(Icons.check, color: Colors.white, size: 16),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[800]!, Colors.orange[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Laba Bersih', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Rp ${formatRupiah(_labaBersih)}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                          child: Icon(Icons.arrow_downward, color: Colors.green[600], size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Pemasukan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Rp ${formatRupiah(_pemasukan)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                          child: Icon(Icons.arrow_upward, color: Colors.red[600], size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('Pengeluaran', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Rp ${formatRupiah(_pengeluaran)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaksi> transaksi) {
    if (transaksi.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Tidak ada transaksi di periode ini', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transaksi.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final tx = transaksi[index];
          final isPemasukan = tx.jenis == 'pemasukan';
          final date = tx.tanggal;
          final items = tx.items;
          
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isPemasukan ? Colors.green[50] : Colors.red[50],
                child: Icon(
                  isPemasukan ? Icons.south_west : Icons.north_east,
                  color: isPemasukan ? Colors.green : Colors.red,
                ),
              ),
              title: Text(tx.deskripsi, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPemasukan ? '+' : '-'} Rp ${formatRupiah(tx.nominal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isPemasukan ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 16, color: Colors.grey),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      if (tx.metode.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Metode Pembayaran:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text(tx.metode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      if (tx.pelanggan.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isPemasukan ? 'Pelanggan:' : 'Supplier:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              Text(tx.pelanggan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      if (tx.deskripsi.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Keterangan:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(tx.deskripsi, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text('Daftar Produk / Item:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 8),
                        ...items.map((item) {
                          String namaProd = item.namaProduk ?? 'Produk Tidak Dikenal';
                          int harga = item.hargaSaatIni;
                          int qty = item.qty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('$namaProd x $qty', style: const TextStyle(fontSize: 13)),
                                ),
                                Text('Rp ${formatRupiah(harga * qty)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateReportPDF() async {
    final pdf = pw.Document();
    
    // Prediksi format tanggal untuk header
    String periodText = _selectedFilter;
    String dateRangeText = _formatDateInfo();

    final sortedTransaksi = List<Transaksi>.from(_filteredTransaksi)
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LAPORAN KEUANGAN', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                    pw.Text('Sistem Kasir Pintar', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Periode: $periodText', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(dateRangeText, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2, color: PdfColors.orange900),
            pw.SizedBox(height: 20),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPDFSummaryBox('Pemasukan', 'Rp ${formatRupiah(_pemasukan)}', PdfColors.green900),
                pw.SizedBox(width: 20),
                _buildPDFSummaryBox('Pengeluaran', 'Rp ${formatRupiah(_pengeluaran)}', PdfColors.red900),
                pw.SizedBox(width: 20),
                _buildPDFSummaryBox('Laba Bersih', 'Rp ${formatRupiah(_labaBersih)}', PdfColors.blue900),
              ],
            ),
            pw.SizedBox(height: 30),

            // Table Header
            pw.Text('Rincian Transaksi', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Tanggal', isHeader: true),
                    _buildTableCell('Deskripsi', isHeader: true),
                    _buildTableCell('Metode', isHeader: true),
                    _buildTableCell('Nominal', isHeader: true),
                  ],
                ),
                // Data Rows
                ...sortedTransaksi.map((tx) {
                  final date = tx.tanggal;
                  return pw.TableRow(
                    children: [
                      _buildTableCell('${date.day}/${date.month}/${date.year}'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(tx.deskripsi, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            if (tx.items.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 4),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: tx.items.map((item) {
                                    return pw.Text(
                                      '- ${item.namaProduk ?? 'Produk'} (x${item.qty})',
                                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildTableCell(tx.metode),
                      _buildTableCell(
                        '${tx.jenis == 'pemasukan' ? '+' : '-'} Rp ${formatRupiah(tx.nominal)}',
                        color: tx.jenis == 'pemasukan' ? PdfColors.green900 : PdfColors.red900,
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 40),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Dicetak pada: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  pw.SizedBox(height: 10),
                  pw.Text('Penanggung Jawab', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 60),
                  pw.Text('( ____________________ )', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();

    try {
      await PrinterService().printPdfDocument(
        pdf,
        'Laporan_Keuangan_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak laporan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPDFSummaryBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 10, color: color)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }
}
