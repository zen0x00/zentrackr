import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'routines_screen.dart';
import 'history_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  static const pages = [
    HomeScreen(),
    RoutinesScreen(),
    HistoryScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (v) => setState(() => index = v),
          items: const [
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.home_outlined),
              activeIcon: _NavIcon(icon: Icons.home_rounded, selected: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.space_dashboard_outlined),
              activeIcon: _NavIcon(
                icon: Icons.space_dashboard_rounded,
                selected: true,
              ),
              label: 'Routines',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.history_rounded),
              activeIcon: _NavIcon(icon: Icons.history_rounded, selected: true),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.auto_graph_outlined),
              activeIcon: _NavIcon(
                icon: Icons.auto_graph_rounded,
                selected: true,
              ),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(icon: Icons.tune_outlined),
              activeIcon: _NavIcon(icon: Icons.tune_rounded, selected: true),
              label: 'Settings',
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 38,
    height: 31,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: selected ? 1.08 : 1,
          child: Icon(icon, size: 22),
        ),
        Positioned(
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 4 : 0,
            height: selected ? 4 : 0,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}
