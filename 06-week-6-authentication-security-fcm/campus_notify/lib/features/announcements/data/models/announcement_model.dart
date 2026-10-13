import '../../domain/entities/announcement.dart';

/// Representasi pengumuman pada layer data beserta konversi dari/ke JSON.
class AnnouncementModel extends Announcement {
  const AnnouncementModel({
    required super.id,
    required super.title,
    required super.body,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };

  Announcement toEntity() =>
      Announcement(id: id, title: title, body: body);
}
