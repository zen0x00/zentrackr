import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/metrics.dart';
import '../core/providers.dart';
import '../data/app_database.dart';
import 'common.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(historyProvider);
    final db = ref.watch(databaseProvider);
    final unit = ref.watch(settingsProvider).valueOrNull?.unit ?? 'kg';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<PerformancePoint>>(
          future: db.getPerformancePoints(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = <String, List<PerformancePoint>>{};
            for (final p in snap.data!) {
              groups.putIfAbsent(p.exerciseId, () => []).add(p);
            }
            if (groups.isEmpty) {
              return const EmptyState(
                icon: Icons.insights,
                title: 'No progress data',
                message: 'Complete working sets to see records and trends.',
              );
            }
            final entries = groups.entries.toList()
              ..sort(
                (a, b) => a.value.first.exerciseName.compareTo(
                  b.value.first.exerciseName,
                ),
              );
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final points = entries[i].value;
                final maxWeight = points
                    .map((p) => p.weightKg ?? 0)
                    .fold<double>(0, max);
                final maxE1rm = points
                    .map((p) => p.estimatedOneRepMax ?? 0)
                    .fold<double>(0, max);
                final maxVolume = points
                    .map((p) => p.volume)
                    .fold<double>(0, max);
                return Card(
                  child: ListTile(
                    title: Text(points.first.exerciseName),
                    subtitle: Text(
                      'Best ${formatWeight(maxWeight, unit)} $unit · e1RM ${formatWeight(maxE1rm, unit)} $unit · set volume ${formatWeight(maxVolume, unit)} $unit',
                    ),
                    trailing: const Icon(Icons.show_chart),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ExerciseProgress(points: points, unit: unit),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ExerciseProgress extends StatelessWidget {
  const ExerciseProgress({super.key, required this.points, required this.unit});
  final List<PerformancePoint> points;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final valid = points.where((p) => p.estimatedOneRepMax != null).toList();
    final spots = valid
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            displayWeight(e.value.estimatedOneRepMax!, unit),
          ),
        )
        .toList();
    final bestWeight = points.map((p) => p.weightKg ?? 0).fold<double>(0, max);
    final bestE1rm = valid
        .map((p) => p.estimatedOneRepMax ?? 0)
        .fold<double>(0, max);
    return Scaffold(
      appBar: AppBar(title: Text(points.first.exerciseName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'HEAVIEST',
                  value: '${formatWeight(bestWeight, unit)} $unit',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'BEST e1RM',
                  value: '${formatWeight(bestE1rm, unit)} $unit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Estimated 1RM trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: spots.length < 2
                ? const Center(
                    child: Text('Complete more sessions to draw a trend.'),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: Theme.of(context).colorScheme.primary,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'e1RM uses the Epley formula for working sets of 1–12 reps.',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'MapleMonoNF',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
