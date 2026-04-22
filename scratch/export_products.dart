import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var path = await databaseFactory.getDatabasesPath();
  var dbPath = '$path/kasirr.db';
  
  if (!(await File(dbPath).exists())) {
    print('Error: Database not found at $dbPath');
    return;
  }

  var db = await databaseFactory.openDatabase(dbPath);
  print('--- Exporting Product Data ---');
  
  try {
    List<Map<String, dynamic>> products = await db.query('produk');
    
    if (products.isEmpty) {
      print('No products found in database.');
      return;
    }

    var csvContent = 'ID,Nama,Kategori,Harga,Harga Beli,Stok\n';
    for (var p in products) {
      csvContent += '${p['id']},"${p['nama']}","${p['kategori']}",${p['harga']},${p['harga_beli']},${p['stok']}\n';
    }

    final exportFile = File('produk_export.csv');
    await exportFile.writeAsString(csvContent);
    print('Successfully exported ${products.length} products to ${exportFile.path}');
    
    // Also print for quick view
    print('\nPreview:');
    print(csvContent);
  } catch (e) {
    print('Error during export: $e');
  } finally {
    await db.close();
  }
}
