import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../data/app_database.dart';
import 'common.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  String unit = 'kg';
  String effort = 'rpe';
  String starterPack = 'full_body';

  Future<void> _finish() async {
    await ref.read(databaseProvider).installStarterPack(starterPack);
    await ref
        .read(databaseProvider)
        .saveSettings(
          AppSettingsCompanion(
            onboardingComplete: const Value(true),
            unit: Value(unit),
            effortScale: Value(effort),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ZenTrackr',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: switch (step) {
                        0 => _WelcomeStep(key: const ValueKey(0)),
                        1 => _PreferencesStep(
                          key: const ValueKey(1),
                          unit: unit,
                          effort: effort,
                          onUnitChanged: (value) =>
                              setState(() => unit = value),
                          onEffortChanged: (value) =>
                              setState(() => effort = value),
                        ),
                        2 => _StarterStep(
                          key: const ValueKey(2),
                          value: starterPack,
                          onChanged: (value) =>
                              setState(() => starterPack = value),
                        ),
                        _ => const _PrivacyStep(key: ValueKey(3)),
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: index == step ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == step
                              ? colors.primary
                              : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => step--),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: step == 3
                              ? _finish
                              : () => setState(() => step++),
                          icon: Icon(
                            step == 3
                                ? Icons.fitness_center
                                : Icons.arrow_forward,
                          ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              step == 3 ? 'Start training' : 'Continue',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.fitness_center,
    title: 'Track the work.',
    message:
        'Log every set, build reusable routines, and see your strength progress without getting in your way.',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _Feature(icon: Icons.bolt, label: 'Fast logging'),
        SizedBox(width: 20),
        _Feature(icon: Icons.insights, label: 'Clear progress'),
      ],
    ),
  );
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep({
    super.key,
    required this.unit,
    required this.effort,
    required this.onUnitChanged,
    required this.onEffortChanged,
  });
  final String unit;
  final String effort;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<String> onEffortChanged;

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.tune,
    title: 'Make it yours.',
    message:
        'Choose how ZenTrackr should display your training data. You can change these later.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Weight unit', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        AppToggle<String>(
          value: unit,
          options: const [
            AppToggleOption('kg', 'Kilograms'),
            AppToggleOption('lb', 'Pounds'),
          ],
          onChanged: onUnitChanged,
        ),
        const SizedBox(height: 22),
        Text('Effort scale', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        AppToggle<String>(
          value: effort,
          options: const [
            AppToggleOption('rpe', 'RPE'),
            AppToggleOption('rir', 'RIR'),
          ],
          onChanged: onEffortChanged,
        ),
      ],
    ),
  );
}

class _StarterStep extends StatelessWidget {
  const _StarterStep({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _StepLayout(
    icon: Icons.auto_awesome_rounded,
    title: 'Start with a solid base.',
    message: 'Choose a starter pack. Every routine remains fully editable.',
    child: Column(
      children: [
        _StarterChoice(
          value: 'full_body',
          selected: value == 'full_body',
          title: 'Full Body',
          subtitle: '2 balanced routines',
          onTap: onChanged,
        ),
        const SizedBox(height: 10),
        _StarterChoice(
          value: 'upper_lower',
          selected: value == 'upper_lower',
          title: 'Upper / Lower',
          subtitle: '2 focused routines',
          onTap: onChanged,
        ),
        const SizedBox(height: 10),
        _StarterChoice(
          value: 'ppl',
          selected: value == 'ppl',
          title: 'Push / Pull / Legs',
          subtitle: '3 familiar routines',
          onTap: onChanged,
        ),
        const SizedBox(height: 10),
        _StarterChoice(
          value: 'none',
          selected: value == 'none',
          title: 'Start empty',
          subtitle: 'Build everything yourself',
          onTap: onChanged,
        ),
      ],
    ),
  );
}

class _StarterChoice extends StatelessWidget {
  const _StarterChoice({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String value;
  final bool selected;
  final String title;
  final String subtitle;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => onTap(value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined),
        ],
      ),
    ),
  );
}

class _PrivacyStep extends StatelessWidget {
  const _PrivacyStep({super.key});

  @override
  Widget build(BuildContext context) => const _StepLayout(
    icon: Icons.lock_outline,
    title: 'Your training stays yours.',
    message:
        'ZenTrackr works without an account or internet connection. Your workouts are stored only on this device.',
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined),
            SizedBox(width: 12),
            Expanded(child: Text('No ads, no paywall, and no cloud tracking.')),
          ],
        ),
      ),
    ),
  );
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.only(top: 58),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 36),
          child,
        ],
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 6),
      Text(label),
    ],
  );
}
