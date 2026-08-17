import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(databaseProvider).watchSettings();
});
final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(databaseProvider).watchExercises(),
);
final routinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref.watch(databaseProvider).watchRoutines(),
);
final historyProvider = StreamProvider<List<Workout>>(
  (ref) => ref.watch(databaseProvider).watchHistory(),
);
final draftProvider = StreamProvider<Workout?>(
  (ref) => ref.watch(databaseProvider).watchDraft(),
);

final suggestedRoutineProvider = FutureProvider<Routine?>((ref) {
  ref.watch(historyProvider);
  ref.watch(routinesProvider);
  return ref.watch(databaseProvider).getSuggestedRoutine();
});

final weeklyReportProvider = FutureProvider<PeriodReport>((ref) {
  ref.watch(historyProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: now.weekday - 1));
  return ref
      .watch(databaseProvider)
      .getPeriodReport(start, start.add(const Duration(days: 7)));
});
