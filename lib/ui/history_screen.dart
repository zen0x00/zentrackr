import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/metrics.dart';
import '../core/providers.dart';
import '../data/app_database.dart';
import 'common.dart';
import 'workout_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final unit = ref.watch(settingsProvider).valueOrNull?.unit ?? 'kg';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No workouts yet',
                  message: 'Finish a workout to build your training history.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final w = rows[i];
                    final end = w.completedAt ?? w.startedAt;
                    final duration = end.difference(w.startedAt);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${end.day}')),
                        title: Text(w.name),
                        subtitle: Text(
                          '${DateFormat('EEE, d MMM yyyy · h:mm a').format(end.toLocal())}\n${duration.inMinutes} min',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Edit workout',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkoutScreen(
                                workoutId: w.id,
                                editingCompleted: true,
                              ),
                            ),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkoutDetail(workout: w, unit: unit),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class WorkoutDetail extends ConsumerWidget {
  const WorkoutDetail({super.key, required this.workout, required this.unit});
  final Workout workout;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
      body: FutureBuilder<List<WorkoutItem>>(
        future: db.getWorkoutItems(workout.id),
        builder: (_, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                DateFormat(
                  'EEEE, d MMMM yyyy · h:mm a',
                ).format((workout.completedAt ?? workout.startedAt).toLocal()),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.exerciseNameSnapshot,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        FutureBuilder<List<WorkoutSet>>(
                          future: db.getSets(item.id),
                          builder: (_, setSnap) => Column(
                            children: (setSnap.data ?? [])
                                .where((s) => s.completed)
                                .map(
                                  (s) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Text(
                                      s.setType == 'warmup' ? 'W' : '•',
                                    ),
                                    title: Text(
                                      '${formatWeight(s.weightKg, unit)} $unit × ${s.reps ?? '—'}',
                                      style: const TextStyle(
                                        fontFamily: 'MapleMonoNF',
                                      ),
                                    ),
                                    trailing: s.effortValue == null
                                        ? null
                                        : Text(
                                            '${s.effortType?.toUpperCase()} ${s.effortValue}',
                                          ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
