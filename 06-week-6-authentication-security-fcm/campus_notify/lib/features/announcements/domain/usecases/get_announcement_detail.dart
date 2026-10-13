import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

class GetAnnouncementDetail {
  const GetAnnouncementDetail(this._repository);

  final AnnouncementRepository _repository;

  Future<Announcement> call(String id) => _repository.getAnnouncementById(id);
}
