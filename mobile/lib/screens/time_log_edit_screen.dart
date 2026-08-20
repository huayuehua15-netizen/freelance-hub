import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/time_log.dart';
import '../providers/timelog_provider.dart';
import '../providers/project_provider.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/currency_format.dart';

class TimeLogEditScreen extends StatefulWidget {
  final TimeLog timeLog;
  const TimeLogEditScreen({super.key, required this.timeLog});

  @override
  State<TimeLogEditScreen> createState() => _TimeLogEditScreenState();
}

class _TimeLogEditScreenState extends State<TimeLogEditScreen> {
  late String? _projectId;
  late DateTime _start;
  late DateTime _end;
  late bool _isBillable;
  late final TextEditingController _tagController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final t = widget.timeLog;
    _projectId = t.projectId.isEmpty ? null : t.projectId;
    _start = DateTime.fromMillisecondsSinceEpoch(t.startTime);
    _end = DateTime.fromMillisecondsSinceEpoch(t.endTime ?? t.startTime);
    _isBillable = t.isBillable;
    _tagController = TextEditingController(text: t.tag);
    _noteController = TextEditingController(text: t.note);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 时长（小时，2位小数），由开始/结束时间自动计算
  double get _durationHours {
    final ms = _end.difference(_start).inMilliseconds;
    if (ms <= 0) return 0;
    return double.parse((ms / 3600000).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final projects = projectProvider.projects;
    final rate = projectProvider.getProjectById(_projectId ?? '')?.hourlyRate ?? 0;
    final amount = double.parse((_durationHours * rate).toStringAsFixed(2));

    // 保证当前项目始终在可选项里（含已归档、甚至未知项目）
    final items = <DropdownMenuItem<String?>>[
      if (_projectId != null && !projects.any((p) => p.projectId == _projectId))
        DropdownMenuItem<String?>(value: _projectId, child: Text(AppLocalizations.t('unknownProject'))),
      ...projects.map((p) => DropdownMenuItem<String?>(
            value: p.projectId,
            child: Text(p.projectName),
          )),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('editTimeLog'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _projectId,
            decoration: InputDecoration(labelText: AppLocalizations.t('project')),
            items: items,
            onChanged: (v) => setState(() => _projectId = v),
          ),
          const SizedBox(height: 16),
          _buildDateTimeTile(AppLocalizations.t('startTime'), _start, (d) => setState(() => _start = d)),
          _buildDateTimeTile(AppLocalizations.t('endTime'), _end, (d) => setState(() => _end = d)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.t('duration')),
            subtitle: Text(AppLocalizations.t('durationAutoCalculated')),
            trailing: Text('${_durationHours.toStringAsFixed(2)}h',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.t('billableAmount')),
            subtitle: Text(AppLocalizations.t('billableAmountHint')),
            trailing: Text(CurrencyFormat.money(amount),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.success)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.t('billable')),
            value: _isBillable,
            onChanged: (v) => setState(() => _isBillable = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagController,
            decoration: InputDecoration(labelText: AppLocalizations.t('tagOptional')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: AppLocalizations.t('noteOptional'),
              helperText: AppLocalizations.t1('maxChars', {'n': '500'}),
              counterText: '',
            ),
            maxLength: 500,
            maxLines: 2,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(AppLocalizations.t('saveChanges'), style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            label: Text(AppLocalizations.t('deleteTimeLog'), style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeTile(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_formatDateTime(value)),
      trailing: const Icon(Icons.schedule),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (d == null || !mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
    );
  }

  Future<void> _save() async {
    final provider = context.read<TimelogProvider>();
    final rate = context.read<ProjectProvider>().getProjectById(_projectId ?? '')?.hourlyRate ?? 0;
    final t = widget.timeLog;
    t
      ..projectId = _projectId ?? ''
      ..startTime = _start.millisecondsSinceEpoch
      ..endTime = _end.millisecondsSinceEpoch
      ..duration = _durationHours
      ..isBillable = _isBillable
      // 非计费工时不产生收入：金额必须清零，否则收入/净收入/自雇税估算全部虚高
      ..billableAmount = _isBillable ? double.parse((_durationHours * rate).toStringAsFixed(2)) : 0.0
      ..tag = _tagController.text.trim()
      ..note = _noteController.text.trim();
    await provider.updateTimeLog(t);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('saved'))),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('deleteTimeLog')),
        content: Text(AppLocalizations.t('deleteTimeLogConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('delete'), style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<TimelogProvider>().deleteTimeLog(widget.timeLog.timeLogId);
    if (mounted) Navigator.pop(context);
  }

  String _formatDateTime(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
