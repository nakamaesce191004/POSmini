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
import 'package:fl_chart/fl_chart.dart';
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
  List<DashboardTrendPoint> _trendData = [];
  DashboardSummary? _summary;
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
    
    // Load trend data based on filter
    int days = 7;
    String? customStart;
    if (_selectedFilter == 'Bulan Ini') {
      days = 30;
    } else if (_selectedFilter == 'Tahun Ini') {
      days = 365;
    } else if (_selectedFilter == 'Pilih Tanggal' && _customDateRange != null) {
      days = _customDateRange!.end.difference(_customDateRange!.start).inDays + 1;
      customStart = _customDateRange!.start.toIso8601String().split('T')[0];
    }
    
    final trend = await _transaksiRepo.getDashboardTrend(days: days, customStartDate: customStart);
    
    // Determine summary period
    String? sDate;
    String? eDate;
    final now = DateTime.now();

    if (_selectedFilter == 'Hari Ini') {
      sDate = now.toIso8601String().split('T')[0];
      eDate = "${sDate}T23:59:59";
    } else if (_selectedFilter == 'Bulan Ini') {
      sDate = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      eDate = "${now.toIso8601String().split('T')[0]}T23:59:59";
    } else if (_selectedFilter == 'Tahun Ini') {
      sDate = DateTime(now.year, 1, 1).toIso8601String().split('T')[0];
      eDate = "${now.toIso8601String().split('T')[0]}T23:59:59";
    } else if (_selectedFilter == 'Pilih Tanggal' && _customDateRange != null) {
      sDate = _customDateRange!.start.toIso8601String().split('T')[0];
      eDate = "${_customDateRange!.end.toIso8601String().split('T')[0]}T23:59:59";
    } else {
      // Fallback to last 7 days
      sDate = now.subtract(const Duration(days: 6)).toIso8601String().split('T')[0];
      eDate = "${now.toIso8601String().split('T')[0]}T23:59:59";
    }

    final summary = await _transaksiRepo.getDashboardSummary(
      startDate: sDate,
      endDate: eDate,
    );

    if (mounted) {
      setState(() {
        _allTransaksi = trx;
        _allProduk = prd;
        _trendData = trend;
        _summary = summary;
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
      _loadData(); // Reload trend and transaction data
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
              if (_summary != null) ...[
                _buildHeroCard(_summary!),
                const SizedBox(height: 24),
                _buildSummaryGrid(_summary!),
              ],
              const SizedBox(height: 24),
              _buildChartSection(),
              const SizedBox(height: 24),
              _buildTopProductsChart(),
              const SizedBox(height: 32),
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
        _loadData();
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
            'Laba dihitung dari penjualan bersih dikurangi HPP${summary.totalPengeluaranManual > 0 ? ' dan pengeluaran manual Rp ${formatRupiah(summary.totalPengeluaranManual)}' : ''}.',
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
            subtitle: summary.totalPengeluaranManual > 0 ? 'Penjualan - HPP - Biaya' : 'Penjualan dikurangi HPP',
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

        if (constraints.maxWidth < 320) {
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
        }

        if (constraints.maxWidth < 900) {
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

        return const SizedBox.shrink();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 190;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 14 : 18),
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
                padding: EdgeInsets.all(isCompact ? 9 : 11),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: isCompact ? 22 : 24),
              ),
              SizedBox(height: isCompact ? 14 : 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 20 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSection() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    // Data points for LineChart
    final List<FlSpot> spots = [];
    double maxVal = 0;

    for (int i = 0; i < _trendData.length; i++) {
      final p = _trendData[i];
      final val = p.totalPenjualan.toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxVal) maxVal = val;
    }

    if (maxVal == 0) maxVal = 10000; // Minimal height if no data

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tren Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100], strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _trendData.length > 7 ? (_trendData.length / 5) : 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _trendData.length) return const Text('');
                        final date = _trendData[index].tanggal;
                        return Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_trendData.length - 1).toDouble(),
                minY: 0,
                maxY: maxVal * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.orange[800],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange[800]!.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.orange[800]!,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        return LineTooltipItem(
                          'Rp ${formatRupiah(s.y.toInt())}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart() {
    // Aggregate product sales
    final Map<String, int> productSales = {};
    for (var tx in _filteredTransaksi) {
      if (tx.jenis == 'pemasukan') {
        for (var item in tx.items) {
          final name = item.namaProduk ?? 'Produk';
          productSales.update(name, (val) => val + item.qty, ifAbsent: () => item.qty);
        }
      }
    }

    if (productSales.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Belum ada data penjualan produk', style: TextStyle(color: Colors.grey)),
      );
    }

    // Sort and take top 5
    final sortedEntries = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    final List<Color> colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.red[400]!,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Produk Terlaris', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: topEntries.asMap().entries.map((e) {
                        final i = e.key;
                        final entry = e.value;
                        return PieChartSectionData(
                          color: colors[i % colors.length],
                          value: entry.value.toDouble(),
                          title: '${entry.value}',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: topEntries.asMap().entries.map((e) {
                    final i = e.key;
                    final entry = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildTransactionList(List<Transaksi> transaksi) { ... removed ...

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
