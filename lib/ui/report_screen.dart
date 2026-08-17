import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/metrics.dart';
import '../core/providers.dart';
import '../data/app_database.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.monthly});
  final bool monthly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final unit = settings?.unit ?? 'kg';
    final ranges = _ranges(DateTime.now(), monthly);
    return Scaffold(
      appBar: AppBar(
        title: Text(monthly ? 'Monthly progress' : 'Weekly recap'),
      ),
      body: FutureBuilder<({PeriodReport current, PeriodReport previous})>(
        future: () async {
          final reports = await Future.wait([
            db.getPeriodReport(ranges.$1, ranges.$2),
            db.getPeriodReport(ranges.$3, ranges.$1),
          ]);
          return (current: reports[0], previous: reports[1]);
        }(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final current = snapshot.data!.current;
          final previous = snapshot.data!.previous;
          final change = previous.volumeKg == 0
              ? null
              : ((current.volumeKg - previous.volumeKg) /
                        previous.volumeKg *
                        100)
                    .round();
          final period = monthly
              ? DateFormat('MMMM yyyy').format(ranges.$1)
              : '${DateFormat('d MMM').format(ranges.$1)} – ${DateFormat('d MMM').format(ranges.$2.subtract(const Duration(days: 1)))}';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(period, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 10),
              Text(
                monthly ? 'Your month in motion.' : 'Your week in review.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              if (!monthly)
                _GoalCard(
                  done: current.workoutCount,
                  goal: settings?.weeklyWorkoutGoal ?? 3,
                ),
              if (!monthly) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReportStat(
                      label: 'WORKOUTS',
                      value: '${current.workoutCount}',
                      detail: _difference(
                        current.workoutCount,
                        previous.workoutCount,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReportStat(
                      label: 'WORKING SETS',
                      value: '${current.setCount}',
                      detail: _difference(current.setCount, previous.setCount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ReportStat(
                      label: 'VOLUME',
                      value: '${formatWeight(current.volumeKg, unit)} $unit',
                      detail: change == null
                          ? 'No prior baseline'
                          : '${change >= 0 ? '+' : ''}$change% vs previous',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReportStat(
                      label: 'TIME',
                      value: '${current.duration.inMinutes} min',
                      detail: '${current.activeDays} active days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.fitness_center_rounded),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MOST TRAINED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              current.topExercise ??
                                  'Complete a workout to see this',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.done, required this.goal});
  final int done;
  final int goal;
  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '$done of $goal workouts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  progress >= 1 ? 'Goal complete' : '${goal - done} to go',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'MapleMonoNF',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

String _difference(int current, int previous) {
  final value = current - previous;
  if (previous == 0) return 'No prior baseline';
  return '${value >= 0 ? '+' : ''}$value vs previous';
}

(DateTime, DateTime, DateTime) _ranges(DateTime now, bool monthly) {
  if (monthly) {
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final previous = DateTime(now.year, now.month - 1);
    return (start, end, previous);
  }
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: now.weekday - 1));
  return (
    start,
    start.add(const Duration(days: 7)),
    start.subtract(const Duration(days: 7)),
  );
}
