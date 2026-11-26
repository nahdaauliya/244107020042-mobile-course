import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/notes/presentation/providers/notes_providers.dart';
import 'perf/perf_scenario_page.dart';
import 'perf/perf_seed_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const noteCount = int.fromEnvironment('PERF_NOTE_COUNT', defaultValue: 500);

  runApp(
    ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(
          PerfSeedNoteRepository(count: noteCount),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PerfScenarioPage(),
      ),
    ),
  );
}
