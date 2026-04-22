import 'package:flutter/material.dart';
import '../database/metode_repository.dart';
import '../models/metode_pembayaran_model.dart';
import 'tambah_metode_pembayaran_screen.dart';

class MetodePembayaranScreen extends StatefulWidget {
  const MetodePembayaranScreen({super.key});

  @override
  State<MetodePembayaranScreen> createState() => _MetodePembayaranScreenState();
}

class _MetodePembayaranScreenState extends State<MetodePembayaranScreen> {
  final MetodeRepository _repo = MetodeRepository();
  List<MetodePembayaran> _allMetode = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAll();
    if (mounted) {
      setState(() {
        _allMetode = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Metode Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _allMetode.isEmpty ? _buildEmptyState() : _buildListState(),
      floatingActionButton: _allMetode.isEmpty 
        ? null 
        : _buildAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _allMetode.isEmpty ? Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildAddButton(),
      ) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum ada metode pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Klik tombol di bawah untuk menambah',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allMetode.length,
      itemBuilder: (context, index) {
        final metode = _allMetode[index];
        final bool isActive = metode.isActive;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F1), // Light peach/orange background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Row(
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8DD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  metode.tipe == 'QRIS' ? Icons.qr_code_scanner : Icons.account_balance_wallet,
                  color: const Color(0xFFF25700),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metode.nama,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User: ${metode.atasNama}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      'No: ${metode.nomor}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              // Switch
              Switch(
                value: isActive,
                onChanged: (val) async {
                  final update = metode.copyWith(isActive: val);
                  await _repo.update(update);
                  _loadData();
                },
                activeColor: const Color(0xFFF25700),
                activeTrackColor: const Color(0xFFFFCCB3),
              ),
              
              // Edit Icon
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TambahMetodePembayaranScreen(metode: metode),
                    ),
                  );
                  _loadData();
                },
              ),
              
              // Delete Icon
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Metode'),
                      content: Text('Apakah Anda yakin ingin menghapus metode ${metode.nama}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _repo.delete(metode.id!);
                            if (mounted) Navigator.pop(context);
                            _loadData();
                          },
                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TambahMetodePembayaranScreen(),
            ),
          );
          _loadData();
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Metode',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF25700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
