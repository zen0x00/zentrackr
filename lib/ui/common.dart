import 'package:flutter/material.dart';
import '../data/app_database.dart';

Future<Exercise?> pickExercise(
  BuildContext context,
  List<Exercise> exercises,
) async {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExercisePicker(exercises: exercises),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.exercises});
  final List<Exercise> exercises;
  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises
        .where(
          (e) => '${e.name} ${e.primaryMuscle} ${e.equipment}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search by name, muscle, or equipment',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final e = filtered[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.primaryMuscle} · ${e.equipment}'),
                  onTap: () => Navigator.pop(context, e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class AppToggleOption<T> {
  const AppToggleOption(this.value, this.label);
  final T value;
  final String label;
}

class AppToggle<T> extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width,
  });

  final T value;
  final List<AppToggleOption<T>> options;
  final ValueChanged<T> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: options.map((option) {
              final selected = option.value == value;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(option.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: .18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: selected
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        child: Text(option.label),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
