import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'timer_screen.dart';
import 'projects_screen.dart';
import 'monthly_report_screen.dart';
import '../l10n/app_localizations.dart';
import '../config/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    TimerScreen(),
    ProjectsScreen(),
    MonthlyReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: AppLocalizations.t('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timer_outlined),
            activeIcon: const Icon(Icons.timer),
            label: AppLocalizations.t('timer'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_outlined),
            activeIcon: const Icon(Icons.folder),
            label: AppLocalizations.t('projects'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            activeIcon: const Icon(Icons.bar_chart),
            label: AppLocalizations.t('reports'),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? null
          : FloatingActionButton(
              heroTag: 'main-timer-fab',
              onPressed: () => setState(() => _currentIndex = 1),
              child: const Icon(Icons.play_arrow),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
