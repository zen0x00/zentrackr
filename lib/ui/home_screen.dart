import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../data/app_database.dart';
import 'report_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openWorkout(
    BuildContext context,
    WidgetRef ref, {
    Routine? routine,
  }) async {
    final id = await ref.read(databaseProvider).startWorkout(routine: routine);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WorkoutScreen(workoutId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftProvider).valueOrNull;
    final routines = ref.watch(routinesProvider).valueOrNull ?? [];
    final history = ref.watch(historyProvider).valueOrNull ?? [];
    final suggested = ref.watch(suggestedRoutineProvider).valueOrNull;
    final weekly = ref.watch(weeklyReportProvider).valueOrNull;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
          children: [
            Text(
              'Train with intent.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Everything you need for today’s session.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _WorkoutHero(
              draft: draft,
              suggested: suggested,
              onPressed: () => _openWorkout(
                context,
                ref,
                routine: draft == null ? suggested : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.check_circle_outline,
                    value: '${history.length}',
                    label: 'Workouts',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.list_alt_rounded,
                    value: '${routines.length}',
                    label: 'Routines',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressCard(
              report: weekly,
              goal: settings?.weeklyWorkoutGoal ?? 3,
              onWeekly: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportScreen(monthly: false),
                ),
              ),
              onMonthly: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportScreen(monthly: true),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionTitle(title: 'Your routines', action: 'View all'),
            const SizedBox(height: 12),
            if (routines.isEmpty)
              const _EmptyCard(
                icon: Icons.list_alt_rounded,
                text:
                    'Create a routine to make starting your next workout effortless.',
              )
            else
              ...routines
                  .take(4)
                  .map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.fitness_center, size: 20),
                          ),
                          title: Text(
                            routine.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('Ready when you are'),
                          trailing: CircleAvatar(
                            radius: 19,
                            backgroundColor: colors.primary,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: colors.onPrimary,
                            ),
                          ),
                          onTap: draft == null
                              ? () =>
                                    _openWorkout(context, ref, routine: routine)
                              : () => _openWorkout(context, ref),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Recent activity'),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const _EmptyCard(
                icon: Icons.history_rounded,
                text: 'Your completed workouts will appear here.',
              )
            else
              ...history
                  .take(3)
                  .map(
                    (workout) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        workout.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        DateFormat('d MMM · h:mm a').format(
                          (workout.completedAt ?? workout.startedAt).toLocal(),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutHero extends StatelessWidget {
  const _WorkoutHero({
    required this.draft,
    required this.suggested,
    required this.onPressed,
  });
  final Workout? draft;
  final Routine? suggested;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  draft != null
                      ? 'IN PROGRESS'
                      : suggested != null
                      ? 'NEXT UP'
                      : 'READY',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bolt_rounded,
                color: colors.primaryContainer,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            draft?.name ?? suggested?.name ?? 'Start a workout',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            draft == null
                ? suggested == null
                      ? 'An empty canvas for today’s training.'
                      : 'Suggested from your recent routine rotation.'
                : 'Your sets are saved. Pick up where you left off.',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: .72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            onPressed: onPressed,
            icon: Icon(
              draft == null ? Icons.add_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(
              draft != null
                  ? 'Resume session'
                  : suggested != null
                  ? 'Start routine'
                  : 'Quick start',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.report,
    required this.goal,
    required this.onWeekly,
    required this.onMonthly,
  });
  final PeriodReport? report;
  final int goal;
  final VoidCallback onWeekly;
  final VoidCallback onMonthly;

  @override
  Widget build(BuildContext context) {
    final done = report?.workoutCount ?? 0;
    final progress = (done / goal).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onWeekly,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WEEKLY CONSISTENCY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .7,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$done of $goal workouts',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: colors.surfaceContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.calendar_month_rounded,
                color: colors.primary,
              ),
              title: const Text('Monthly progress'),
              subtitle: const Text('See volume, time and trends'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onMonthly,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'MapleMonoNF',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null)
        Text(
          action!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
