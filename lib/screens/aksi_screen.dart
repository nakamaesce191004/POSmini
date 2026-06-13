import 'package:flutter/material.dart';
import 'manajemen_produk_screen.dart';
import 'uang_screen.dart';
import 'tambah_metode_pembayaran_screen.dart';
import 'metode_pembayaran_screen.dart';
import 'data_manajemen_screen.dart';
import 'manajemen_presensi_screen.dart';
import 'printer_settings_screen.dart';
import 'printer_settings_screen.dart';
import 'kalkulator_hpp_screen.dart';
import 'bahan_baku_screen.dart';
import 'meja_screen.dart';
import '../database/resep_repository.dart';
import '../models/resep_model.dart';

class AksiScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AksiScreen({super.key, this.onBack});

  @override
  State<AksiScreen> createState() => _AksiScreenState();
}

class _AksiScreenState extends State<AksiScreen> {
  final ResepRepository _repo = ResepRepository();
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStock();
  }

  Future<void> _checkStock() async {
    final allBahan = await _repo.getAllBahan();
    int count = 0;
    for (var b in allBahan) {
      if (b.totalBahan <= b.stokMinimal) {
        count++;
      }
    }
    if (mounted) {
      setState(() {
        _lowStockCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: const Text(
          'Menu Aksi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Manajemen Bisnis',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.inventory_2,
                  iconColor: Colors.blue[400]!,
                  iconBgColor: Colors.blue[50]!,
                  title: 'Manajemen Produk',
                  subtitle: 'Kelola daftar barang & harga jual',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManajemenProdukScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.calculate_outlined,
                  iconColor: Colors.deepOrange[400]!,
                  iconBgColor: Colors.deepOrange[50]!,
                  title: 'Kalkulator HPP',
                  subtitle: 'Hitung modal per item dari total belanja',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const KalkulatorHppScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.payment,
                  iconColor: Colors.blueGrey[400]!,
                  iconBgColor: Colors.blueGrey[50]!,
                  title: 'Metode Pembayaran',
                  subtitle: 'Kelola QRIS & tipe bayar',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MetodePembayaranScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.print,
                  iconColor: Colors.blue[400]!,
                  iconBgColor: Colors.blue[50]!,
                  title: 'Pengaturan Printer',
                  subtitle: 'Sambungkan printer thermal Bluetooth',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrinterSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.egg_outlined,
                  iconColor: Colors.orange[400]!,
                  iconBgColor: Colors.orange[50]!,
                  title: 'Purchasing ',
                  subtitle: 'Kelola bahan baku & harga modal',
                  trailing: _lowStockCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_lowStockCount Low',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BahanBakuScreen(),
                      ),
                    );
                    _checkStock(); // Refresh status setelah kembali
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.table_restaurant,
                  iconColor: Colors.teal[400]!,
                  iconBgColor: Colors.teal[50]!,
                  title: 'Manajemen Meja',
                  subtitle: 'Kelola nomor meja & status aktif',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MejaScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Administrasi Bisnis',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.deepOrange[400]!,
                  iconBgColor: Colors.deepOrange[50]!,
                  title: 'Catat Pengeluaran/Pemasukan',
                  subtitle: 'Input data keuangan manual',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UangScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.folder_zip,
                  iconColor: Colors.green[400]!,
                  iconBgColor: Colors.green[50]!,
                  title: 'Manajemen Data & Excel',
                  subtitle: 'Import/Export produk via Excel',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DataManajemenScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 64),
                _buildMenuItem(
                  context: context,
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: Colors.teal[400]!,
                  iconBgColor: Colors.teal[50]!,
                  title: 'Manajemen Presensi',
                  subtitle: 'Kelola data karyawan & riwayat kehadiran',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManajemenPresensiScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
