import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/announcement_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/get_announcements.dart';

/// Composition root fitur announcements.
final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepositoryImpl(),
);

final getAnnouncementsProvider = Provider<GetAnnouncements>(
  (ref) => GetAnnouncements(ref.watch(announcementRepositoryProvider)),
);

final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(getAnnouncementsProvider).call(),
);

final announcementDetailProvider =
    FutureProvider.family<Announcement, String>(
  (ref, id) => ref.watch(announcementRepositoryProvider).getAnnouncementById(id),
);
