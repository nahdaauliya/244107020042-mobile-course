import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/announcements_providers.dart';

class AnnouncementPage extends ConsumerWidget {
  final String id;
  const AnnouncementPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementAsync = ref.watch(announcementDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Announcement #$id'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: announcementAsync.when(
            data: (announcement) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  announcement.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            error: (error, stackTrace) => Text(
              'Gagal memuat pengumuman: $error',
              textAlign: TextAlign.center,
            ),
            loading: () => const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
