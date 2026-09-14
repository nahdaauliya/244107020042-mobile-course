import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/stats_page.dart';

void main() {
  // ProviderScope diperlukan agar Riverpod
  // dapat digunakan di dalam aplikasi.
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// Widget utama aplikasi.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stats Riverpod',

      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),

      // Menampilkan StatsPage sebagai halaman utama.
      home: const StatsPage(),
    );
  }
}