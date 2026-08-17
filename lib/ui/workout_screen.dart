import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/metrics.dart';
import '../core/providers.dart';
import '../core/rest_notifications.dart';
import '../data/app_database.dart';
import 'common.dart';
import 'workout_summary_screen.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.workoutId,
    this.editingCompleted = false,
  });
  final String workoutId;
  final bool editingCompleted;
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  Timer? timer;
  int remaining = 0;
  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer(int seconds) {
    timer?.cancel();
    RestNotifications.instance.schedule(seconds);
    setState(() => remaining = seconds);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || remaining <= 1) {
        t.cancel();
        if (mounted) setState(() => remaining = 0);
      } else {
        setState(() => remaining--);
      }
    });
  }

  String get timerText =>
      '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingCompleted ? 'Edit workout' : 'Active workout',
        ),
        actions: [
          if (!widget.editingCompleted && remaining > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(
                    timerText,
                    style: const TextStyle(fontFamily: 'MapleMonoNF'),
                  ),
                  onPressed: () {
                    RestNotifications.instance.cancel();
                    setState(() => remaining = 0);
                  },
                ),
              ),
            ),
          if (!widget.editingCompleted)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'discard') {
                  final yes = await _confirm(
                    context,
                    'Discard workout?',
                    'The draft will be removed from your active workouts.',
                  );
                  if (yes && context.mounted) {
                    await db.discardWorkout(widget.workoutId);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'discard', child: Text('Discard workout')),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<WorkoutItem>>(
        stream: db.watchWorkoutItems(widget.workoutId),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.add_circle_outline,
              title: 'Add your first exercise',
              message: 'Your workout saves automatically as you log it.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
            children: items
                .map(
                  (item) => _ExerciseCard(
                    item: item,
                    workoutId: widget.workoutId,
                    db: db,
                    unit: settings?.unit ?? 'kg',
                    effortType: settings?.effortScale ?? 'rpe',
                    onCompleted: widget.editingCompleted
                        ? () {}
                        : () => startTimer(settings?.defaultRestSeconds ?? 120),
                  ),
                )
                .toList(),
          );
        },
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await pickExercise(context, exercises);
                    if (picked != null) {
                      await db.addExerciseToWorkout(widget.workoutId, picked);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    if (widget.editingCompleted) {
                      await db.touchWorkout(widget.workoutId);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      return;
                    }
                    final items = await db.getWorkoutItems(widget.workoutId);
                    var completed = 0;
                    for (final item in items) {
                      completed += (await db.getSets(
                        item.id,
                      )).where((s) => s.completed).length;
                    }
                    if (!context.mounted) return;
                    if (completed == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Complete at least one set first.'),
                        ),
                      );
                      return;
                    }
                    final yes = await _confirm(
                      context,
                      'Finish workout?',
                      '$completed completed sets will be saved to history.',
                    );
                    if (yes && context.mounted) {
                      await db.finishWorkout(widget.workoutId);
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutSummaryScreen(
                              workoutId: widget.workoutId,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    widget.editingCompleted ? Icons.save_outlined : Icons.check,
                  ),
                  label: Text(widget.editingCompleted ? 'Save' : 'Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.item,
    required this.workoutId,
    required this.db,
    required this.unit,
    required this.effortType,
    required this.onCompleted,
  });
  final WorkoutItem item;
  final String workoutId;
  final AppDatabase db;
  final String unit;
  final String effortType;
  final VoidCallback onCompleted;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.exerciseNameSnapshot,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove exercise',
                onPressed: () => db.removeWorkoutItem(item.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          FutureBuilder<List<PreviousSet>>(
            future: db.getPreviousPerformance(item.exerciseId, workoutId),
            builder: (context, snapshot) {
              final previous = snapshot.data ?? [];
              if (previous.isEmpty) return const SizedBox.shrink();
              final summary = previous
                  .take(4)
                  .map(
                    (s) => '${formatWeight(s.weightKg, unit)}×${s.reps ?? '—'}',
                  )
                  .join('  ·  ');
              final target = _beatTarget(previous, unit);
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAST TIME',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'MapleMonoNF',
                              fontSize: 12,
                            ),
                          ),
                          if (target != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              'BEAT IT  $target',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'MapleMonoNF',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          db.copyPreviousPerformance(item.id, previous),
                      child: const Text('Use last'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 42, child: Text('SET')),
              Expanded(
                child: Text(unit.toUpperCase(), textAlign: TextAlign.center),
              ),
              const Expanded(child: Text('REPS', textAlign: TextAlign.center)),
              Expanded(
                child: Text(
                  effortType.toUpperCase(),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 46),
            ],
          ),
          StreamBuilder<List<WorkoutSet>>(
            stream: db.watchSets(item.id),
            builder: (_, snap) => Column(
              children: (snap.data ?? []).asMap().entries.map((entry) {
                final set = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: InkWell(
                          onTap: () => db.setKind(
                            set.id,
                            set.setType == 'working' ? 'warmup' : 'working',
                          ),
                          onLongPress: () => db.removeSet(set.id),
                          child: CircleAvatar(
                            radius: 15,
                            child: Text(
                              set.setType == 'warmup'
                                  ? 'W'
                                  : '${entry.key + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _NumberField(
                          key: ValueKey('${set.id}-w-${set.weightKg}'),
                          value: set.weightKg == null
                              ? ''
                              : formatWeight(set.weightKg, unit),
                          decimal: true,
                          onChanged: (v) => db.setWeight(
                            set.id,
                            v == null ? null : canonicalWeight(v, unit),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _NumberField(
                          key: ValueKey('${set.id}-r-${set.reps}'),
                          value: set.reps?.toString() ?? '',
                          onChanged: (v) => db.setReps(set.id, v?.round()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _NumberField(
                          key: ValueKey('${set.id}-e-${set.effortValue}'),
                          value: set.effortValue?.toString() ?? '',
                          decimal: true,
                          onChanged: (v) {
                            if (v == null || validEffort(v, effortType)) {
                              db.setEffort(set.id, v, effortType);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: () {
                          db.setCompleted(set.id, !set.completed);
                          if (!set.completed) onCompleted();
                        },
                        icon: Icon(
                          set.completed ? Icons.check : Icons.circle_outlined,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          TextButton.icon(
            onPressed: () => db.addSet(item.id),
            icon: const Icon(Icons.add),
            label: const Text('Add set'),
          ),
        ],
      ),
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });
  final String value;
  final bool decimal;
  final ValueChanged<double?> onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    style: const TextStyle(
      fontFamily: 'MapleMonoNF',
      fontWeight: FontWeight.w600,
    ),
    textAlign: TextAlign.center,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 11, horizontal: 4),
    ),
    onChanged: (v) => onChanged(double.tryParse(v)),
  );
}

String? _beatTarget(List<PreviousSet> previous, String unit) {
  final working = previous
      .where((set) => set.setType == 'working' && set.reps != null)
      .toList();
  if (working.isEmpty) return null;
  final best = working.reduce((a, b) {
    final aScore = (a.weightKg ?? 0) * 100 + (a.reps ?? 0);
    final bScore = (b.weightKg ?? 0) * 100 + (b.reps ?? 0);
    return bScore > aScore ? b : a;
  });
  final reps = best.reps ?? 0;
  if ((best.weightKg ?? 0) <= 0) return '${reps + 1} reps';
  if (reps < 12) {
    return '${formatWeight(best.weightKg, unit)} $unit × ${reps + 1}';
  }
  final incrementKg = unit == 'lb' ? 5 / 2.2046226218 : 2.5;
  return '${formatWeight((best.weightKg ?? 0) + incrementKg, unit)} $unit × 8';
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
