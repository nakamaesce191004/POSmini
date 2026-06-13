class Transaksi {
  final String? id;
  final String jenis; // 'pemasukan' or 'pengeluaran'
  final int nominal;
  final DateTime tanggal;
  final String deskripsi;
  final String pelanggan;
  final String metode;
  final int diskon;
  final int pajak;
  final String? diskonInfo;
  final String? pajakInfo;
  final List<TransaksiItem> items;

  final String? noMeja;
  final String status; // 'Selesai' (Sudah Bayar) atau 'Pending' (Belum Bayar)
  final bool isPrinted;
  final bool isSettled;

  Transaksi({
    this.id,
    required this.jenis,
    required this.nominal,
    required this.tanggal,
    required this.deskripsi,
    required this.pelanggan,
    required this.metode,
    this.diskon = 0,
    this.pajak = 0,
    this.diskonInfo,
    this.pajakInfo,
    this.noMeja,
    this.status = 'Selesai',
    this.isPrinted = false,
    this.isSettled = false,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis,
      'nominal': nominal,
      'tanggal': tanggal.toIso8601String(),
      'deskripsi': deskripsi,
      'pelanggan': pelanggan,
      'metode': metode,
      'diskon': diskon,
      'pajak': pajak,
      'diskon_info': diskonInfo,
      'pajak_info': pajakInfo,
      'no_meja': noMeja,
      'status': status,
      'is_printed': isPrinted ? 1 : 0,
      'is_settled': isSettled ? 1 : 0,
    };
  }

  factory Transaksi.fromMap(Map<String, dynamic> map, List<TransaksiItem> items) {
    return Transaksi(
      id: map['id']?.toString(),
      jenis: map['jenis'],
      nominal: map['nominal'],
      tanggal: DateTime.parse(map['tanggal']),
      deskripsi: map['deskripsi'],
      pelanggan: map['pelanggan'],
      metode: map['metode'],
      diskon: map['diskon'] ?? 0,
      pajak: map['pajak'] ?? 0,
      diskonInfo: map['diskon_info'],
      pajakInfo: map['pajak_info'],
      noMeja: map['no_meja'],
      status: map['status'] ?? 'Selesai',
      isPrinted: (map['is_printed'] ?? 0) == 1,
      isSettled: (map['is_settled'] ?? 0) == 1,
      items: items,
    );
  }
}

class TransaksiItem {
  final String? id;
  final String transaksiId;
  final String produkId;
  final int qty;
  final int hargaSaatIni;
  final String? namaProduk; // Optional: for display without joining

  TransaksiItem({
    this.id,
    required this.transaksiId,
    required this.produkId,
    required this.qty,
    required this.hargaSaatIni,
    this.namaProduk,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaksi_id': transaksiId,
      'produk_id': produkId,
      'qty': qty,
      'harga_saat_ini': hargaSaatIni,
    };
  }

  factory TransaksiItem.fromMap(Map<String, dynamic> map) {
    return TransaksiItem(
      id: map['id']?.toString(),
      transaksiId: map['transaksi_id'].toString(),
      produkId: map['produk_id'].toString(),
      qty: map['qty'],
      hargaSaatIni: map['harga_saat_ini'],
      namaProduk: map['nama'], // if joined with product table
    );
  }
}
