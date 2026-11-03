import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../providers/notes_providers.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(notesSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(notesSearchQueryProvider.notifier).update('');
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(filteredNotesProvider);
    final allNotesAsync = ref.watch(notesProvider);
    final query = ref.watch(notesSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: ref.read(notesSearchQueryProvider.notifier).update,
              decoration: InputDecoration(
                hintText: 'Cari judul catatan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Hapus pencarian',
                        onPressed: _clearSearch,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Gagal memuat catatan: $error')),
        data: (notes) {
          if (notes.isEmpty) {
            final noNotes = allNotesAsync.value?.isEmpty ?? true;
            return Center(
              child: Text(
                noNotes
                    ? 'Belum ada catatan.'
                    : 'Tidak ada catatan dengan judul "$query".',
              ),
            );
          }
          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              final updated = formatDateTime(note.updatedAt);
              return ListTile(
                title: Text(note.title),
                subtitle: Text(
                  note.body.isEmpty ? updated : '$updated\n${note.body}',
                ),
                isThreeLine: note.body.isNotEmpty,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(notesProvider.notifier).add(title: 'Catatan baru');
        },
        tooltip: 'Tambah catatan',
        child: const Icon(Icons.add),
      ),
    );
  }
}
