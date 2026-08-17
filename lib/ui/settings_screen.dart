import 'package:drift/drift.dart' show Value;
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' hide XFile;
import '../core/providers.dart';
import '../core/rest_notifications.dart';
import '../data/app_database.dart';
import 'common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final db = ref.watch(databaseProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            Text('Training', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Weight unit',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        AppToggle<String>(
                          value: settings.unit,
                          options: const [
                            AppToggleOption('kg', 'kg'),
                            AppToggleOption('lb', 'lb'),
                          ],
                          onChanged: (value) => db.saveSettings(
                            AppSettingsCompanion(
                              unit: Value(value),
                              updatedAt: Value(DateTime.now()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Effort scale',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        AppToggle<String>(
                          value: settings.effortScale,
                          options: const [
                            AppToggleOption('rpe', 'RPE'),
                            AppToggleOption('rir', 'RIR'),
                          ],
                          onChanged: (value) => db.saveSettings(
                            AppSettingsCompanion(
                              effortScale: Value(value),
                              updatedAt: Value(DateTime.now()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Default rest timer'),
                    subtitle: Text(
                      '${settings.defaultRestSeconds ~/ 60} min ${settings.defaultRestSeconds % 60} sec',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final v = await _restDialog(
                        context,
                        settings.defaultRestSeconds,
                      );
                      if (v != null) {
                        await db.saveSettings(
                          AppSettingsCompanion(
                            defaultRestSeconds: Value(v),
                            updatedAt: Value(DateTime.now()),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Weekly workout goal'),
                    subtitle: Text('${settings.weeklyWorkoutGoal} workouts'),
                    trailing: DropdownButton<int>(
                      value: settings.weeklyWorkoutGoal,
                      underline: const SizedBox.shrink(),
                      items: [2, 3, 4, 5, 6]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        db.saveSettings(
                          AppSettingsCompanion(
                            weeklyWorkoutGoal: Value(value),
                            updatedAt: Value(DateTime.now()),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Training-day reminders'),
                    subtitle: Text(
                      settings.remindersEnabled
                          ? 'A gentle nudge on selected days'
                          : 'Off — your workouts stay pressure-free',
                    ),
                    value: settings.remindersEnabled,
                    onChanged: (enabled) async {
                      await db.saveSettings(
                        AppSettingsCompanion(
                          remindersEnabled: Value(enabled),
                          updatedAt: Value(DateTime.now()),
                        ),
                      );
                      if (enabled) {
                        await _scheduleReminders(settings);
                      } else {
                        await RestNotifications.instance
                            .cancelTrainingReminders();
                      }
                    },
                  ),
                  if (settings.remindersEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: _WeekdayPicker(
                        selected: _parseDays(settings.reminderDays),
                        onChanged: (days) async {
                          final encoded = (days.toList()..sort()).join(',');
                          await db.saveSettings(
                            AppSettingsCompanion(
                              reminderDays: Value(encoded),
                              updatedAt: Value(DateTime.now()),
                            ),
                          );
                          await RestNotifications.instance
                              .scheduleTrainingReminders(
                                weekdays: days,
                                hour: settings.reminderHour,
                                minute: settings.reminderMinute,
                              );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Reminder time'),
                      subtitle: Text(
                        _formatTime(
                          context,
                          settings.reminderHour,
                          settings.reminderMinute,
                        ),
                      ),
                      trailing: const Icon(Icons.schedule_rounded),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: settings.reminderHour,
                            minute: settings.reminderMinute,
                          ),
                        );
                        if (time == null) return;
                        await db.saveSettings(
                          AppSettingsCompanion(
                            reminderHour: Value(time.hour),
                            reminderMinute: Value(time.minute),
                            updatedAt: Value(DateTime.now()),
                          ),
                        );
                        await RestNotifications.instance
                            .scheduleTrainingReminders(
                              weekdays: _parseDays(settings.reminderDays),
                              hour: time.hour,
                              minute: time.minute,
                            );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('App', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Manage exercises'),
                    subtitle: const Text(
                      'Browse the catalog or create your own',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExerciseManager(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Backup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('Export backup'),
                    subtitle: const Text(
                      'Save workouts, routines, and settings as JSON',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final json = await db.exportBackupJson();
                      final name =
                          'zentrackr-backup-${DateTime.now().toIso8601String().split('T').first}.json';
                      final file = XFile.fromData(
                        utf8.encode(json),
                        mimeType: 'application/json',
                        name: name,
                      );
                      if (defaultTargetPlatform == TargetPlatform.android ||
                          defaultTargetPlatform == TargetPlatform.iOS) {
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [file],
                            fileNameOverrides: [name],
                            title: 'ZenTrackr backup',
                          ),
                        );
                      } else {
                        final location = await getSaveLocation(
                          suggestedName: name,
                        );
                        if (location == null) return;
                        await file.saveTo(location.path);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup exported.')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded),
                    title: const Text('Restore backup'),
                    subtitle: const Text(
                      'Replaces the training data on this device',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final file = await openFile(
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'ZenTrackr JSON',
                            extensions: ['json'],
                          ),
                        ],
                      );
                      if (file == null || !context.mounted) return;
                      final confirmed =
                          await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Restore this backup?'),
                              content: const Text(
                                'Current workouts, routines, and custom exercises will be replaced.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Restore'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirmed) return;
                      try {
                        await db.importBackupJson(await file.readAsString());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup restored.')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not restore: $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                title: const Text('Delete local training data'),
                subtitle: const Text(
                  'Removes workouts, routines, and custom exercises from this device.',
                ),
                trailing: const Icon(Icons.delete_forever),
                onTap: () async {
                  final yes =
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete all training data?'),
                          content: const Text(
                            'This cannot be undone. There is no cloud backup in this version.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (yes) await db.clearUserData();
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your data stays on this device. Uninstalling the app or clearing its storage may permanently remove it.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Set<int> _parseDays(String value) => value
    .split(',')
    .map(int.tryParse)
    .whereType<int>()
    .where((day) => day >= 1 && day <= 7)
    .toSet();

String _formatTime(BuildContext context, int hour, int minute) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));

Future<void> _scheduleReminders(AppSetting settings) =>
    RestNotifications.instance.scheduleTrainingReminders(
      weekdays: _parseDays(settings.reminderDays),
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
    );

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(7, (index) {
        final day = index + 1;
        final active = selected.contains(day);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final updated = {...selected};
                active ? updated.remove(day) : updated.add(day);
                onChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? colors.primary : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: active ? colors.onPrimary : colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ExerciseManager extends ConsumerWidget {
  const ExerciseManager({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider);
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center,
                title: 'No exercises',
                message: '',
              )
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final e = rows[i];
                  return ListTile(
                    title: Text(e.name),
                    subtitle: Text(
                      '${e.primaryMuscle} · ${e.equipment}${e.isCustom ? ' · Custom' : ''}',
                    ),
                    trailing: e.isCustom
                        ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _exerciseDialog(context, db, existing: e);
                              }
                              if (v == 'archive') {
                                await db.archiveExercise(e.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exerciseDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Custom exercise'),
      ),
    );
  }
}

Future<void> _exerciseDialog(
  BuildContext context,
  AppDatabase db, {
  Exercise? existing,
}) async {
  final name = TextEditingController(text: existing?.name);
  String muscle = existing?.primaryMuscle ?? 'Chest';
  String equipment = existing?.equipment ?? 'Barbell';
  String type = existing?.trackingType ?? 'weight_reps';
  final save = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (_, setState) => AlertDialog(
        title: Text(existing == null ? 'Custom exercise' : 'Edit exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                initialValue: muscle,
                decoration: const InputDecoration(labelText: 'Primary muscle'),
                items:
                    [
                          'Chest',
                          'Back',
                          'Shoulders',
                          'Biceps',
                          'Triceps',
                          'Quadriceps',
                          'Hamstrings',
                          'Glutes',
                          'Calves',
                          'Core',
                          'Other',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => muscle = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                initialValue: equipment,
                decoration: const InputDecoration(labelText: 'Equipment'),
                items:
                    [
                          'Barbell',
                          'Dumbbell',
                          'Machine',
                          'Cable',
                          'Bodyweight',
                          'Other',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => equipment = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tracking'),
                items: const [
                  DropdownMenuItem(
                    value: 'weight_reps',
                    child: Text('Weight + reps'),
                  ),
                  DropdownMenuItem(
                    value: 'bodyweight_reps',
                    child: Text('Bodyweight + reps'),
                  ),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (save == true && name.text.trim().isNotEmpty) {
    if (existing == null) {
      await db.createCustomExercise(name.text, muscle, equipment, type);
    } else {
      await db.updateCustomExercise(
        existing.id,
        name.text,
        muscle,
        equipment,
        type,
      );
    }
  }
}

Future<int?> _restDialog(BuildContext context, int current) async {
  int value = current;
  return showDialog<int>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Default rest timer'),
        content: Slider(
          value: value.toDouble(),
          min: 30,
          max: 300,
          divisions: 18,
          label: '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}',
          onChanged: (v) => setState(() => value = v.round()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
