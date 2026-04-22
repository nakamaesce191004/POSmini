class MetodePembayaran {
  final String? id;
  final String nama;
  final String tipe;
  final String nomor;
  final String atasNama;
  final String gambar;
  final bool isActive;

  MetodePembayaran({
    this.id,
    required this.nama,
    required this.tipe,
    required this.nomor,
    required this.atasNama,
    required this.gambar,
    required this.isActive,
  });
  MetodePembayaran copyWith({
    String? id,
    String? nama,
    String? tipe,
    String? nomor,
    String? atasNama,
    String? gambar,
    bool? isActive,
  }) {
    return MetodePembayaran(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      tipe: tipe ?? this.tipe,
      nomor: nomor ?? this.nomor,
      atasNama: atasNama ?? this.atasNama,
      gambar: gambar ?? this.gambar,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'tipe': tipe,
      'nomor': nomor,
      'atasNama': atasNama,
      'gambar': gambar,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory MetodePembayaran.fromMap(Map<String, dynamic> map) {
    return MetodePembayaran(
      id: map['id']?.toString(),
      nama: map['nama'],
      tipe: map['tipe'],
      nomor: map['nomor'],
      atasNama: map['atasNama'],
      gambar: map['gambar'],
      isActive: map['isActive'] == 1,
    );
  }
}
