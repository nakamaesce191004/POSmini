class BahanBaku {
  final String? id;
  final String nama;
  final int totalBelanja;
  final double totalBahan;
  final String satuan;
  final double hargaPerSatuan;

  BahanBaku({
    this.id,
    required this.nama,
    required this.totalBelanja,
    required this.totalBahan,
    required this.satuan,
    required this.hargaPerSatuan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'total_belanja': totalBelanja,
      'total_bahan': totalBahan,
      'satuan': satuan,
      'harga_per_satuan': hargaPerSatuan,
    };
  }

  factory BahanBaku.fromMap(Map<String, dynamic> map) {
    return BahanBaku(
      id: map['id'],
      nama: map['nama'],
      totalBelanja: map['total_belanja'],
      totalBahan: map['total_bahan'],
      satuan: map['satuan'],
      hargaPerSatuan: map['harga_per_satuan'],
    );
  }
}

class Resep {
  final int? id;
  final String produkId;
  final String bahanId;
  final double qty;
  // Extra fields for UI convenience
  final String? namaBahan;
  final double? hargaPerSatuan;
  final String? satuan;

  Resep({
    this.id,
    required this.produkId,
    required this.bahanId,
    required this.qty,
    this.namaBahan,
    this.hargaPerSatuan,
    this.satuan,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'produk_id': produkId,
      'bahan_id': bahanId,
      'qty': qty,
    };
  }

  factory Resep.fromMap(Map<String, dynamic> map) {
    return Resep(
      id: map['id'],
      produkId: map['produk_id'],
      bahanId: map['bahan_id'],
      qty: map['qty'],
      namaBahan: map['nama_bahan'],
      hargaPerSatuan: map['harga_per_satuan'],
      satuan: map['satuan'],
    );
  }

  double get totalHppContribution => qty * (hargaPerSatuan ?? 0);
}
