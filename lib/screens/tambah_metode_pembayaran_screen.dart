import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/metode_repository.dart';
import '../models/metode_pembayaran_model.dart';
import '../widgets/app_image_view.dart';

class TambahMetodePembayaranScreen extends StatefulWidget {
  final MetodePembayaran? metode;
  const TambahMetodePembayaranScreen({super.key, this.metode});

  @override
  State<TambahMetodePembayaranScreen> createState() => _TambahMetodePembayaranScreenState();
}

class _TambahMetodePembayaranScreenState extends State<TambahMetodePembayaranScreen> {
  late String _selectedTipe;
  late TextEditingController _namaController;
  late TextEditingController _nomorController;
  late TextEditingController _atasNamaController;
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  final MetodeRepository _repo = MetodeRepository();

  @override
  void initState() {
    super.initState();
    _selectedTipe = widget.metode?.tipe ?? 'QRIS';
    _namaController = TextEditingController(text: widget.metode?.nama ?? '');
    _nomorController = TextEditingController(text: widget.metode?.nomor ?? '');
    _atasNamaController = TextEditingController(text: widget.metode?.atasNama ?? '');
    
    if (widget.metode?.gambar != null && widget.metode!.gambar.isNotEmpty) {
      _imageFile = XFile(widget.metode!.gambar);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.metode == null ? 'Tambah Metode Pembayaran' : 'Edit Metode Pembayaran',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Selection
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    title: 'QRIS',
                    icon: Icons.qr_code_scanner,
                    isSelected: _selectedTipe == 'QRIS',
                    onTap: () => setState(() => _selectedTipe = 'QRIS'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTypeButton(
                    title: 'E-Wallet',
                    icon: Icons.account_balance_wallet,
                    isSelected: _selectedTipe == 'E-Wallet',
                    onTap: () => setState(() => _selectedTipe = 'E-Wallet'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Nama Metode
            _buildLabel('Nama Metode'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _namaController,
              hintText: 'Contoh: Dana, GoPay, QRIS BCA',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 24),

            // Nomor Rekening / ID
            _buildLabel('Nomor Rekening / ID'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nomorController,
              hintText: 'Masukkan nomor atau ID anda',
              icon: Icons.tag,
            ),
            const SizedBox(height: 24),

            // Nama Account
            _buildLabel('Nama Account (Atas Nama)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _atasNamaController,
              hintText: 'Contoh: Aditya Maulana',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 24),

            // Foto QRIS
            if (_selectedTipe == 'QRIS') ...[
              _buildLabel('Foto QRIS'),
              const SizedBox(height: 12),
              _buildImagePicker(),
              const SizedBox(height: 40),
            ] else
              const SizedBox(height: 16),

            // Simpan Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _simpanMetode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF25700), // Orange color from image
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Simpan Metode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1EB) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFF25700) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? const Color(0xFFF25700) : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? const Color(0xFFF25700) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: _imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppImageView(
                  path: _imageFile!.path,
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Pilih Foto atau Scan QRIS',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }

  void _simpanMetode() async {
    if (_namaController.text.isEmpty || _nomorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi data')),
      );
      return;
    }

    if (widget.metode != null) {
      // Update existing
      final m = widget.metode!.copyWith(
        nama: _namaController.text,
        tipe: _selectedTipe,
        nomor: _nomorController.text,
        atasNama: _atasNamaController.text,
        gambar: _imageFile?.path ?? widget.metode!.gambar,
      );
      await _repo.update(m);
    } else {
      // Add new
      final m = MetodePembayaran(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nama: _namaController.text,
        tipe: _selectedTipe,
        nomor: _nomorController.text,
        atasNama: _atasNamaController.text,
        gambar: _imageFile?.path ?? '', 
        isActive: true,
      );
      await _repo.insert(m);
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.metode == null ? 'Metode pembayaran berhasil disimpan' : 'Metode pembayaran berhasil diperbarui')),
      );
    }
  }
}
