# Tabel Usulan AI vs Keputusan Final

Keputusan final dibuat dengan menimbang trade-off (boleh berbeda dari AI),
dengan alasan teknis tertulis dan status penerapan di repo.

| # | Usulan AI | Keputusan final | Alasan teknis | Status |
| --- | --- | --- | --- | --- |
| 1 | Feature-first `auth/` & `announcements/` (domain/data/presentation) | **Diterima** | Konsisten dengan `notes/` yang sudah feature-first; dependency rule jelas; memudahkan hapus/geser fitur | Diterapkan |
| 2 | `lib/data/token_store.dart` → `core/storage/` | **Diterima (lokasi direvisi)** | Semula diusulkan ke `core/`, tapi `core/` wajib bebas framework (check grep melarang impor `flutter/dio/sqflite/firebase`), sedangkan token store butuh `flutter_secure_storage`. Ditempatkan di `features/auth/data/datasources/token_store.dart` | Diterapkan (revisi lokasi) |
| 3 | `lib/data/api_client.dart` → `core/network/` | **Diterima (lokasi direvisi)** | Alasan sama: Dio itu framework, jadi tidak boleh di `core/`. Ditempatkan di `features/auth/data/datasources/api_client.dart` | Diterapkan (revisi lokasi) |
| 4 | `auth_repository.dart` dipecah: entity + interface + impl | **Diterima** | Interface wajib di domain, impl di data; `AuthSession` adalah entity murni | Diterapkan |
| 5 | `messaging/push_service.dart` → `core/messaging/` | **Ditolak (untuk sekarang)** | `push_service.dart` sudah berisi top-level function & state global; memindah folder tanpa memecahnya hanya memberi ilusi rapi. Perlu redesign state, di luar scope refactor ini | Dipertahankan |
| 6 | `home_page.dart` → `features/home/` | **Ditolak** | Masih placeholder kosong; memindahnya menambah folder tanpa isi nyata (over-structuring) | Dipertahankan |
| 7 | Use case untuk `announcements` | **Diterima (dengan catatan)** | Awalnya ditolak sebagai over-engineering, tetapi challenge meminta eksplisit "1 use case per fitur". Diterapkan sebagai `get_announcements.dart`; dicatat tetap borderline passthrough | Diterapkan (`get_announcements.dart`) |
| 8 | Use case untuk `auth` login | **Diterima (berevolusi)** | Awalnya ditolak, lalu diterima karena `Login` memuat aturan bisnis nyata: validasi email (`@`) dan panjang kata sandi (>=6) sebelum memanggil repo — bukan passthrough murni | Diterapkan (`login.dart`) |
| 9 | Use case `get_notes.dart` & `add_note.dart` (sudah ada) | **Dipertahankan** | Struktur ini diminta eksplisit oleh codelab. Dicatat sebagai borderline: keduanya passthrough 1 baris → kandidat ditipiskan bila logika tak bertambah | Dipertahankan (di-review) |
| 10 | `core/providers.dart` (opsional) | **Ditunda** | Belum ada provider lintas-fitur nyata; membuatnya sekarang = file kosong. Dibuat hanya saat ada `dioProvider`/`tokenStoreProvider` bersama | Ditunda |
| 11 | Interface repository di domain, impl di data | **Diterima** | Memenuhi dependency rule + memudahkan override fake di test | Sudah diterapkan di `notes/`; berlaku untuk auth & announcements |
| 12 | Entity bebas mapping (`toMap/fromMap/toJson` hanya di model) | **Diterima** | Entity = inti domain murni; mapping = detail data | Sudah diterapkan (`notes/domain/entities/note.dart`) |
| 13 | DI terpusat di provider Riverpod, tanpa package DI | **Diterima** | Sudah pola `notes_providers.dart`; widget tidak `new Repository()` | Diterapkan di semua fitur |
| 14 | Fungsi tanggal & parsing rute diekstrak ke `core/format.dart` | **Diterima** | Fungsi murni (tanpa Flutter) → aman di `core/` dan mudah diuji; `routes.dart` cukup `export ... show routeFromMessage` agar import lama tetap valid | Diterapkan |

## Ringkasan keputusan

- **Diadopsi:** feature-first untuk `auth` + `announcements`, interface di domain /
  impl di data, entity bebas mapping, DI via Riverpod, dan fungsi murni di
  `core/format.dart`. Infra ber-framework (token store, api client) diletakkan di
  `features/auth/data/datasources/` agar `core/` tetap murni Dart.
- **Ditolak/ditunda:** pemecahan `push_service`, folder `home/`, dan
  `core/providers.dart` kosong.
- **Usulan awal yang direvisi:** use case announcements & auth awalnya ditolak,
  namun diterapkan (login usulan berisi validasi nyata; announcements diminta
  eksplisit oleh challenge). Penempatan token store/api client dipindah dari
  `core/` ke `features/auth/data/datasources/`.
- **Prinsip:** hindari over-engineering untuk CRUD sederhana; use case baru hanya
  saat ada orkestrasi/aturan bisnis nyata.
