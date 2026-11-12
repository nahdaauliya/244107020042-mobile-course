import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../domain/entities/note.dart';

class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Catatan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(note.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            formatDateTime(note.updatedAt),
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 32),
          Text(
            note.body.isEmpty ? 'Tidak ada isi catatan.' : note.body,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
