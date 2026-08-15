import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/client_project.dart';
import '../providers/project_provider.dart';
import '../providers/timelog_provider.dart';
import '../providers/expense_provider.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProjectProvider, TimelogProvider, ExpenseProvider>(
      builder: (context, projectProvider, timelog, expense, _) {
        final project = projectProvider.getProjectById(projectId);

        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const Center(child: Text('Project not found')),
          );
        }

        final logs = timelog.timeLogs.where((t) => t.projectId == projectId).toList();
        final expenses = expense.expenses.where((e) => e.projectId == projectId).toList();
        final totalHours = logs.fold<double>(0, (s, t) => s + t.duration);
        final totalIncome = logs.fold<double>(0, (s, t) => s + t.billableAmount);
        final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);

        return Scaffold(
          appBar: AppBar(
            title: Text(project.projectName),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, value, project, projectProvider),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 项目信息
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.clientName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (project.clientEmail.isNotEmpty)
                        Text(project.clientEmail, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _infoChip('Rate', '${CurrencyFormat.symbol()}${project.hourlyRate.toStringAsFixed(2)}/hr'),
                          _infoChip('Status', project.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 三统计卡
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric('Hours', '${totalHours.toStringAsFixed(1)}h'),
                      _metric('Income', CurrencyFormat.money(totalIncome)),
                      _metric('Expenses', CurrencyFormat.money(totalExpenses)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 工时记录
              const Text('Time Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                const Card(child: ListTile(title: Text('No time logs yet'), subtitle: Text('Start a timer for this project')))
              else
                ...logs.map((t) {
                  final d = DateTime.fromMillisecondsSinceEpoch(t.startTime);
                  final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  return Card(
                    child: ListTile(
                      title: Text(dateStr),
                      subtitle: Text('${t.duration.toStringAsFixed(1)}h${t.tag.isNotEmpty ? ' · ${t.tag}' : ''}'),
                      trailing: Text(CurrencyFormat.money(t.billableAmount),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.pushNamed(context, '/time-log-edit', arguments: t),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              // 开支记录
              const Text('Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (expenses.isEmpty)
                const Card(child: ListTile(title: Text('No expenses yet')))
              else
                ...expenses.map((e) {
                  final d = DateTime.fromMillisecondsSinceEpoch(e.expenseDate);
                  final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  return Card(
                    child: ListTile(
                      title: Text(e.category),
                      subtitle: Text('$dateStr${e.merchant.isNotEmpty ? ' · ${e.merchant}' : ''}'),
                      trailing: Text(CurrencyFormat.money(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _handleMenuAction(BuildContext context, String value, ClientProject project, ProjectProvider provider) {
    switch (value) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ProjectEditSheet(project: project),
        );
        break;
      case 'archive':
        provider.archiveProject(project.projectId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project archived')));
        break;
      case 'delete':
        provider.deleteProject(project.projectId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted')));
        break;
    }
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _ProjectEditSheet extends StatefulWidget {
  final ClientProject project;
  const _ProjectEditSheet({required this.project});

  @override
  State<_ProjectEditSheet> createState() => _ProjectEditSheetState();
}

class _ProjectEditSheetState extends State<_ProjectEditSheet> {
  late final TextEditingController _clientNameController;
  late final TextEditingController _projectNameController;
  late final TextEditingController _rateController;
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clientNameController = TextEditingController(text: widget.project.clientName);
    _projectNameController = TextEditingController(text: widget.project.projectName);
    _rateController = TextEditingController(text: widget.project.hourlyRate.toStringAsFixed(2));
    _emailController = TextEditingController(text: widget.project.clientEmail);
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _projectNameController.dispose();
    _rateController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final rate = double.tryParse(_rateController.text.trim()) ?? 0;
    widget.project
      ..clientName = _clientNameController.text.trim()
      ..projectName = _projectNameController.text.trim()
      ..hourlyRate = rate
      ..clientEmail = _emailController.text.trim();
    await context.read<ProjectProvider>().updateProject(widget.project);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Project', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(labelText: 'Client Name'),
              maxLength: 100,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Client name is required';
                if (s.length > 100) return 'Maximum 100 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _projectNameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
              maxLength: 100,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Project name is required';
                if (s.length > 100) return 'Maximum 100 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateController,
              decoration: InputDecoration(labelText: 'Hourly Rate (${CurrencyFormat.symbol()})'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              validator: (v) {
                final val = double.tryParse(v?.trim() ?? '');
                if (val == null || val <= 0) return 'Enter a valid rate (> 0)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Client Email (optional)'),
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return null;
                if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
