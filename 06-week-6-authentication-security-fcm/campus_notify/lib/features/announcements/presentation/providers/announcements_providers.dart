import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/announcement_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/get_announcement_detail.dart';
import '../../domain/usecases/get_announcements.dart';

/// Composition root fitur: satu tempat untuk merakit dependency.
final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepositoryImpl(),
);

final getAnnouncementsProvider = Provider<GetAnnouncements>(
  (ref) => GetAnnouncements(ref.watch(announcementRepositoryProvider)),
);

final getAnnouncementDetailProvider = Provider<GetAnnouncementDetail>(
  (ref) => GetAnnouncementDetail(ref.watch(announcementRepositoryProvider)),
);

final announcementsProvider =
    AsyncNotifierProvider<AnnouncementsNotifier, List<Announcement>>(
  AnnouncementsNotifier.new,
);

class AnnouncementsNotifier extends AsyncNotifier<List<Announcement>> {
  @override
  Future<List<Announcement>> build() {
    return ref.watch(getAnnouncementsProvider).call();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getAnnouncementsProvider).call(),
    );
  }
}

/// Detail satu pengumuman berdasarkan id dari deep link / rute.
final announcementDetailProvider =
    FutureProvider.family<Announcement, String>((ref, id) {
  return ref.watch(getAnnouncementDetailProvider).call(id);
});
