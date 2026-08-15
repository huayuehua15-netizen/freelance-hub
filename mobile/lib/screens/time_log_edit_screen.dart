import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/time_log.dart';
import '../providers/timelog_provider.dart';
import '../providers/project_provider.dart';
import '../config/app_theme.dart';
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
        DropdownMenuItem<String?>(value: _projectId, child: const Text('Unknown project')),
      ...projects.map((p) => DropdownMenuItem<String?>(
            value: p.projectId,
            child: Text(p.projectName),
          )),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Time Log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            value: _projectId,
            decoration: const InputDecoration(labelText: 'Project'),
            items: items,
            onChanged: (v) => setState(() => _projectId = v),
          ),
          const SizedBox(height: 16),
          _buildDateTimeTile('Start Time', _start, (d) => setState(() => _start = d)),
          _buildDateTimeTile('End Time', _end, (d) => setState(() => _end = d)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Duration'),
            subtitle: const Text('Auto-calculated from start & end'),
            trailing: Text('${_durationHours.toStringAsFixed(2)}h',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Billable Amount'),
            subtitle: const Text('Duration × hourly rate'),
            trailing: Text(CurrencyFormat.money(amount),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.success)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Billable'),
            value: _isBillable,
            onChanged: (v) => setState(() => _isBillable = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagController,
            decoration: const InputDecoration(labelText: 'Tag (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              helperText: 'Max 500 characters',
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
              child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            label: const Text('Delete Time Log', style: TextStyle(color: AppTheme.danger)),
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
      ..billableAmount = double.parse((_durationHours * rate).toStringAsFixed(2))
      ..tag = _tagController.text.trim()
      ..note = _noteController.text.trim();
    await provider.updateTimeLog(t);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Time Log'),
        content: const Text('This will remove this time log. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<TimelogProvider>().deleteTimeLog(widget.timeLog.timeLogId);
    if (mounted) Navigator.pop(context);
  }

  String _formatDateTime(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
