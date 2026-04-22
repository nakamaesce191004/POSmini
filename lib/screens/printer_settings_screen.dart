import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/printer_service.dart';
import '../models/transaksi_model.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selectedDevice;
  bool _isScanning = false;
  bool _hasBluetoothPermission = false;
  bool _isBluetoothOn = false;
  String _debugLogs = "--- Log Diagnosa Printer ---\n";
  final ScrollController _logScrollController = ScrollController();
  
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  void _updateLogs() {
    if (mounted) {
      setState(() {
        _debugLogs = "--- Log Diagnosa Printer ---\n" + _printerService.logs.join("\n");
      });
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _addLog(String msg) {
    _updateLogs();
  }

  @override
  void initState() {
    super.initState();
    _storeNameController.text = _printerService.storeName;
    _storeAddressController.text = _printerService.storeAddress;
    _checkStatusAndScan();
  }

  Future<void> _checkStatusAndScan() async {
    _addLog("Mengecek izin Bluetooth...");
    final bool perm = await _printerService.requestPermissions();
    final bool on = await _printerService.checkBluetooth();
    
    _addLog("Izin: ${perm ? 'Diberikan' : 'Ditolak'}");
    _addLog("Bluetooth HP: ${on ? 'Aktif' : 'Mati'}");
    if (mounted) {
      setState(() {
        _hasBluetoothPermission = perm;
        _isBluetoothOn = on;
      });
      if (perm && on) {
        _scanDevices();
      }
    }
  }

  Future<void> _scanDevices() async {
    _addLog("Memulai pencarian printer...");
    setState(() => _isScanning = true);
    final results = await _printerService.getBluetoothDevices();
    _addLog("Ditemukan ${results.length} perangkat.");
    for (var d in results) {
      _addLog("Found: ${d.name} (${d.macAdress})");
    }
    if (mounted) {
      setState(() {
        _devices = results;
        _isScanning = false;
        // Auto select if already connected
        if (_printerService.isConnected && _printerService.selectedPrinterName != null) {
          try {
            _selectedDevice = _devices.firstWhere((d) => d.name == _printerService.selectedPrinterName);
          } catch (e) {}
        }
      });

      if (results.isEmpty && _isAndroid) {
        _showNoDeviceDialog();
      }
    }
  }

  void _showNoDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Printer Tidak Ditemukan'),
        content: const Text(
          'Pastikan printer sudah menyala dan sudah "Dipasangkan" (Paired) lewat Pengaturan Bluetooth HP Anda.\n\nJika belum dipasangkan, printer tidak akan muncul di aplikasi ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK Saya Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih printer dulu!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final bool isEnabled = await _printerService.checkBluetooth();
    if (!isEnabled && _isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth Mati! Silakan nyalakan Bluetooth Anda.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    _addLog("Menyambungkan ke ${_selectedDevice!.name}...");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Menyambungkan ke ${_selectedDevice!.name}...')));
    
    try {
      final ok = await _printerService.connect(_selectedDevice!.macAdress);
      _addLog("Hasil koneksi: ${ok ? 'SUKSES' : 'GAGAL'}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Printer Tersambung!' : 'Gagal Menyambung'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      _addLog("Error Koneksi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF25700), Color(0xFFFF8E53)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Pengaturan Printer',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _buildStatusBanner(),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Izin (Baru)
                  _buildPermissionStatus(),
                  const SizedBox(height: 24),

                  const Text('Pilih Perangkat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                  const SizedBox(height: 12),
                  
                  // Device Dropdown/Selector
                  _buildDeviceSelector(),

                  const SizedBox(height: 32),
                  const Text('Aksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                  const SizedBox(height: 12),

                  // Action Buttons
                  _buildActionButton(
                    label: _printerService.isConnected ? 'Putus Koneksi' : 'Hubungkan Printer',
                    icon: Icons.bluetooth,
                    color: _printerService.isConnected ? Colors.red : const Color(0xFF9E9E9E),
                    onPressed: _printerService.isConnected 
                      ? () async { await _printerService.disconnect(); setState(() {}); }
                      : _connect,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    label: 'Cetak Test Struk',
                    icon: Icons.print,
                    color: Colors.green,
                    outline: true,
                    onPressed: _printerService.isConnected ? _printTest : null,
                  ),
                  const SizedBox(height: 12),
                  
                  // Auto Print Switch
                  _buildAutoPrintSwitch(),
                  
                  const SizedBox(height: 32),
                  const Text('Informasi Toko', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                  const SizedBox(height: 12),
                  _buildStoreInfoFields(),

                  const SizedBox(height: 40),
                  
                  // Connection Tips
                  _buildTipsCard(),
                  
                  const SizedBox(height: 24),
                  const Text('Log Diagnosa Sistem', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _buildDebugConsole(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanDevices,
        backgroundColor: const Color(0xFFFF8E53),
        child: _isScanning 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final bool isConnected = _printerService.isConnected;
    return Container(
      width: double.infinity,
      color: isConnected ? Colors.green[50] : Colors.red[50],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error_outline,
            color: isConnected ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected 
              ? 'Printer Terhubung ke ${_printerService.selectedPrinterName}' 
              : 'Printer Belum Terhubung',
            style: TextStyle(
              color: isConnected ? Colors.green[700] : Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BluetoothInfo>(
          hint: const Text('Cari Printer Thermal...'),
          isExpanded: true,
          value: _selectedDevice,
          items: _devices.map((device) {
            return DropdownMenuItem(
              value: device,
              child: Text(device.name),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedDevice = val);
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool outline = false,
  }) {
    final bool isDisabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: outline ? color : Colors.white),
        label: Text(
          label,
          style: TextStyle(
            color: outline ? color : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: outline ? Colors.white : color,
          disabledBackgroundColor: Colors.grey[300],
          elevation: outline ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: outline ? BorderSide(color: isDisabled ? Colors.grey[300]! : color) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD591)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange[800], size: 24),
              const SizedBox(width: 8),
              Text('Tips Koneksi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900], fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          _tipItem('1. Hidupkan Bluetooth.'),
          _tipItem('2. Pastikan printer sudah "Paired".'),
          _tipItem('3. Jika tidak muncul, tekan tombol refresh.'),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.orange[900], fontSize: 14),
      ),
    );
  }

  Widget _buildPermissionStatus() {
    if (!_isAndroid) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hasBluetoothPermission ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_hasBluetoothPermission ? Icons.lock_open : Icons.lock_outline, color: _hasBluetoothPermission ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasBluetoothPermission ? 'Izin Bluetooth: Diberikan' : 'Izin Bluetooth: Ditolak',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _hasBluetoothPermission ? Colors.green : Colors.red),
                    ),
                    Text(
                      _hasBluetoothPermission ? 'Aplikasi siap mencari printer.' : 'Klik tombol di bawah untuk izinkan.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (!_hasBluetoothPermission)
                ElevatedButton(
                  onPressed: _checkStatusAndScan,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('Izinkan'),
                ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(_isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled, color: _isBluetoothOn ? Colors.blue : Colors.grey),
              const SizedBox(width: 12),
              Text(
                _isBluetoothOn ? 'Bluetooth HP: Menyala' : 'Bluetooth HP: Mati',
                style: TextStyle(fontWeight: FontWeight.bold, color: _isBluetoothOn ? Colors.blue : Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugConsole() {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: SingleChildScrollView(
        controller: _logScrollController,
        child: Text(
          _debugLogs,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildAutoPrintSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Cetak otomatis setelah bayar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          Switch(
            value: _printerService.autoPrint,
            onChanged: (val) async {
              await _printerService.setAutoPrint(val);
              setState(() {});
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoFields() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _storeNameController,
            onChanged: (val) => _printerService.updateStoreInfo(val, _storeAddressController.text),
            decoration: const InputDecoration(
              labelText: 'Nama Toko (Header)',
              hintText: 'Masukkan nama toko...',
              icon: Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeAddressController,
            onChanged: (val) => _printerService.updateStoreInfo(_storeNameController.text, val),
            decoration: const InputDecoration(
              labelText: 'Alamat Toko',
              hintText: 'Jl. Contoh No. 123...',
              icon: Icon(Icons.location_on),
            ),
          ),
        ],
      ),
    );
  }

  void _printTest() async {
    _addLog("Memulai Cetak Test Struk...");
    final fakeTrx = Transaksi(
      id: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      nominal: 10000,
      tanggal: DateTime.now(),
      metode: 'Tunai',
      items: [
        TransaksiItem(transaksiId: 'TEST', produkId: 'TEST', qty: 1, hargaSaatIni: 5000, namaProduk: 'Produk A'),
        TransaksiItem(transaksiId: 'TEST', produkId: 'TEST', qty: 1, hargaSaatIni: 5000, namaProduk: 'Produk B'),
      ],
      jenis: 'pemasukan',
      deskripsi: 'Cetak Uji Coba',
      pelanggan: 'Pelanggan Umum',
    );
    final ok = await _printerService.printReceipt(fakeTrx, _printerService.storeName);
    _addLog("Hasil Cetak Test: ${ok ? 'BERHASIL' : 'GAGAL'}");
  }
}
