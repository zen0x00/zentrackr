import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  TextColumn get effortScale => text().withDefault(const Constant('rpe'))();
  IntColumn get defaultRestSeconds =>
      integer().withDefault(const Constant(120))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  IntColumn get weeklyWorkoutGoal => integer().withDefault(const Constant(3))();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get reminderDays => text().withDefault(const Constant('1,3,5'))();
  IntColumn get reminderHour => integer().withDefault(const Constant(18))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  TextColumn get equipment => text()();
  TextColumn get trackingType =>
      text().withDefault(const Constant('weight_reps'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  @override
  Set<Column> get primaryKey => {id};
}

class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  @override
  Set<Column> get primaryKey => {id};
}

class RoutineItems extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().references(Routines, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class RoutineSetTargets extends Table {
  TextColumn get id => text()();
  TextColumn get routineItemId => text().references(RoutineItems, #id)();
  IntColumn get position => integer()();
  TextColumn get setType => text().withDefault(const Constant('working'))();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  RealColumn get targetEffort => real().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get routineId => text().nullable().references(Routines, #id)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutItems extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get exerciseNameSnapshot => text()();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get workoutItemId => text().references(WorkoutItems, #id)();
  IntColumn get position => integer()();
  TextColumn get setType => text().withDefault(const Constant('working'))();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get effortValue => real().nullable()();
  TextColumn get effortType => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppSettings,
    Exercises,
    Routines,
    RoutineItems,
    RoutineSetTargets,
    Workouts,
    WorkoutItems,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static const uuid = Uuid();
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettings).insert(const AppSettingsCompanion());
      await _seedExercises();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(appSettings, appSettings.weeklyWorkoutGoal);
        await m.addColumn(appSettings, appSettings.remindersEnabled);
        await m.addColumn(appSettings, appSettings.reminderDays);
        await m.addColumn(appSettings, appSettings.reminderHour);
        await m.addColumn(appSettings, appSettings.reminderMinute);
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _seedExercises() async {
    const data = [
      (
        'barbell-bench-press',
        'Barbell Bench Press',
        'Chest',
        'Barbell',
        'weight_reps',
      ),
      ('back-squat', 'Back Squat', 'Quadriceps', 'Barbell', 'weight_reps'),
      ('deadlift', 'Deadlift', 'Back', 'Barbell', 'weight_reps'),
      (
        'overhead-press',
        'Overhead Press',
        'Shoulders',
        'Barbell',
        'weight_reps',
      ),
      ('barbell-row', 'Barbell Row', 'Back', 'Barbell', 'weight_reps'),
      ('pull-up', 'Pull-up', 'Back', 'Bodyweight', 'bodyweight_reps'),
      ('chin-up', 'Chin-up', 'Back', 'Bodyweight', 'bodyweight_reps'),
      ('dip', 'Dip', 'Chest', 'Bodyweight', 'bodyweight_reps'),
      ('push-up', 'Push-up', 'Chest', 'Bodyweight', 'bodyweight_reps'),
      ('front-squat', 'Front Squat', 'Quadriceps', 'Barbell', 'weight_reps'),
      (
        'romanian-deadlift',
        'Romanian Deadlift',
        'Hamstrings',
        'Barbell',
        'weight_reps',
      ),
      ('leg-press', 'Leg Press', 'Quadriceps', 'Machine', 'weight_reps'),
      ('lat-pulldown', 'Lat Pulldown', 'Back', 'Cable', 'weight_reps'),
      ('cable-row', 'Seated Cable Row', 'Back', 'Cable', 'weight_reps'),
      (
        'dumbbell-bench',
        'Dumbbell Bench Press',
        'Chest',
        'Dumbbell',
        'weight_reps',
      ),
      (
        'incline-dumbbell-bench',
        'Incline Dumbbell Press',
        'Chest',
        'Dumbbell',
        'weight_reps',
      ),
      (
        'lateral-raise',
        'Lateral Raise',
        'Shoulders',
        'Dumbbell',
        'weight_reps',
      ),
      ('barbell-curl', 'Barbell Curl', 'Biceps', 'Barbell', 'weight_reps'),
      (
        'triceps-pushdown',
        'Triceps Pushdown',
        'Triceps',
        'Cable',
        'weight_reps',
      ),
      ('calf-raise', 'Standing Calf Raise', 'Calves', 'Machine', 'weight_reps'),
    ];
    await batch((b) {
      b.insertAll(
        exercises,
        data
            .map(
              (e) => ExercisesCompanion.insert(
                id: e.$1,
                name: e.$2,
                primaryMuscle: e.$3,
                equipment: e.$4,
                trackingType: Value(e.$5),
              ),
            )
            .toList(),
      );
    });
  }

  Stream<AppSetting> watchSettings() => select(appSettings).watchSingle();
  Future<AppSetting> getSettings() => select(appSettings).getSingle();
  Future<void> saveSettings(AppSettingsCompanion value) =>
      (update(appSettings)..where((t) => t.id.equals(1))).write(value);
  Stream<List<Exercise>> watchExercises() =>
      (select(exercises)
            ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();
  Stream<List<Routine>> watchRoutines() =>
      (select(routines)
            ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();
  Stream<List<Workout>> watchHistory() =>
      (select(workouts)
            ..where((t) => t.status.equals('completed') & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .watch();
  Stream<Workout?> watchDraft() =>
      (select(workouts)
            ..where((t) => t.status.equals('draft'))
            ..limit(1))
          .watchSingleOrNull();
  Future<Workout?> getDraft() =>
      (select(workouts)
            ..where((t) => t.status.equals('draft'))
            ..limit(1))
          .getSingleOrNull();

  Future<String> createCustomExercise(
    String name,
    String muscle,
    String equipment,
    String trackingType,
  ) async {
    final id = uuid.v4();
    await into(exercises).insert(
      ExercisesCompanion.insert(
        id: id,
        name: name.trim(),
        primaryMuscle: muscle,
        equipment: equipment,
        trackingType: Value(trackingType),
        isCustom: const Value(true),
      ),
    );
    return id;
  }

  Future<void> updateCustomExercise(
    String id,
    String name,
    String muscle,
    String equipment,
    String trackingType,
  ) =>
      (update(
        exercises,
      )..where((t) => t.id.equals(id) & t.isCustom.equals(true))).write(
        ExercisesCompanion(
          name: Value(name.trim()),
          primaryMuscle: Value(muscle),
          equipment: Value(equipment),
          trackingType: Value(trackingType),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<String> createRoutine(String name) async {
    final id = uuid.v4();
    await into(
      routines,
    ).insert(RoutinesCompanion.insert(id: id, name: name.trim()));
    return id;
  }

  Future<void> addExerciseToRoutine(String routineId, Exercise exercise) async {
    final maxPos =
        await (selectOnly(routineItems)
              ..addColumns([routineItems.position.max()])
              ..where(routineItems.routineId.equals(routineId)))
            .getSingle();
    final itemId = uuid.v4();
    await transaction(() async {
      await into(routineItems).insert(
        RoutineItemsCompanion.insert(
          id: itemId,
          routineId: routineId,
          exerciseId: exercise.id,
          position: (maxPos.read(routineItems.position.max()) ?? -1) + 1,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await into(routineSetTargets).insert(
          RoutineSetTargetsCompanion.insert(
            id: uuid.v4(),
            routineItemId: itemId,
            position: i,
          ),
        );
      }
      await (update(routines)..where((t) => t.id.equals(routineId))).write(
        RoutinesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<String> startWorkout({Routine? routine}) async {
    final existing = await getDraft();
    if (existing != null) return existing.id;
    final id = uuid.v4();
    await transaction(() async {
      await into(workouts).insert(
        WorkoutsCompanion.insert(
          id: id,
          name: routine?.name ?? 'Workout',
          routineId: Value(routine?.id),
          startedAt: DateTime.now(),
        ),
      );
      if (routine != null) {
        final items =
            await (select(routineItems)
                  ..where((t) => t.routineId.equals(routine.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        for (final item in items) {
          final exercise = await (select(
            exercises,
          )..where((t) => t.id.equals(item.exerciseId))).getSingle();
          final workoutItemId = uuid.v4();
          await into(workoutItems).insert(
            WorkoutItemsCompanion.insert(
              id: workoutItemId,
              workoutId: id,
              exerciseId: exercise.id,
              exerciseNameSnapshot: exercise.name,
              position: item.position,
            ),
          );
          final targets =
              await (select(routineSetTargets)
                    ..where((t) => t.routineItemId.equals(item.id))
                    ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                  .get();
          for (final target in targets) {
            await into(workoutSets).insert(
              WorkoutSetsCompanion.insert(
                id: uuid.v4(),
                workoutItemId: workoutItemId,
                position: target.position,
                setType: Value(target.setType),
                weightKg: Value(target.targetWeightKg),
                reps: Value(target.targetReps),
                effortValue: Value(target.targetEffort),
              ),
            );
          }
        }
      }
    });
    return id;
  }

  Future<void> addExerciseToWorkout(String workoutId, Exercise exercise) async {
    final maxPos =
        await (selectOnly(workoutItems)
              ..addColumns([workoutItems.position.max()])
              ..where(workoutItems.workoutId.equals(workoutId)))
            .getSingle();
    final itemId = uuid.v4();
    await transaction(() async {
      await into(workoutItems).insert(
        WorkoutItemsCompanion.insert(
          id: itemId,
          workoutId: workoutId,
          exerciseId: exercise.id,
          exerciseNameSnapshot: exercise.name,
          position: (maxPos.read(workoutItems.position.max()) ?? -1) + 1,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await into(workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: uuid.v4(),
            workoutItemId: itemId,
            position: i,
          ),
        );
      }
      await touchWorkout(workoutId);
    });
  }

  Stream<List<WorkoutItem>> watchWorkoutItems(String workoutId) =>
      (select(workoutItems)
            ..where((t) => t.workoutId.equals(workoutId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();
  Stream<List<WorkoutSet>> watchSets(String itemId) =>
      (select(workoutSets)
            ..where((t) => t.workoutItemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();
  Future<List<WorkoutItem>> getWorkoutItems(String workoutId) =>
      (select(workoutItems)
            ..where((t) => t.workoutId.equals(workoutId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
  Future<Workout> getWorkout(String workoutId) =>
      (select(workouts)..where((t) => t.id.equals(workoutId))).getSingle();
  Future<List<WorkoutSet>> getSets(String itemId) =>
      (select(workoutSets)
            ..where((t) => t.workoutItemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
  Future<List<RoutineItem>> getRoutineItems(String routineId) =>
      (select(routineItems)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
  Stream<List<RoutineItem>> watchRoutineItems(String routineId) =>
      (select(routineItems)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();
  Stream<List<RoutineSetTarget>> watchRoutineTargets(String itemId) =>
      (select(routineSetTargets)
            ..where((t) => t.routineItemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();
  Future<void> setRoutineReps(String id, int? value) =>
      (update(routineSetTargets)..where((t) => t.id.equals(id))).write(
        RoutineSetTargetsCompanion(targetReps: Value(value)),
      );
  Future<void> setRoutineWeight(String id, double? value) =>
      (update(routineSetTargets)..where((t) => t.id.equals(id))).write(
        RoutineSetTargetsCompanion(targetWeightKg: Value(value)),
      );
  Future<void> setRoutineEffort(String id, double? value) =>
      (update(routineSetTargets)..where((t) => t.id.equals(id))).write(
        RoutineSetTargetsCompanion(targetEffort: Value(value)),
      );
  Future<void> addRoutineTarget(String itemId) async {
    final rows = await (select(
      routineSetTargets,
    )..where((t) => t.routineItemId.equals(itemId))).get();
    await into(routineSetTargets).insert(
      RoutineSetTargetsCompanion.insert(
        id: uuid.v4(),
        routineItemId: itemId,
        position: rows.length,
      ),
    );
  }

  Future<void> removeRoutineItem(String id) => transaction(() async {
    await (delete(
      routineSetTargets,
    )..where((t) => t.routineItemId.equals(id))).go();
    await (delete(routineItems)..where((t) => t.id.equals(id))).go();
  });
  Future<String> duplicateRoutine(Routine source) async {
    final newId = await createRoutine('${source.name} copy');
    final items = await getRoutineItems(source.id);
    for (final item in items) {
      final exercise = await (select(
        exercises,
      )..where((t) => t.id.equals(item.exerciseId))).getSingle();
      await addExerciseToRoutine(newId, exercise);
    }
    return newId;
  }

  Future<void> setWeight(String id, double? value) =>
      (update(workoutSets)..where((t) => t.id.equals(id))).write(
        WorkoutSetsCompanion(weightKg: Value(value)),
      );
  Future<void> setReps(String id, int? value) =>
      (update(workoutSets)..where((t) => t.id.equals(id))).write(
        WorkoutSetsCompanion(reps: Value(value)),
      );
  Future<void> setEffort(String id, double? value, String effortType) =>
      (update(workoutSets)..where((t) => t.id.equals(id))).write(
        WorkoutSetsCompanion(
          effortValue: Value(value),
          effortType: Value(value == null ? null : effortType),
        ),
      );
  Future<void> setCompleted(String id, bool value) =>
      (update(workoutSets)..where((t) => t.id.equals(id))).write(
        WorkoutSetsCompanion(
          completed: Value(value),
          completedAt: Value(value ? DateTime.now() : null),
        ),
      );
  Future<void> setKind(String id, String value) =>
      (update(workoutSets)..where((t) => t.id.equals(id))).write(
        WorkoutSetsCompanion(setType: Value(value)),
      );

  Future<void> addSet(String itemId) async {
    final rows = await getSets(itemId);
    final previous = rows.isEmpty ? null : rows.last;
    await into(workoutSets).insert(
      WorkoutSetsCompanion.insert(
        id: uuid.v4(),
        workoutItemId: itemId,
        position: rows.length,
        weightKg: Value(previous?.weightKg),
        reps: Value(previous?.reps),
      ),
    );
  }

  Future<void> removeSet(String id) =>
      (delete(workoutSets)..where((t) => t.id.equals(id))).go();
  Future<void> removeWorkoutItem(String id) => transaction(() async {
    await (delete(workoutSets)..where((t) => t.workoutItemId.equals(id))).go();
    await (delete(workoutItems)..where((t) => t.id.equals(id))).go();
  });
  Future<void> finishWorkout(String id) =>
      (update(workouts)..where((t) => t.id.equals(id))).write(
        WorkoutsCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
  Future<void> discardWorkout(String id) =>
      (update(workouts)..where((t) => t.id.equals(id))).write(
        WorkoutsCompanion(
          status: const Value('discarded'),
          updatedAt: Value(DateTime.now()),
        ),
      );
  Future<void> archiveRoutine(String id) =>
      (update(routines)..where((t) => t.id.equals(id))).write(
        RoutinesCompanion(
          archived: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
  Future<void> archiveExercise(String id) =>
      (update(exercises)..where((t) => t.id.equals(id))).write(
        ExercisesCompanion(
          archived: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
  Future<void> touchWorkout(String id) =>
      (update(workouts)..where((t) => t.id.equals(id))).write(
        WorkoutsCompanion(updatedAt: Value(DateTime.now())),
      );

  Future<List<PreviousSet>> getPreviousPerformance(
    String exerciseId,
    String excludingWorkoutId,
  ) async {
    final rows = await customSelect(
      '''
      SELECT ws.weight_kg, ws.reps, ws.effort_value, ws.effort_type, ws.set_type
      FROM workout_sets ws
      JOIN workout_items wi ON wi.id = ws.workout_item_id
      JOIN workouts w ON w.id = wi.workout_id
      WHERE wi.exercise_id = ? AND w.status = 'completed' AND w.id != ? AND ws.completed = 1
        AND w.id = (
          SELECT w2.id FROM workouts w2
          JOIN workout_items wi2 ON wi2.workout_id = w2.id
          WHERE wi2.exercise_id = ? AND w2.status = 'completed' AND w2.id != ?
          ORDER BY w2.completed_at DESC LIMIT 1
        )
      ORDER BY ws.position
      ''',
      variables: [
        Variable.withString(exerciseId),
        Variable.withString(excludingWorkoutId),
        Variable.withString(exerciseId),
        Variable.withString(excludingWorkoutId),
      ],
      readsFrom: {workoutSets, workoutItems, workouts},
    ).get();
    return rows
        .map(
          (r) => PreviousSet(
            weightKg: r.readNullable<double>('weight_kg'),
            reps: r.readNullable<int>('reps'),
            effort: r.readNullable<double>('effort_value'),
            effortType: r.readNullable<String>('effort_type'),
            setType: r.read<String>('set_type'),
          ),
        )
        .toList();
  }

  Future<void> copyPreviousPerformance(
    String workoutItemId,
    List<PreviousSet> previous,
  ) async {
    await transaction(() async {
      var current = await getSets(workoutItemId);
      while (current.length < previous.length) {
        await addSet(workoutItemId);
        current = await getSets(workoutItemId);
      }
      for (var i = 0; i < previous.length; i++) {
        final source = previous[i];
        await (update(
          workoutSets,
        )..where((t) => t.id.equals(current[i].id))).write(
          WorkoutSetsCompanion(
            weightKg: Value(source.weightKg),
            reps: Value(source.reps),
            effortValue: Value(source.effort),
            effortType: Value(source.effortType),
            setType: Value(source.setType),
            completed: const Value(false),
            completedAt: const Value(null),
          ),
        );
      }
    });
  }

  Future<WorkoutSummaryData> getWorkoutSummary(String workoutId) async {
    final workout = await getWorkout(workoutId);
    final items = await getWorkoutItems(workoutId);
    var completedSets = 0;
    var volumeKg = 0.0;
    final records = <String>[];
    for (final item in items) {
      final current = (await getSets(
        item.id,
      )).where((s) => s.completed && s.setType == 'working').toList();
      completedSets += current.length;
      volumeKg += current.fold<double>(
        0,
        (sum, s) => sum + (s.weightKg ?? 0) * (s.reps ?? 0),
      );
      if (current.isEmpty) continue;
      final history = await customSelect(
        '''
        SELECT ws.weight_kg, ws.reps FROM workout_sets ws
        JOIN workout_items wi ON wi.id = ws.workout_item_id
        JOIN workouts w ON w.id = wi.workout_id
        WHERE wi.exercise_id = ? AND w.status = 'completed' AND w.id != ?
          AND ws.completed = 1 AND ws.set_type = 'working'
        ''',
        variables: [
          Variable.withString(item.exerciseId),
          Variable.withString(workoutId),
        ],
        readsFrom: {workoutSets, workoutItems, workouts},
      ).get();
      final oldWeight = history.fold<double>(
        0,
        (best, r) => max(best, r.readNullable<double>('weight_kg') ?? 0),
      );
      final oldVolume = history.fold<double>(0, (best, r) {
        final value =
            (r.readNullable<double>('weight_kg') ?? 0) *
            (r.readNullable<int>('reps') ?? 0);
        return max(best, value);
      });
      final oldE1rm = history.fold<double>(0, (best, r) {
        final weight = r.readNullable<double>('weight_kg') ?? 0;
        final reps = r.readNullable<int>('reps') ?? 0;
        return max(
          best,
          reps >= 1 && reps <= 12 ? weight * (1 + reps / 30) : 0,
        );
      });
      final newWeight = current.fold<double>(
        0,
        (best, s) => max(best, s.weightKg ?? 0),
      );
      final newVolume = current.fold<double>(
        0,
        (best, s) => max(best, (s.weightKg ?? 0) * (s.reps ?? 0)),
      );
      final newE1rm = current.fold<double>(0, (best, s) {
        final reps = s.reps ?? 0;
        return max(
          best,
          reps >= 1 && reps <= 12 ? (s.weightKg ?? 0) * (1 + reps / 30) : 0,
        );
      });
      if (history.isNotEmpty && newWeight > oldWeight) {
        records.add('${item.exerciseNameSnapshot}: heaviest weight');
      }
      if (history.isNotEmpty && newE1rm > oldE1rm) {
        records.add('${item.exerciseNameSnapshot}: estimated 1RM');
      }
      if (history.isNotEmpty && newVolume > oldVolume) {
        records.add('${item.exerciseNameSnapshot}: set volume');
      }
    }
    final end = workout.completedAt ?? DateTime.now();
    return WorkoutSummaryData(
      workout: workout,
      exerciseCount: items.length,
      completedSets: completedSets,
      duration: end.difference(workout.startedAt),
      volumeKg: volumeKg,
      records: records.toSet().toList(),
    );
  }

  Future<void> clearUserData() async => transaction(() async {
    await delete(workoutSets).go();
    await delete(workoutItems).go();
    await delete(workouts).go();
    await delete(routineSetTargets).go();
    await delete(routineItems).go();
    await delete(routines).go();
    await (delete(exercises)..where((t) => t.isCustom.equals(true))).go();
  });

  Future<List<PerformancePoint>> getPerformancePoints() async {
    final rows = await customSelect(
      '''
      SELECT wi.exercise_id, wi.exercise_name_snapshot, ws.weight_kg, ws.reps,
             ws.set_type, w.completed_at
      FROM workout_sets ws
      JOIN workout_items wi ON wi.id = ws.workout_item_id
      JOIN workouts w ON w.id = wi.workout_id
      WHERE w.status = 'completed' AND ws.completed = 1 AND ws.set_type = 'working'
      ORDER BY w.completed_at ASC
    ''',
      readsFrom: {workoutSets, workoutItems, workouts},
    ).get();
    return rows
        .map(
          (r) => PerformancePoint(
            exerciseId: r.read<String>('exercise_id'),
            exerciseName: r.read<String>('exercise_name_snapshot'),
            weightKg: r.readNullable<double>('weight_kg'),
            reps: r.readNullable<int>('reps'),
            completedAt: r.readNullable<int>('completed_at') == null
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(
                    r.read<int>('completed_at') * 1000,
                  ),
          ),
        )
        .toList();
  }

  Future<void> installStarterPack(String pack) async {
    final definitions = switch (pack) {
      'full_body' => {
        'Full Body A': ['back-squat', 'barbell-bench-press', 'barbell-row'],
        'Full Body B': ['deadlift', 'overhead-press', 'pull-up'],
      },
      'upper_lower' => {
        'Upper': [
          'barbell-bench-press',
          'barbell-row',
          'overhead-press',
          'lat-pulldown',
        ],
        'Lower': ['back-squat', 'romanian-deadlift', 'leg-press', 'calf-raise'],
      },
      'ppl' => {
        'Push': [
          'barbell-bench-press',
          'overhead-press',
          'incline-dumbbell-bench',
          'triceps-pushdown',
        ],
        'Pull': ['deadlift', 'pull-up', 'barbell-row', 'barbell-curl'],
        'Legs': ['back-squat', 'romanian-deadlift', 'leg-press', 'calf-raise'],
      },
      _ => <String, List<String>>{},
    };
    for (final entry in definitions.entries) {
      final existing =
          await (select(routines)
                ..where((t) => t.name.equals(entry.key) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing != null) continue;
      final routineId = await createRoutine(entry.key);
      for (final exerciseId in entry.value) {
        final exercise = await (select(
          exercises,
        )..where((t) => t.id.equals(exerciseId))).getSingle();
        await addExerciseToRoutine(routineId, exercise);
      }
    }
  }

  Future<String> exportBackupJson() async {
    final custom = await (select(
      exercises,
    )..where((t) => t.isCustom.equals(true))).get();
    final payload = {
      'format': 'zentrackr-backup',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': (await getSettings()).toJson(),
      'custom_exercises': custom.map((e) => e.toJson()).toList(),
      'routines': (await select(
        routines,
      ).get()).map((e) => e.toJson()).toList(),
      'routine_items': (await select(
        routineItems,
      ).get()).map((e) => e.toJson()).toList(),
      'routine_set_targets': (await select(
        routineSetTargets,
      ).get()).map((e) => e.toJson()).toList(),
      'workouts': (await select(
        workouts,
      ).get()).map((e) => e.toJson()).toList(),
      'workout_items': (await select(
        workoutItems,
      ).get()).map((e) => e.toJson()).toList(),
      'workout_sets': (await select(
        workoutSets,
      ).get()).map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackupJson(String source) async {
    final payload = jsonDecode(source);
    if (payload is! Map<String, dynamic> ||
        payload['format'] != 'zentrackr-backup' ||
        payload['version'] != 1) {
      throw const FormatException('Not a supported ZenTrackr backup.');
    }
    List<Map<String, dynamic>> rows(String key) =>
        (payload[key] as List? ?? []).cast<Map<String, dynamic>>();
    await transaction(() async {
      await clearUserData();
      for (final row in rows('custom_exercises')) {
        await into(exercises).insertOnConflictUpdate(Exercise.fromJson(row));
      }
      for (final row in rows('routines')) {
        await into(routines).insertOnConflictUpdate(Routine.fromJson(row));
      }
      for (final row in rows('routine_items')) {
        await into(
          routineItems,
        ).insertOnConflictUpdate(RoutineItem.fromJson(row));
      }
      for (final row in rows('routine_set_targets')) {
        await into(
          routineSetTargets,
        ).insertOnConflictUpdate(RoutineSetTarget.fromJson(row));
      }
      for (final row in rows('workouts')) {
        await into(workouts).insertOnConflictUpdate(Workout.fromJson(row));
      }
      for (final row in rows('workout_items')) {
        await into(
          workoutItems,
        ).insertOnConflictUpdate(WorkoutItem.fromJson(row));
      }
      for (final row in rows('workout_sets')) {
        await into(
          workoutSets,
        ).insertOnConflictUpdate(WorkoutSet.fromJson(row));
      }
      final settingsJson = payload['settings'];
      if (settingsJson is Map<String, dynamic>) {
        await into(
          appSettings,
        ).insertOnConflictUpdate(AppSetting.fromJson(settingsJson));
      }
    });
  }

  Future<Routine?> getSuggestedRoutine() async {
    final available =
        await (select(routines)
              ..where((t) => t.archived.equals(false) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (available.isEmpty) return null;
    final last =
        await (select(workouts)
              ..where(
                (t) =>
                    t.status.equals('completed') &
                    t.routineId.isNotNull() &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (last?.routineId == null) return available.first;
    final index = available.indexWhere((r) => r.id == last!.routineId);
    return index < 0
        ? available.first
        : available[(index + 1) % available.length];
  }

  Future<PeriodReport> getPeriodReport(DateTime start, DateTime end) async {
    final workoutRows = await customSelect(
      '''
      SELECT COUNT(*) AS workout_count,
             COALESCE(SUM(completed_at - started_at), 0) AS duration_seconds,
             COUNT(DISTINCT date(completed_at, 'unixepoch', 'localtime')) AS active_days
      FROM workouts
      WHERE status = 'completed' AND deleted_at IS NULL
        AND completed_at >= ? AND completed_at < ?
      ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {workouts},
    ).getSingle();
    final setRows = await customSelect(
      '''
      SELECT COUNT(*) AS set_count,
             COALESCE(SUM(COALESCE(ws.weight_kg, 0) * COALESCE(ws.reps, 0)), 0.0) AS volume_kg
      FROM workout_sets ws
      JOIN workout_items wi ON wi.id = ws.workout_item_id
      JOIN workouts w ON w.id = wi.workout_id
      WHERE w.status = 'completed' AND w.deleted_at IS NULL
        AND w.completed_at >= ? AND w.completed_at < ?
        AND ws.completed = 1 AND ws.set_type = 'working'
      ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {workoutSets, workoutItems, workouts},
    ).getSingle();
    final top = await customSelect(
      '''
      SELECT wi.exercise_name_snapshot AS name,
             SUM(COALESCE(ws.weight_kg, 0) * COALESCE(ws.reps, 0)) AS volume
      FROM workout_sets ws
      JOIN workout_items wi ON wi.id = ws.workout_item_id
      JOIN workouts w ON w.id = wi.workout_id
      WHERE w.status = 'completed' AND w.deleted_at IS NULL
        AND w.completed_at >= ? AND w.completed_at < ?
        AND ws.completed = 1 AND ws.set_type = 'working'
      GROUP BY wi.exercise_id ORDER BY volume DESC LIMIT 1
      ''',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
      readsFrom: {workoutSets, workoutItems, workouts},
    ).getSingleOrNull();
    return PeriodReport(
      start: start,
      end: end,
      workoutCount: workoutRows.read<int>('workout_count'),
      activeDays: workoutRows.read<int>('active_days'),
      duration: Duration(seconds: workoutRows.read<int>('duration_seconds')),
      setCount: setRows.read<int>('set_count'),
      volumeKg: setRows.read<double>('volume_kg'),
      topExercise: top?.readNullable<String>('name'),
    );
  }
}

class PreviousSet {
  const PreviousSet({
    required this.weightKg,
    required this.reps,
    required this.effort,
    required this.effortType,
    required this.setType,
  });
  final double? weightKg;
  final int? reps;
  final double? effort;
  final String? effortType;
  final String setType;
}

class WorkoutSummaryData {
  const WorkoutSummaryData({
    required this.workout,
    required this.exerciseCount,
    required this.completedSets,
    required this.duration,
    required this.volumeKg,
    required this.records,
  });
  final Workout workout;
  final int exerciseCount;
  final int completedSets;
  final Duration duration;
  final double volumeKg;
  final List<String> records;
}

class PeriodReport {
  const PeriodReport({
    required this.start,
    required this.end,
    required this.workoutCount,
    required this.activeDays,
    required this.duration,
    required this.setCount,
    required this.volumeKg,
    required this.topExercise,
  });
  final DateTime start;
  final DateTime end;
  final int workoutCount;
  final int activeDays;
  final Duration duration;
  final int setCount;
  final double volumeKg;
  final String? topExercise;
}

class PerformancePoint {
  const PerformancePoint({
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
  });
  final String exerciseId;
  final String exerciseName;
  final double? weightKg;
  final int? reps;
  final DateTime completedAt;
  double get volume => (weightKg ?? 0) * (reps ?? 0);
  double? get estimatedOneRepMax =>
      weightKg == null ||
          weightKg! <= 0 ||
          reps == null ||
          reps! < 1 ||
          reps! > 12
      ? null
      : weightKg! * (1 + reps! / 30);
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  // The directory can be absent in minimal Linux desktop environments.
  await dir.create(recursive: true);
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'zentrackr.sqlite')),
  );
});
