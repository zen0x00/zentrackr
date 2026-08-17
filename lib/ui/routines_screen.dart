import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/metrics.dart';
import '../core/providers.dart';
import '../data/app_database.dart';
import 'common.dart';
import 'workout_screen.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: routines.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.list_alt,
                  title: 'No routines yet',
                  message: 'Build a reusable template for your next session.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final routine = rows[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center),
                        ),
                        title: Text(routine.name),
                        subtitle: const Text('Tap to edit'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoutineEditor(routine: routine),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            final db = ref.read(databaseProvider);
                            if (v == 'start') {
                              final id = await db.startWorkout(
                                routine: routine,
                              );
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WorkoutScreen(workoutId: id),
                                  ),
                                );
                              }
                            }
                            if (v == 'copy') await db.duplicateRoutine(routine);
                            if (v == 'archive') {
                              await db.archiveRoutine(routine.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'start', child: Text('Start')),
                            PopupMenuItem(
                              value: 'copy',
                              child: Text('Duplicate'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'starter-routines',
            tooltip: 'Starter routines',
            onPressed: () => _installStarterPack(context, ref),
            child: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new-routine',
            onPressed: () async {
              final name = await _askName(context);
              if (name == null || name.trim().isEmpty) return;
              final id = await ref.read(databaseProvider).createRoutine(name);
              final routine = Routine(
                id: id,
                name: name.trim(),
                notes: null,
                archived: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                deletedAt: null,
                syncState: 'local',
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoutineEditor(routine: routine),
                  ),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('New routine'),
          ),
        ],
      ),
    );
  }
}

class RoutineEditor extends ConsumerWidget {
  const RoutineEditor({super.key, required this.routine});
  final Routine routine;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final exercises = ref.watch(exercisesProvider).valueOrNull ?? [];
    final settings = ref.watch(settingsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(routine.name)),
      body: StreamBuilder<List<RoutineItem>>(
        stream: db.watchRoutineItems(routine.id),
        builder: (_, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.add_circle_outline,
              title: 'Empty routine',
              message: 'Add exercises and configure the planned sets.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: items.map((item) {
              final exercise = exercises
                  .where((e) => e.id == item.exerciseId)
                  .firstOrNull;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise?.name ?? 'Exercise',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () => db.removeRoutineItem(item.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 34, child: Text('SET')),
                          Expanded(
                            child: Text(
                              (settings?.unit ?? 'kg').toUpperCase(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Expanded(
                            child: Text('REPS', textAlign: TextAlign.center),
                          ),
                          Expanded(
                            child: Text(
                              (settings?.effortScale ?? 'rpe').toUpperCase(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      StreamBuilder<List<RoutineSetTarget>>(
                        stream: db.watchRoutineTargets(item.id),
                        builder: (_, targetSnap) => Column(
                          children: (targetSnap.data ?? []).asMap().entries.map((
                            e,
                          ) {
                            final target = e.value;
                            final unit = settings?.unit ?? 'kg';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Text('${e.key + 1}'),
                                  ),
                                  Expanded(
                                    child: _TargetField(
                                      key: ValueKey(
                                        '${target.id}-w-${target.targetWeightKg}',
                                      ),
                                      value: target.targetWeightKg == null
                                          ? ''
                                          : formatWeight(
                                              target.targetWeightKg,
                                              unit,
                                            ),
                                      onChanged: (v) => db.setRoutineWeight(
                                        target.id,
                                        v == null
                                            ? null
                                            : canonicalWeight(v, unit),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _TargetField(
                                      key: ValueKey(
                                        '${target.id}-r-${target.targetReps}',
                                      ),
                                      value:
                                          target.targetReps?.toString() ?? '',
                                      onChanged: (v) => db.setRoutineReps(
                                        target.id,
                                        v?.round(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _TargetField(
                                      key: ValueKey(
                                        '${target.id}-e-${target.targetEffort}',
                                      ),
                                      value:
                                          target.targetEffort?.toString() ?? '',
                                      onChanged: (v) {
                                        final scale =
                                            settings?.effortScale ?? 'rpe';
                                        if (v == null ||
                                            validEffort(v, scale)) {
                                          db.setRoutineEffort(target.id, v);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => db.addRoutineTarget(item.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add target set'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final picked = await pickExercise(context, exercises);
          if (picked != null) await db.addExerciseToRoutine(routine.id, picked);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
    );
  }
}

class _TargetField extends StatelessWidget {
  const _TargetField({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<double?> onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    style: const TextStyle(
      fontFamily: 'MapleMonoNF',
      fontWeight: FontWeight.w600,
    ),
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(isDense: true),
    onChanged: (v) => onChanged(double.tryParse(v)),
  );
}

Future<String?> _askName(BuildContext context) async {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('New routine'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Routine name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

Future<void> _installStarterPack(BuildContext context, WidgetRef ref) async {
  final pack = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add starter routines',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Existing routines will not be changed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Full Body'),
              subtitle: const Text('2 routines'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 'full_body'),
            ),
            ListTile(
              title: const Text('Upper / Lower'),
              subtitle: const Text('2 routines'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 'upper_lower'),
            ),
            ListTile(
              title: const Text('Push / Pull / Legs'),
              subtitle: const Text('3 routines'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 'ppl'),
            ),
          ],
        ),
      ),
    ),
  );
  if (pack == null) return;
  await ref.read(databaseProvider).installStarterPack(pack);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starter routines added.')));
  }
}
