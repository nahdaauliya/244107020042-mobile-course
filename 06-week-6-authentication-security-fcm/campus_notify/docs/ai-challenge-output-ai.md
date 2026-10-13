# Output Awal AI — Usulan Reorganisasi Feature-First Clean Architecture

## 1. Struktur yang diusulkan

```
lib/
├── core/                                  # lintas fitur, tidak tahu fitur apa pun
│   ├── failures.dart                      # Failure murni Dart (sudah ada)
│   ├── network/api_client.dart            # dari lib/data/api_client.dart
│   ├── storage/token_store.dart           # dari lib/data/token_store.dart
│   └── providers.dart                     # DI lintas fitur (opsional, isi bila ada)
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── entities/auth_session.dart
│   │   │   └── repositories/auth_repository.dart      # interface saja
│   │   ├── data/
│   │   │   └── repositories/auth_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/auth_providers.dart
│   │       └── pages/login_page.dart
│   ├── announcements/
│   │   ├── domain/
│   │   │   ├── entities/announcement.dart
│   │   │   └── repositories/announcement_repository.dart
│   │   ├── data/
│   │   │   ├── models/announcement_model.dart
│   │   │   └── repositories/announcement_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/announcements_providers.dart
│   │       └── pages/announcement_page.dart
│   └── notes/                              # sudah feature-first
├── messaging/push_service.dart             # infra lintas fitur (boleh ke core/messaging)
├── routes.dart                             # konstanta rute (tetap di root)
└── main.dart                               # composition root
```

Aturan arah dependensi: `presentation → domain ← data`. Domain tidak boleh
tahu Flutter/Dio/SQLite/Firebase. Data mengimplementasikan interface domain.

## 2. File lama → tujuan baru

| File lama | Tujuan baru | Aksi |
| --- | --- | --- |
| `lib/data/token_store.dart` | `core/storage/token_store.dart` | pindah (infra, bukan milik satu fitur) |
| `lib/data/api_client.dart` | `core/network/api_client.dart` | pindah (infra HTTP lintas fitur) |
| `lib/data/auth_repository.dart` | `auth/domain/entities/auth_session.dart` + `auth/domain/repositories/auth_repository.dart` (interface) + `auth/data/repositories/auth_repository_impl.dart` | pecah 3 |
| `lib/providers/auth_provider.dart` | `auth/presentation/providers/auth_providers.dart` | pindah |
| `lib/pages/login_page.dart` | `auth/presentation/pages/login_page.dart` | pindah |
| `lib/pages/announcement_page.dart` | `announcements/presentation/pages/announcement_page.dart` | pindah |
| `lib/pages/home_page.dart` | `home/presentation/pages/home_page.dart` | pindah (opsional) |
| `lib/messaging/push_service.dart` | `core/messaging/push_service.dart` | pindah (cross-cutting) |
| `lib/routes.dart` | tetap `lib/routes.dart` | dipertahankan (level aplikasi) |
| `lib/main.dart` | tetap `lib/main.dart` | dipertahankan (composition root) |

## 3. Over-engineering: kapan use case layak, kapan cukup repository

**Tandai OVER-ENGINEERING bila:**
- Membuat use case untuk setiap operasi CRUD yang isinya satu baris passthrough
  (`GetAnnouncements.call() => repo.getAnnouncements()`). Ini menambah file,
  lapisan, dan import tanpa aturan bisnis apa pun.
- Membuat `core/providers.dart` yang hanya berisi provider fitur (salah tempat),
  atau interface + impl untuk fitur yang benar-benar sepele tanpa rencana test.
- Membuat model/entity terpisah bila tidak ada serialization dan tidak ada
  perbedaan field.

**Use case BARU layak bila ada:**
- Orkestrasi lintas repository (mis. login = simpan token + update state + sinkron
  perangkat), validasi/aturan bisnis, caching/retry policy, atau logika yang
  dipakai ulang oleh lebih dari satu notifier.
- Batas transaksi yang kompleks (multi-tabel, rollback).

**Kesimpulan usulan untuk fitur di sini:**
- **announcements** (read-only, CRUD sederhana) → cukup **notifier → repository**,
  tanpa use case.
- **notes** → `AddNote`/`GetNotes` saat ini passthrough; bisa ditipiskan jadi
  notifier → repository. Pertahankan hanya jika ingin konsisten dengan struktur
  codelab.
- **auth** → orkestrasi login nyata (panggil repo, simpan token, refresh 401).
  Orkestrasi ini cukup di notifier; use case opsional.

## 4. Wiring DI dengan Riverpod (tanpa package DI tambahan)

```dart
// core
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final dioProvider = Provider<Dio>(
  (ref) => buildApiClient(ref.watch(tokenStoreProvider), ref.watch(authRepositoryProvider)),
);

// auth — data & domain
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);
final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

// announcements
final announcementRepositoryProvider =
    Provider<AnnouncementRepository>((ref) => AnnouncementRepositoryImpl());
final announcementsProvider =
    FutureProvider<List<Announcement>>((ref) => ref.watch(announcementRepositoryProvider).getAnnouncements());
```

`Provider` = composition root. Widget/notifier hanya `ref.watch`/`ref.read`.
Tidak ada `Repository()` yang dibuat di dalam widget.

## 5. Trade-off tiap keputusan

| Keputusan | Untung | Rugi |
| --- | --- | --- |
| Feature-first (per fitur) | Tim bisa kerja paralel, kode fitur terkurung, mudah dihapus | Duplikasi folder kecil (`models/`, `repositories/`) tiap fitur |
| Interface di domain, impl di data | Dependency rule terjaga, mudah di-fake saat test | Satu file tambahan per fitur |
| Infra ke `core/` | Tidak ada fitur yang "memiliki" Http/Storage | `core` bisa jadi keranjang sampah bila tak disiplin |
| Tanpa use case untuk CRUD 1 baris | Lebih sedikit file, alur lurus | Kalau logika bertambah, harus refactor ke use case |
| `Provider` Riverpod sebagai DI | Tanpa package tambahan, lazy, mudah di-override di test | Provider tingkat atas harus disiplin agar tidak jadi wadah sembarangan |
