/// Model `Comment` untuk endpoint `GET /comments?postId={id}`
/// dari JSONPlaceholder (https://jsonplaceholder.typicode.com).
class Comment {
  /// ID post (postingan) tempat komentar ini berada.
  final int? postId;

  /// ID unik dari komentar.
  final int? id;

  /// Nama orang yang memberikan komentar.
  final String? name;

  /// Alamat email dari pemberi komentar.
  final String? email;

  /// Isi / teks komentar.
  final String? body;

  const Comment({
    this.postId,
    this.id,
    this.name,
    this.email,
    this.body,
  });

  /// Membuat [Comment] dari JSON yang dikirim server.
  ///
  /// Aman terhadap null: jika sebuah field tidak ada di JSON
  /// atau bernilai `null`, nilai field model tetap `null`
  /// tanpa melempar error (no crash saat parsing).
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      // Konversi int yang defensif: jika nilainya bukan angka
      // (mis. string 'abc' atau null), helper [_asInt] mengembalikan null.
      postId: _asInt(json['postId']),
      id: _asInt(json['id']),
      // `as String?` pada key yang hilang menghasilkan null (aman),
      // sehingga tidak memunculkan exception TypeCast saat field primitif.
      name: json['name'] as String?,
      email: json['email'] as String?,
      body: json['body'] as String?,
    );
  }

  /// Helper yang aman untuk mengubah nilai JSON menjadi [int].
  /// Nilai `null`, non-angka, atau yang gagal di-parse => dianggap null.
  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}