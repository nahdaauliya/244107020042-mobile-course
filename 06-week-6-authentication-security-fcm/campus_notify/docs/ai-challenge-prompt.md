# AI Prompt Challenge — Prompt yang Digunakan

Disalin apa adanya sebagai tanggung jawab teknis (prompt harus disimpan).

> Project Flutter saya: campus_notify (auth + FCM + daftar pengumuman).
> Kondisi kini: folder lib/{data, providers, pages, messaging},
> repository tercampur dengan implementasi, widget memanggil Dio langsung.
> Tugas:
> 1. Usulkan struktur feature-first Clean Architecture
>    (presentation/domain/data) untuk fitur auth + announcements.
> 2. Untuk tiap file lama, sebutkan tujuan barunya (pindah/pecah/hapus).
> 3. Tandai bagian yang over-engineering bila diterapkan ke CRUD sederhana,
>    dan kapan use case benar-benar dibutuhkan vs repository langsung.
> 4. Tunjukkan wiring DI dengan Riverpod (tanpa package DI tambahan).
> Jelaskan trade-off setiap keputusan.

## Catatan kondisi aktual repo (dicek sebelum menjawab)

- Fitur **notes** sudah lebih dulu direfaktor ke feature-first
  (`lib/features/notes/{domain,data,presentation}`).
- **auth** masih bergaya lama: `lib/data/{api_client,auth_repository,token_store}.dart`,
  `lib/providers/auth_provider.dart`, `lib/pages/login_page.dart`.
- **announcements** masih satu halaman datar: `lib/pages/announcement_page.dart`.
- **Klaim "widget memanggil Dio langsung" sudah tidak benar** di repo ini:
  Dio hanya dibangun di `lib/data/api_client.dart` dan disuntikkan sebagai
  dependency repository. Tidak ada widget yang mengakses Dio.
