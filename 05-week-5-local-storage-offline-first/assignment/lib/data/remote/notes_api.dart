import '../local/note.dart';

/// Hasil satu operasi tulis ke server.
class UploadResult {
  const UploadResult({
    required this.accepted,
    this.serverNote,
    this.message = '',
  });

  /// `true` bila server menyimpan versi yang dikirim.
  final bool accepted;

  /// Versi yang benar-benar tersimpan di server. Berbeda dari yang dikirim
  /// ketika server menolak karena versi lokal lebih tua (konflik).
  final Note? serverNote;

  /// Alasan penolakan, ditampilkan ke pengguna kalau ada konflik.
  final String message;
}

/// Kontrak sisi server.
///
/// Sengaja berupa interface tipis supaya aplikasi tetap bisa dijalankan penuh
/// tanpa backend: [InMemoryNotesApi] menggantikan peran server sungguhan, dan
/// test bisa memakai implementasi yang selalu gagal untuk menguji jalur offline.
abstract class NotesApi {
  /// Daftar seluruh catatan yang ada di server.
  Future<List<Note>> fetchAllNotes();

  /// Kirim satu catatan. Server memutuskan diterima atau ditolak.
  ///
  /// [force] dipakai setelah pengguna eksplisit memilih "pakai versi perangkat
  /// ini": saat itu aturan last-write-wins harus dilewati, bukan beaten oleh
  /// jam server yang mungkin lebih maju.
  Future<UploadResult> uploadNote(Note note, {bool force = false});

  /// Hapus satu catatan di server.
  Future<void> deleteNote(int id);
}

/// Server tiruan: menyimpan catatan di memori selama satu sesi aplikasi.
///
/// Meniru perilaku server yang wajar untuk latihan sinkronisasi:
/// - `uploadNote` diterima hanya bila versi yang dikirim tidak lebih tua dari
///   versi server (last-write-wins berbasis jam, sama dengan aturan klien).
/// - Ada latensi artificial supaya status "menyinkron..." kelihatan di UI.
class InMemoryNotesApi implements NotesApi {
  InMemoryNotesApi({
    List<Note>? seed,
    this.latency = const Duration(milliseconds: 350),
  }) : _store = {for (final note in seed ?? const <Note>[]) note.id: note};

  final Map<int?, Note> _store;
  final Duration latency;

  /// Snapshot server; dipakai test untuk menyimulasikan perubahan dari
  /// "perangkat lain", misalnya setelah diedit di browser.
  List<Note> get serverNotes => _store.values.toList();

  @override
  Future<List<Note>> fetchAllNotes() async {
    await Future<void>.delayed(latency);
    return _store.values.toList();
  }

  @override
  Future<UploadResult> uploadNote(Note note, {bool force = false}) async {
    await Future<void>.delayed(latency);
    final id = note.id;
    if (id == null) {
      return const UploadResult(
        accepted: false,
        message: 'Catatan baru harus punya id lokal sebelum diunggah.',
      );
    }
    final current = _store[id];
    if (!force &&
        current != null &&
        current.updatedAt.isAfter(note.updatedAt)) {
      return UploadResult(
        accepted: false,
        serverNote: current,
        message: 'Server menyimpan versi yang lebih baru.',
      );
    }
    _store[id] = note.copyWith(status: SyncStatus.synced, conflictNote: '');
    return UploadResult(accepted: true, serverNote: _store[id]);
  }

  @override
  Future<void> deleteNote(int id) async {
    await Future<void>.delayed(latency);
    _store.remove(id);
  }
}
