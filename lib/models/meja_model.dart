class Meja {
  final String id;
  final String nama;
  final String? kategori;
  final bool isActive;

  Meja({
    required this.id,
    required this.nama,
    this.kategori,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Meja.fromMap(Map<String, dynamic> map) {
    return Meja(
      id: map['id'],
      nama: map['nama'],
      kategori: map['kategori'],
      isActive: map['isActive'] == 1,
    );
  }

  Meja copyWith({
    String? id,
    String? nama,
    String? kategori,
    bool? isActive,
  }) {
    return Meja(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      isActive: isActive ?? this.isActive,
    );
  }
}
