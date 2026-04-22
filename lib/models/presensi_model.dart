class Presensi {
  final String? id;
  final String namaKaryawan;
  final DateTime waktu;
  final String status; // 'masuk', 'pulang'
  final String? fotoPath;

  Presensi({
    this.id,
    required this.namaKaryawan,
    required this.waktu,
    required this.status,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_karyawan': namaKaryawan,
      'waktu': waktu.toIso8601String(),
      'status': status,
      'foto_path': fotoPath,
    };
  }

  factory Presensi.fromMap(Map<String, dynamic> map) {
    return Presensi(
      id: map['id']?.toString(),
      namaKaryawan: map['nama_karyawan'],
      waktu: DateTime.parse(map['waktu']),
      status: map['status'],
      fotoPath: map['foto_path'],
    );
  }
}
