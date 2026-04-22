import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var path = await databaseFactory.getDatabasesPath();
  print('Database path: $path');
  
  var dbPath = '$path/kasirr.db';
  if (await File(dbPath).exists()) {
    print('Found kasirr.db at $dbPath');
  } else {
    print('kasirr.db NOT found at $dbPath');
    // Try current directory
    if (await File('kasirr.db').exists()) {
       print('Found kasirr.db in current directory');
    }
  }
}
