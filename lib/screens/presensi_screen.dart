import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../database/presensi_repository.dart';
import '../models/presensi_model.dart';
import '../main.dart'; // To access the global cameras list
import '../widgets/app_image_view.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  final PresensiRepository _repo = PresensiRepository();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && cameras.isNotEmpty) {
      // Use native camera package for better desktop/mobile support
      final XFile? photo = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
      );
      if (photo != null) {
        setState(() {
          _image = photo;
        });
      }
      return;
    }

    // Fallback to image_picker for gallery or if no camera list available
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (photo != null) {
        setState(() {
          _image = photo;
        });
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('cameraDelegate')) {
        errorMessage = 'Kamera tidak didukung di platform ini. Silakan gunakan Galeri.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    // We now support camera even on Windows via the camera package
    // so we don't need to disable it if cameras list is not empty.
    final bool hasCamera = cameras.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Pilih Sumber Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: !hasCamera ? Colors.grey : null),
              title: Text(
                !hasCamera ? 'Kamera (Tidak terdeteksi)' : 'Kamera',
                style: TextStyle(color: !hasCamera ? Colors.grey : null),
              ),
              onTap: !hasCamera ? null : () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _simpanPresensi(String status) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan isi nama terlebih dahulu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan ambil foto terlebih dahulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final p = Presensi(
      namaKaryawan: _nameController.text.trim(),
      waktu: DateTime.now(),
      status: status,
      fotoPath: _image!.path,
    );

    await _repo.insert(p);

    setState(() {
      _image = null; // Reset setelah simpan
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Presensi $status berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Presensi Karyawan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Silakan isi nama dan ambil foto untuk bukti kehadiran',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Kolom Input Nama
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey[200]!, blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Karyawan (Wajib)',
                  hintText: 'Masukkan nama Anda...',
                  prefixIcon: const Icon(Icons.person, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange[200]!, width: 2),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AppImageView(
                          path: _image!.path,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 80, color: Colors.orange[300]),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[800],
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'Klik untuk Ambil Foto',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ambil Ulang Foto'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _simpanPresensi('Masuk'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Presensi Masuk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _simpanPresensi('Pulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Presensi Pulang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Catatan: Foto akan disimpan sebagai bukti kehadiran.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      // Find front camera as default
      for (int i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == CameraLensDirection.front) {
          _selectedCameraIndex = i;
          break;
        }
      }
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int index) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    
    _controller = CameraController(
      cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    setState(() {
      _initializeControllerFuture = _controller!.initialize();
    });
  }

  void _toggleCamera() {
    if (cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    _initCamera(_selectedCameraIndex);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kamera')),
        body: const Center(child: Text('Kamera tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambil Foto Presensi'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _toggleCamera,
              tooltip: 'Ganti Kamera',
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _controller != null && _controller!.value.isInitialized) {
            return Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            );
          } else if (snapshot.hasError) {
             return Center(child: Text('Gagal Memuat Kamera: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller!.takePicture();
            if (!mounted) return;
            Navigator.pop(context, image);
          } catch (e) {
            debugPrint('Error taking picture: $e');
          }
        },
      ),
    );
  }
}
