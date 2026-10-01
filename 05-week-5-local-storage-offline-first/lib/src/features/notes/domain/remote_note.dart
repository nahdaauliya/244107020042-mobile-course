/// Representasi catatan di sisi server.
///
/// Sengaja dipisah dari [Note] (domain): bentuk di jaringan tidak boleh bocor
/// ke lapisan lokal. Field `revision` adalah penanda versi milik server yang
/// dipakai untuk mendeteksi perubahan dari perangkat lain.
class RemoteNote {
  const RemoteNote({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.deleted = false,
    this.revision = 1,
  });

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;
  final bool deleted;
  final int revision;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
        'deleted': deleted,
        'revision': revision,
      };

  factory RemoteNote.fromJson(Map<String, Object?> json) {
    return RemoteNote(
      id: json['id'] is String ? json['id']! as String : '',
      title: json['title'] is String ? json['title']! as String : '',
      body: json['body'] is String ? json['body']! as String : '',
      updatedAt: json['updated_at'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updated_at']! as num).toInt(),
              isUtc: true,
            )
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deleted: json['deleted'] == true,
      revision: json['revision'] is num ? (json['revision']! as num).toInt() : 1,
    );
  }

  @override
  String toString() => 'RemoteNote($id, rev=$revision, deleted=$deleted)';
}