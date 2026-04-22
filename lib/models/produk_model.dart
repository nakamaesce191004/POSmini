import 'package:flutter/material.dart';

class Produk {
  final String? id;
  final String nama;
  final String kategori;
  final int harga;
  final int hargaBeli;
  final int stok;
  final IconData gambar;

  Produk({
    this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    required this.hargaBeli,
    required this.stok,
    required this.gambar,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'harga': harga,
      'harga_beli': hargaBeli,
      'stok': stok,
      'icon_code': gambar.codePoint,
      'icon_font_family': gambar.fontFamily,
      'icon_font_package': gambar.fontPackage,
    };
  }

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: map['id']?.toString(),
      nama: map['nama'],
      kategori: map['kategori'],
      harga: map['harga'],
      hargaBeli: map['harga_beli'],
      stok: map['stok'],
      gambar: IconData(
        map['icon_code'],
        fontFamily: map['icon_font_family'],
        fontPackage: map['icon_font_package'],
      ),
    );
  }

  Produk copyWith({
    String? id,
    String? nama,
    String? kategori,
    int? harga,
    int? hargaBeli,
    int? stok,
    IconData? gambar,
  }) {
    return Produk(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      harga: harga ?? this.harga,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      stok: stok ?? this.stok,
      gambar: gambar ?? this.gambar,
    );
  }
}
