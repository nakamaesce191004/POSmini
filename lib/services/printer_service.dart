import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaksi_model.dart';
import '../utils/formatters.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _selectedPrinterName;
  String? _selectedPrinterId;
  String? get selectedPrinterName => _selectedPrinterName;
  
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  
  void _addLog(String msg) {
    String log = "[${DateTime.now().toString().substring(11, 19)}] $msg";
    _logs.add(log);
    debugPrint(log);
    if (_logs.length > 50) _logs.removeAt(0);
  }
  
  bool _autoPrint = false;
  bool get autoPrint => _autoPrint;
  
  String _storeName = "KASIR PINTAR";
  String _storeAddress = "Jl. Contoh No. 123";
  String get storeName => _storeName;
  String get storeAddress => _storeAddress;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedPrinterName = prefs.getString('printer_name');
      _selectedPrinterId = prefs.getString('printer_id');
      _autoPrint = prefs.getBool('auto_print') ?? false;
      _storeName = prefs.getString('store_name') ?? "KASIR PINTAR";
      _storeAddress = prefs.getString('store_address') ?? "";
      
      if (_isAndroid && _selectedPrinterId != null) {
        connect(_selectedPrinterId!); // Don't await connection during init
      }
    } catch (e) {
      _addLog("Service Init Error: $e");
    }
  }

  Future<void> setAutoPrint(bool value) async {
    _autoPrint = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_print', value);
  }

  Future<void> updateStoreInfo(String name, String address) async {
    _storeName = name;
    _storeAddress = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_name', name);
    await prefs.setString('store_address', address);
  }

  Future<void> savePrinter(String name, String id) async {
    _selectedPrinterName = name;
    _selectedPrinterId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_name', name);
      await prefs.setString('printer_id', id);
    } catch (e) {
      _addLog("Error saving printer: $e");
    }
  }

  Future<bool> checkBluetooth() async {
    if (!_isAndroid) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_isAndroid) return true;
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.locationWhenInUse,
      ].request();
      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      return false;
    }
  }

  Future<List<BluetoothInfo>> getBluetoothDevices() async {
    if (_isAndroid) {
      try {
        final bool perm = await requestPermissions();
        if (!perm) {
          debugPrint("Bluetooth permissions denied");
        }
        
        final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isEnabled) {
          debugPrint("Bluetooth is disabled");
        }

        // Kembali menggunakan pairedBluetooths karena getBluetooths tidak tersedia di versi ini
        final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
        debugPrint("Ditemukan ${devices.length} perangkat Bluetooth terpilih");
        return devices;
      } catch (e) {
        debugPrint("Error getting mobile devices: $e");
        return [];
      }
    } else {
      try {
        final List<Printer> systemPrinters = await Printing.listPrinters();
        // Filter out common virtual printers on Windows
        return systemPrinters
            .where((p) {
              final name = p.name.toLowerCase();
              return !name.contains('pdf') && 
                     !name.contains('onenote') && 
                     !name.contains('microsoft xps') && 
                     !name.contains('fax') &&
                     !name.contains('send to');
            })
            .map((p) => BluetoothInfo(
              name: p.name,
              macAdress: p.url,
            )).toList();
      } catch (e) {
        debugPrint("Error getting system printers: $e");
        return [];
      }
    }
  }

  Future<bool> connect(String macAddress) async {
    if (!_isAndroid) {
      if (_selectedPrinterName == null) {
        final printers = await Printing.listPrinters();
        try {
          final p = printers.firstWhere((p) => p.url == macAddress);
          await savePrinter(p.name, p.url);
        } catch (e) {}
      }
      _isConnected = true; 
      return true;
    }
    
    try {
      _addLog("Connecting to $macAddress...");
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _addLog("Connection result: $result");
      
      if (result) {
        _isConnected = true;
        final devices = await getBluetoothDevices();
        try {
          final d = devices.firstWhere((d) => d.macAdress == macAddress);
          await savePrinter(d.name, d.macAdress);
        } catch (e) {
          await savePrinter("Printer", macAddress);
        }
      }
      return result;
    } catch (e) {
      _addLog("Connection error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    if (!_isAndroid) return;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {}
  }

  Future<bool> printReceipt(Transaksi transaksi, String storeName) async {
    _addLog("Memulai proses cetak...");
    
    if (_isAndroid) {
      final bool currentlyConnected = await PrintBluetoothThermal.connectionStatus;
      _addLog("Status koneksi aktual: $currentlyConnected");
      _isConnected = currentlyConnected;
    }

    if (_isAndroid && _isConnected) {
       _addLog("Menggunakan mode ESC/POS...");
       return await _printEscPos(transaksi, storeName);
    } 
    
    _addLog("Menggunakan mode Universal (PDF)...");
    return await printReceiptUniversal(transaksi, storeName);
  }

  Future<bool> _printEscPos(Transaksi transaksi, String storeName) async {
    try {
      _addLog("Menyiapkan bytes ESC/POS...");
      List<int> bytes = [];
      
      // Gunakan profile default jika load() bermasalah
      CapabilityProfile profile;
      try {
        profile = await CapabilityProfile.load();
      } catch (e) {
        _addLog("Gagal load profile, menggunakan default: $e");
        profile = await CapabilityProfile.load(); // Coba lagi atau biarkan throw ke catch utama
      }
      
      final generator = Generator(PaperSize.mm58, profile);

      // Header: Store Name
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ));
      bytes += generator.text(storeName);
      
      // Header: Store Address (if any)
      if (_storeAddress.isNotEmpty) {
        bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
        bytes += generator.text(_storeAddress);
      }
      
      bytes += generator.hr();
      
      // Transaction Info
      bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
      final String safeId = transaksi.id ?? '---';
      final String displayId = safeId.length > 8 ? safeId.substring(safeId.length - 8) : safeId;
      bytes += generator.text('No. Transaksi: $displayId');
      bytes += generator.text('Waktu: ${transaksi.tanggal.toString().substring(0, 19)}');
      
      if (transaksi.pelanggan.isNotEmpty) {
        bytes += generator.text('Pelanggan: ${transaksi.pelanggan}');
      }
      if (transaksi.noMeja != null && transaksi.noMeja!.isNotEmpty) {
        bytes += generator.text('Meja/Kursi: ${transaksi.noMeja}');
      }
      bytes += generator.text('Kasir: Admin');
      bytes += generator.hr();

      // Items
      for (var item in transaksi.items) {
        bytes += generator.setStyles(const PosStyles(bold: true));
        bytes += generator.text(item.namaProduk ?? 'Produk');
        
        bytes += generator.setStyles(const PosStyles(bold: false));
        bytes += generator.row([
          PosColumn(text: '${item.qty} x ${formatRupiah(item.hargaSaatIni)}', width: 7),
          PosColumn(text: formatRupiah(item.qty * item.hargaSaatIni), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      
      // Subtotal calculation logic for receipt
      int subtotalHeader = transaksi.nominal + transaksi.diskon - transaksi.pajak;
      
      bytes += generator.row([
        PosColumn(text: 'SUBTOTAL', width: 6),
        PosColumn(text: formatRupiah(subtotalHeader), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (transaksi.diskon > 0) {
        bytes += generator.row([
          PosColumn(text: 'DISKON ${transaksi.diskonInfo != null ? "(${transaksi.diskonInfo})" : ""}', width: 8),
          PosColumn(text: '-${formatRupiah(transaksi.diskon)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      
      if (transaksi.pajak > 0) {
        bytes += generator.row([
          PosColumn(text: 'PAJAK ${transaksi.pajakInfo != null ? "(${transaksi.pajakInfo})" : ""}', width: 8),
          PosColumn(text: '+${formatRupiah(transaksi.pajak)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      
      // Totals
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Rp ${formatRupiah(transaksi.nominal)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      
      bytes += generator.text('Metode: ${transaksi.metode}');
      bytes += generator.hr();
      
      // Footer
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.text('Terima Kasih Atas Kunjungan Anda');
      bytes += generator.text('Barang yang sudah dibeli');
      bytes += generator.text('tidak dapat ditukar/dikembalikan');
      
      bytes += generator.feed(3);
      bytes += generator.cut();

      debugPrint("Mengirim ${bytes.length} bytes ke printer...");
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      debugPrint("Hasil writeBytes: $result");
      return result;
    } catch (e, stack) {
      debugPrint("Print Error: $e");
      debugPrint("Stack Trace: $stack");
      return false;
    }
  }

  Future<pw.Document> generateReceiptPdf(Transaksi transaksi, String storeName) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(storeName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('No. Transaksi: ${transaksi.id}'),
              pw.Text('Waktu: ${transaksi.tanggal.toString().substring(0, 19)}'),
              if (transaksi.pelanggan.isNotEmpty) pw.Text('Pelanggan: ${transaksi.pelanggan}'),
              if (transaksi.noMeja != null && transaksi.noMeja!.isNotEmpty) pw.Text('Meja/Kursi: ${transaksi.noMeja}'),
              pw.Text('Kasir: Admin'),
              pw.Divider(),
              ...transaksi.items.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${item.qty}x ${item.namaProduk}'),
                  pw.Text(formatRupiah(item.qty * item.hargaSaatIni)),
                ],
              )),
              pw.Divider(),
              if (transaksi.diskon > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Diskon ${transaksi.diskonInfo != null ? "(${transaksi.diskonInfo})" : ""}'),
                    pw.Text('-${formatRupiah(transaksi.diskon)}'),
                  ],
                ),
              if (transaksi.pajak > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Pajak ${transaksi.pajakInfo != null ? "(${transaksi.pajakInfo})" : ""}'),
                    pw.Text('+${formatRupiah(transaksi.pajak)}'),
                  ],
                ),
              if (transaksi.diskon > 0 || transaksi.pajak > 0) pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rp ${formatRupiah(transaksi.nominal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  Future<bool> printReceiptUniversal(Transaksi transaksi, String storeName) async {
    try {
      final doc = await generateReceiptPdf(transaksi, storeName);

      Printer? targetPrinter;
      if (_selectedPrinterId != null && !kIsWeb) {
        final printers = await Printing.listPrinters();
        try {
          targetPrinter = printers.firstWhere((p) => p.url == _selectedPrinterId || p.name == _selectedPrinterName);
        } catch (e) {}
      }

      if (targetPrinter != null) {
        await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) => doc.save(),
          name: 'Struk_${transaksi.id}',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) => doc.save(),
          name: 'Struk_${transaksi.id}',
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> printPdfDocument(pw.Document doc, String documentName) async {
    try {
      Printer? targetPrinter;
      if (_selectedPrinterId != null && !kIsWeb) {
        final printers = await Printing.listPrinters();
        try {
          targetPrinter = printers.firstWhere((p) => p.url == _selectedPrinterId || p.name == _selectedPrinterName);
        } catch (e) {}
      }

      if (targetPrinter != null) {
        await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) => doc.save(),
          name: documentName,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) => doc.save(),
          name: documentName,
        );
      }
      return true;
    } catch (e) {
      _addLog("Print PDF Document Error: $e");
      return false;
    }
  }
}
