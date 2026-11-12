# Performance Findings – Campus Notify

## 1. Baseline Profiling

Pengujian performa dilakukan menggunakan Flutter DevTools pada aplikasi Campus Notify.

Hasil pengamatan:
- Average FPS: 59 FPS.
- Target FPS: 60 FPS.
- Ditemukan beberapa frame yang mengalami jank.
- Raster time pada Flutter Frame 2 mencapai 64,4 ms.
- Target waktu rendering untuk 60 FPS adalah sekitar 16,67 ms.

Screenshot baseline: `screenshots/before-profile.png`

## 2. Identifikasi Masalah

### Temuan 1: Widget Rebuild Berulang

Berdasarkan Rebuild Stats, ditemukan beberapa widget dengan jumlah rebuild tinggi:

| Widget | Jumlah Rebuild |
|---|---:|
| Scaffold | 28 |
| Icon | 27 |
| Text | 24 |
| TextField | 24 |
| Container | 24 |
| AppBar | 20 |
| ListView | 17 |

Berdasarkan pemeriksaan kode `chat_screen.dart`, fungsi `_sendQuestion()` menggunakan `setState()` setiap tiga karakter ketika menampilkan jawaban AI.

Kondisi ini menyebabkan pembaruan tampilan yang terlalu sering dan berpotensi memicu rebuild widget yang tidak diperlukan.

### Temuan 2: Scroll Animation Berulang

Fungsi `_scrollToBottom()` dipanggil pada setiap iterasi proses streaming jawaban AI.

Fungsi tersebut menggunakan `animateTo()` dengan durasi 300 ms, sedangkan pembaruan jawaban dilakukan setiap 30 ms.

Akibatnya, animasi scroll berpotensi dimulai ulang secara berulang dan menambah beban rendering.

### Temuan 3: Ukuran Gambar Belum Dioptimasi

Pada fungsi `_pickAndAnalyzeImage()`, pemilihan gambar belum menggunakan pembatasan dimensi maupun kualitas gambar.

Belum terdapat pengaturan `maxWidth`, `maxHeight`, dan `imageQuality` pada pemanggilan `pickImage()`.

Hal ini berpotensi menyebabkan gambar berukuran besar diproses dan dikirim ke layanan AI sehingga meningkatkan penggunaan memori dan waktu pemrosesan.

Temuan ini masih perlu diverifikasi melalui pengujian gambar.

## 3. Temuan Tambahan

- Aplikasi sudah menggunakan `ListView.builder`.
- TextEditingController dan ScrollController sudah memiliki pemanggilan `dispose()`.
- AudioRecorder juga sudah memiliki pemanggilan `dispose()`.

Belum ditemukan bukti yang cukup untuk menyimpulkan adanya memory leak.

## 4. Kesimpulan

Berdasarkan hasil baseline profiling dan pemeriksaan kode, ditemukan tiga area yang berpotensi memengaruhi performa aplikasi, yaitu widget rebuild berulang, pemanggilan animasi scroll yang terlalu sering, dan pemrosesan gambar tanpa pembatasan ukuran.

Ketiga area tersebut akan menjadi fokus optimasi pada tahap berikutnya.