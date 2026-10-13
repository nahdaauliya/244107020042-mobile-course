import '../../../../core/failures.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../models/announcement_model.dart';

/// Implementasi repository berbasis sumber data lokal. Exception mentah
/// ditangkap dan diubah menjadi [Failure] yang ramah pengguna.
class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl({List<Map<String, dynamic>>? source})
      : _source = source ?? _defaultSource;

  final List<Map<String, dynamic>> _source;

  static final List<Map<String, dynamic>> _defaultSource = [
    {
      'id': '1',
      'title': 'Perkuliahan Daring',
      'body': 'Seluruh perkuliahan hari Jumat dilaksanakan secara daring.',
      'published_at': DateTime(2026, 10, 12, 8).toIso8601String(),
    },
    {
      'id': '2',
      'title': 'Jadwal UTS',
      'body': 'Ujian Tengah Semester dimulai pada Senin pekan depan.',
      'published_at': DateTime(2026, 10, 13, 9, 30).toIso8601String(),
    },
    {
      'id': '3',
      'title': 'Announcement Detail #3',
      'body': 'Schedule changed: Mobile class moved to Room A2 at 1:00 PM',
      'published_at': DateTime(2026, 10, 14, 13).toIso8601String(),
    },
  ];

  @override
  Future<List<Announcement>> getAnnouncements() async {
    try {
      return _source
          .map((json) => AnnouncementModel.fromJson(json).toEntity())
          .toList(growable: false);
    } catch (_) {
      throw const LocalFailure('Gagal memuat daftar pengumuman.');
    }
  }

  @override
  Future<Announcement> getAnnouncementById(String id) async {
    try {
      final match =
          _source.where((json) => json['id'].toString() == id).toList();
      if (match.isEmpty) {
        throw const NotFoundFailure('Pengumuman tidak ditemukan.');
      }
      return AnnouncementModel.fromJson(match.first).toEntity();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const LocalFailure('Gagal memuat pengumuman.');
    }
  }
}
