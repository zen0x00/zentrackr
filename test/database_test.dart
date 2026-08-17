import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentrackr/data/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('first open seeds settings and exercises', () async {
    final settings = await db.getSettings();
    expect(settings.onboardingComplete, isFalse);
    expect(settings.weeklyWorkoutGoal, 3);
    expect(settings.remindersEnabled, isFalse);
    final exercises = await db.watchExercises().first;
    expect(exercises.length, greaterThanOrEqualTo(20));
    expect(exercises.any((e) => e.name == 'Back Squat'), isTrue);
  });

  test('only one draft workout is created', () async {
    final first = await db.startWorkout();
    expect(await db.startWorkout(), first);
    expect((await db.getDraft())?.id, first);
  });

  test('routine becomes a durable workout draft', () async {
    final routineId = await db.createRoutine('Push');
    final exercise = (await db.watchExercises().first).firstWhere(
      (e) => e.id == 'barbell-bench-press',
    );
    await db.addExerciseToRoutine(routineId, exercise);
    final workoutId = await db.startWorkout(
      routine: (await db.watchRoutines().first).single,
    );
    final items = await db.getWorkoutItems(workoutId);
    expect(items.single.exerciseNameSnapshot, 'Barbell Bench Press');
    expect(await db.getSets(items.single.id), hasLength(3));
  });

  test('completed working sets produce progress points', () async {
    final exercise = (await db.watchExercises().first).firstWhere(
      (e) => e.id == 'back-squat',
    );
    final workoutId = await db.startWorkout();
    await db.addExerciseToWorkout(workoutId, exercise);
    final item = (await db.getWorkoutItems(workoutId)).single;
    final set = (await db.getSets(item.id)).first;
    await db.setWeight(set.id, 100);
    await db.setReps(set.id, 5);
    await db.setCompleted(set.id, true);
    await db.finishWorkout(workoutId);

    final point = (await db.getPerformancePoints()).single;
    expect(point.volume, 500);
    expect(point.estimatedOneRepMax, closeTo(116.67, .01));
  });

  test('previous performance can be copied into a new draft', () async {
    final exercise = (await db.watchExercises().first).firstWhere(
      (e) => e.id == 'back-squat',
    );
    final firstId = await db.startWorkout();
    await db.addExerciseToWorkout(firstId, exercise);
    final firstItem = (await db.getWorkoutItems(firstId)).single;
    final firstSet = (await db.getSets(firstItem.id)).first;
    await db.setWeight(firstSet.id, 120);
    await db.setReps(firstSet.id, 5);
    await db.setCompleted(firstSet.id, true);
    await db.finishWorkout(firstId);

    final secondId = await db.startWorkout();
    await db.addExerciseToWorkout(secondId, exercise);
    final secondItem = (await db.getWorkoutItems(secondId)).single;
    final previous = await db.getPreviousPerformance(exercise.id, secondId);
    await db.copyPreviousPerformance(secondItem.id, previous);
    final copied = (await db.getSets(secondItem.id)).first;
    expect(copied.weightKg, 120);
    expect(copied.reps, 5);
    expect(copied.completed, isFalse);
  });

  test('summary detects records against older workouts', () async {
    final exercise = (await db.watchExercises().first).firstWhere(
      (e) => e.id == 'barbell-bench-press',
    );
    Future<String> log(double weight) async {
      final id = await db.startWorkout();
      await db.addExerciseToWorkout(id, exercise);
      final item = (await db.getWorkoutItems(id)).single;
      final set = (await db.getSets(item.id)).first;
      await db.setWeight(set.id, weight);
      await db.setReps(set.id, 5);
      await db.setCompleted(set.id, true);
      await db.finishWorkout(id);
      return id;
    }

    await log(100);
    final improvedId = await log(110);
    final summary = await db.getWorkoutSummary(improvedId);
    expect(summary.records, contains(contains('heaviest weight')));
    expect(summary.records, contains(contains('estimated 1RM')));
    expect(summary.volumeKg, 550);
  });

  test('starter packs are idempotent', () async {
    await db.installStarterPack('full_body');
    await db.installStarterPack('full_body');
    final routines = await db.watchRoutines().first;
    expect(
      routines.map((r) => r.name),
      containsAll(['Full Body A', 'Full Body B']),
    );
    expect(routines, hasLength(2));
  });

  test('suggested routine advances through the routine rotation', () async {
    await db.installStarterPack('full_body');
    final first = await db.getSuggestedRoutine();
    expect(first, isNotNull);
    final workoutId = await db.startWorkout(routine: first);
    await db.finishWorkout(workoutId);
    final next = await db.getSuggestedRoutine();
    expect(next?.id, isNot(first!.id));
    expect(next?.name, 'Full Body B');
  });

  test('period report summarizes completed training', () async {
    final exercise = (await db.watchExercises().first).firstWhere(
      (e) => e.id == 'back-squat',
    );
    final workoutId = await db.startWorkout();
    await db.addExerciseToWorkout(workoutId, exercise);
    final item = (await db.getWorkoutItems(workoutId)).single;
    final set = (await db.getSets(item.id)).first;
    await db.setWeight(set.id, 80);
    await db.setReps(set.id, 5);
    await db.setCompleted(set.id, true);
    await db.finishWorkout(workoutId);

    final report = await db.getPeriodReport(
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now().add(const Duration(days: 1)),
    );
    expect(report.workoutCount, 1);
    expect(report.activeDays, 1);
    expect(report.setCount, 1);
    expect(report.volumeKg, 400);
    expect(report.topExercise, 'Back Squat');
  });

  test('JSON backup restores user data', () async {
    await db.installStarterPack('upper_lower');
    await db.createCustomExercise('Seal Row', 'Back', 'Barbell', 'weight_reps');
    final backup = await db.exportBackupJson();
    await db.clearUserData();
    expect(await db.watchRoutines().first, isEmpty);

    await db.importBackupJson(backup);
    expect(await db.watchRoutines().first, hasLength(2));
    expect(
      (await db.watchExercises().first).any((e) => e.name == 'Seal Row'),
      isTrue,
    );
  });
}
