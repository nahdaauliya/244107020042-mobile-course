import '../../../../core/failures.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../models/announcement_model.dart';

/// Implementasi repository berbasis sumber data lokal. Isi pengumuman yang
/// sebelumnya ditulis langsung di halaman kini dipindahkan ke layer data.
class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl({List<Map<String, dynamic>>? source})
      : _source = source ?? _defaultSource;

  final List<Map<String, dynamic>> _source;

  static const List<Map<String, dynamic>> _defaultSource = [
    {
      'id': '1',
      'title': 'Perkuliahan Daring',
      'body': 'Seluruh perkuliahan hari Jumat dilaksanakan secara daring.',
    },
    {
      'id': '2',
      'title': 'Jadwal UTS',
      'body': 'Ujian Tengah Semester dimulai pada Senin pekan depan.',
    },
    {
      'id': '3',
      'title': 'Announcement Detail #3',
      'body': 'Schedule changed: Mobile class moved to Room A2 at 1:00 PM',
    },
  ];

  @override
  Future<List<Announcement>> getAnnouncements() async {
    try {
      return _source
          .map((json) => AnnouncementModel.fromJson(json).toEntity())
          .toList(growable: false);
    } catch (_) {
      throw const CacheFailure();
    }
  }

  @override
  Future<Announcement> getAnnouncementById(String id) async {
    try {
      final match =
          _source.where((json) => json['id'].toString() == id).toList();
      if (match.isEmpty) {
        throw const NotFoundFailure();
      }
      return AnnouncementModel.fromJson(match.first).toEntity();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const CacheFailure();
    }
  }
}
