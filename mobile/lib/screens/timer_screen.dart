import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timelog_provider.dart';
import '../providers/project_provider.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/currency_format.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 每秒刷新UI，让计时器数字实时跳动
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = context.watch<TimelogProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('timer'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 项目选择
            _buildProjectSelector(timerProvider, projectProvider),
            if (timerProvider.timerState == TimerState.idle && projectProvider.hasReachedFreeLimit) ...[
              const SizedBox(height: 12),
              _buildUpgradeHint(),
            ],
            const SizedBox(height: 32),
            // 计时器显示
            _buildTimerDisplay(timerProvider),
            const SizedBox(height: 32),
            // 标签和备注
            if (timerProvider.timerState != TimerState.idle) _buildTagAndNote(timerProvider),
            const Spacer(),
            // 控制按钮
            _buildControls(timerProvider, projectProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectSelector(TimelogProvider timer, ProjectProvider projects) {
    if (timer.timerState != TimerState.idle) {
      final project = projects.getProjectById(timer.currentProjectId ?? '');
      return Card(
        child: ListTile(
          title: Text(project?.projectName ?? AppLocalizations.t('unknownProject')),
          subtitle: Text(project?.clientName ?? ''),
          trailing: Text('${CurrencyFormat.symbol()}${project?.hourlyRate.toStringAsFixed(2) ?? '0'}/hr'),
        ),
      );
    }
    if (projects.activeProjects.isEmpty) {
      return Card(
        color: AppTheme.primary.withValues(alpha: 0.06),
        child: ListTile(
          leading: const Icon(Icons.info_outline, color: AppTheme.primary),
          title: Text(AppLocalizations.t('noProjectYet')),
          subtitle: Text(AppLocalizations.t('noProjectTimerHint')),
          onTap: () => Navigator.pushNamed(context, '/projects'),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: timer.currentProjectId,
      decoration: InputDecoration(labelText: AppLocalizations.t('selectProject')),
      items: projects.activeProjects.map((p) {
        return DropdownMenuItem(
          value: p.projectId,
          child: Text('${p.projectName} - ${CurrencyFormat.symbol()}${p.hourlyRate.toStringAsFixed(2)}/hr'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) timer.selectProject(value);
      },
    );
  }

  Widget _buildUpgradeHint() {
    return Card(
      color: AppTheme.primary.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.lock_outline, color: AppTheme.primary),
        title: Text(AppLocalizations.t('freePlanLimitReached')),
        subtitle: Text(AppLocalizations.t('upgradeForMoreFeatures')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, '/premium'),
      ),
    );
  }

  Widget _buildTimerDisplay(TimelogProvider timer) {
    final elapsed = timer.currentElapsedMs;
    final hours = (elapsed ~/ 3600000).toString().padLeft(2, '0');
    final minutes = ((elapsed % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((elapsed % 60000) ~/ 1000).toString().padLeft(2, '0');
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 4),
      ),
      child: Center(
        child: Text(
          '$hours:$minutes:$seconds',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildTagAndNote(TimelogProvider timer) {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(labelText: AppLocalizations.t('tagPlaceholder')),
          onChanged: timer.setTag,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(labelText: AppLocalizations.t('note')),
          onChanged: timer.setNote,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildControls(TimelogProvider timer, ProjectProvider projects) {
    switch (timer.timerState) {
      case TimerState.idle:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: timer.currentProjectId == null ? null : timer.startTimer,
            icon: const Icon(Icons.play_arrow),
            label: Text(AppLocalizations.t('startTimer'), style: const TextStyle(fontSize: 18)),
          ),
        );
      case TimerState.running:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: timer.pauseTimer,
                icon: const Icon(Icons.pause),
                label: Text(AppLocalizations.t('pause')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final project = projects.getProjectById(timer.currentProjectId ?? '');
                  final log = await timer.stopAndSave(project?.hourlyRate ?? 0);
                  if (log != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.t('timeLogSaved'))),
                    );
                  }
                },
                icon: const Icon(Icons.stop),
                label: Text(AppLocalizations.t('stopAndSave')),
              ),
            ),
          ],
        );
      case TimerState.paused:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: timer.resumeTimer,
                icon: const Icon(Icons.play_arrow),
                label: Text(AppLocalizations.t('resume')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final project = projects.getProjectById(timer.currentProjectId ?? '');
                  final log = await timer.stopAndSave(project?.hourlyRate ?? 0);
                  if (log != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.t('timeLogSaved'))),
                    );
                  }
                },
                icon: const Icon(Icons.stop),
                label: Text(AppLocalizations.t('stopAndSave')),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              // 丢弃是破坏性且不可恢复的操作：必须二次确认
              onPressed: () => _confirmCancelTimer(timer),
              icon: const Icon(Icons.close, color: AppTheme.danger),
            ),
          ],
        );
    }
  }

  void _confirmCancelTimer(TimelogProvider timerProvider) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('cancelTimerTitle')),
        content: Text(AppLocalizations.t('cancelTimerBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.t('keepTracking')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.t('discard')),
          ),
        ],
      ),
    );
    if (discard == true) {
      await timerProvider.cancelTimer();
    }
  }
}
