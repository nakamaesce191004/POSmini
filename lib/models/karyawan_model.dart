class Karyawan {
  final String id;
  final String nama;
  final String? posisi;
  final String? telepon;

  Karyawan({
    required this.id,
    required this.nama,
    this.posisi,
    this.telepon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'posisi': posisi,
      'telepon': telepon,
    };
  }

  factory Karyawan.fromMap(Map<String, dynamic> map) {
    return Karyawan(
      id: map['id'],
      nama: map['nama'],
      posisi: map['posisi'],
      telepon: map['telepon'],
    );
  }
}
