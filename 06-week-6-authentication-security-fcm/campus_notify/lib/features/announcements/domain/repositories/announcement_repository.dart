import '../entities/announcement.dart';

/// Kontrak sumber pengumuman. Lapisan presentation dan use case hanya
/// bergantung pada abstraksi ini, bukan pada implementasi di layer data.
abstract class AnnouncementRepository {
  Future<List<Announcement>> getAnnouncements();

  Future<Announcement> getAnnouncementById(String id);
}
