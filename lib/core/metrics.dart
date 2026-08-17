import 'dart:math';
import '../data/app_database.dart';

double displayWeight(double kg, String unit) =>
    unit == 'lb' ? kg * 2.2046226218 : kg;
double canonicalWeight(double value, String unit) =>
    unit == 'lb' ? value / 2.2046226218 : value;
String formatWeight(double? kg, String unit) {
  if (kg == null) return '—';
  final value = displayWeight(kg, unit);
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

double setVolume(WorkoutSet set) => set.completed && set.setType == 'working'
    ? (set.weightKg ?? 0) * (set.reps ?? 0)
    : 0;
double? estimatedOneRepMax(WorkoutSet set) {
  final weight = set.weightKg;
  final reps = set.reps;
  if (!set.completed ||
      set.setType != 'working' ||
      weight == null ||
      weight <= 0 ||
      reps == null ||
      reps < 1 ||
      reps > 12) {
    return null;
  }
  return weight * (1 + reps / 30);
}

double maxOrZero(Iterable<double> values) => values.fold(0, max);

bool validEffort(double value, String type) {
  if (type == 'rpe') {
    return value >= 1 && value <= 10 && value * 2 == (value * 2).round();
  }
  return value >= 0 && value <= 10 && value == value.roundToDouble();
}
