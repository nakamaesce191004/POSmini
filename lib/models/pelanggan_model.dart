class Pelanggan {
  final String? id;
  final String nama;
  final String? telepon;
  final String? alamat;

  Pelanggan({
    this.id,
    required this.nama,
    this.telepon,
    this.alamat,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'telepon': telepon,
      'alamat': alamat,
    };
  }

  factory Pelanggan.fromMap(Map<String, dynamic> map) {
    return Pelanggan(
      id: map['id']?.toString(),
      nama: map['nama'],
      telepon: map['telepon'],
      alamat: map['alamat'],
    );
  }
}
