import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'timer_screen.dart';
import 'projects_screen.dart';
import 'reports_entry_screen.dart';
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
    ReportsEntryScreen(),
  ];

  void _onTap(int index) => setState(() => _currentIndex = index);

  // 底部导航 item：图标 + 文字，选中态高亮。
  // 用 Expanded 平分宽度，中间 SizedBox(56) 给 FAB notch 留位。
  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData outline,
    required IconData filled,
    required String label,
  }) {
    final selected = _currentIndex == index;
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? filled : outline, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // BottomAppBar + CircularNotchedRectangle：FAB centerDocked 时底部留 notch，
      // 避免 FAB 遮挡导航 item（此前用 BottomNavigationBar 时 FAB 盖住中间 item）。
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _buildNavItem(
              context,
              index: 0,
              outline: Icons.dashboard_outlined,
              filled: Icons.dashboard,
              label: AppLocalizations.t('home'),
            ),
            _buildNavItem(
              context,
              index: 1,
              outline: Icons.timer_outlined,
              filled: Icons.timer,
              label: AppLocalizations.t('timer'),
            ),
            const SizedBox(width: 56), // FAB notch 占位
            _buildNavItem(
              context,
              index: 2,
              outline: Icons.folder_outlined,
              filled: Icons.folder,
              label: AppLocalizations.t('projects'),
            ),
            _buildNavItem(
              context,
              index: 3,
              outline: Icons.bar_chart_outlined,
              filled: Icons.bar_chart,
              label: AppLocalizations.t('reports'),
            ),
          ],
        ),
      ),
      // Timer 页本身是计时入口，隐藏 FAB 避免重复；其他页 FAB 一键开始计时。
      floatingActionButton: _currentIndex == 1
          ? null
          : FloatingActionButton(
              heroTag: 'main-timer-fab',
              onPressed: () => _onTap(1),
              child: const Icon(Icons.play_arrow),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
