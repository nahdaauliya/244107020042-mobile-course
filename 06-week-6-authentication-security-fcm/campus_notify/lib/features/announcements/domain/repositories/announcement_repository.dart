import '../entities/announcement.dart';

/// Kontrak sumber pengumuman. Implementasi disediakan layer data.
abstract class AnnouncementRepository {
  Future<List<Announcement>> getAnnouncements();

  Future<Announcement> getAnnouncementById(String id);
}
