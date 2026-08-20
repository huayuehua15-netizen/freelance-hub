import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/project_provider.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/premium_guard.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _searching = false;
  String _query = '';
  String _filter = 'active'; // all / active / archived
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, _) {
        final premiumProvider = context.watch<PremiumProvider>();

        final all = projectProvider.projects; // 非删除（含 active + archived）
        final filtered = all.where((p) {
          final matchesFilter = _filter == 'all' || p.status == _filter;
          final q = _query.toLowerCase();
          final matchesQuery = q.isEmpty ||
              p.projectName.toLowerCase().contains(q) ||
              p.clientName.toLowerCase().contains(q);
          return matchesFilter && matchesQuery;
        }).toList();

        return Scaffold(
          appBar: _selectionMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  ),
                  title: Text(AppLocalizations.t1('nSelected', {'n': '${_selectedIds.length}'})),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      // 修复 M2:批量归档是 Annual 专属功能,Free/Monthly 不能用
                      onPressed: (_selectedIds.isEmpty || !premiumProvider.isAnnual)
                          ? null
                          : () => _batchArchive(projectProvider),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _batchDelete(context, projectProvider),
                    ),
                  ],
                )
              : AppBar(
                  title: _searching
                      ? TextField(
                          autofocus: true,
                          decoration: InputDecoration(hintText: AppLocalizations.t('searchProjectsHint'), border: InputBorder.none),
                          onChanged: (v) => setState(() => _query = v),
                        )
                      : Text(AppLocalizations.t('projects')),
                  actions: [
                    IconButton(
                      icon: Icon(_searching ? Icons.close : Icons.search),
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _query = '';
                      }),
                    ),
                    if (premiumProvider.isFree)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Text(
                            '${projectProvider.activeProjects.length}/3',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    _filterChip(AppLocalizations.t('filterActive'), 'active'),
                    const SizedBox(width: 8),
                    _filterChip(AppLocalizations.t('filterArchived'), 'archived'),
                    const SizedBox(width: 8),
                    _filterChip(AppLocalizations.t('filterAll'), 'all'),
                  ],
                ),
              ),
              Expanded(
                child: projectProvider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.folder_outlined,
                            title: _query.isEmpty ? AppLocalizations.t('noProjects') : AppLocalizations.t('noMatchingProjects'),
                            subtitle: _query.isEmpty
                                ? AppLocalizations.t('noProjectsHint')
                                : AppLocalizations.t('noMatchingProjectsHint'),
                            buttonText: AppLocalizations.t('createProject'),
                            onButtonPressed: () => _showCreateProjectSheet(context),
                          )
                    : RefreshIndicator(
                        onRefresh: () => projectProvider.loadProjects(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final project = filtered[index];
                            return Card(
                              child: ListTile(
                                leading: _selectionMode
                                    ? Checkbox(
                                        value: _selectedIds.contains(project.projectId),
                                        onChanged: (_) => _toggleSelect(project.projectId),
                                      )
                                    : null,
                                title: Text(
                                  project.projectName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(project.clientName),
                                trailing: _selectionMode
                                    ? null
                                    : Text(
                                        '${CurrencyFormat.symbol()}${project.hourlyRate.toStringAsFixed(2)}/hr',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                selected: _selectionMode && _selectedIds.contains(project.projectId),
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleSelect(project.projectId);
                                  } else {
                                    Navigator.pushNamed(context, '/project-detail', arguments: project.projectId);
                                  }
                                },
                                onLongPress: () {
                                  if (!_selectionMode) _enterSelectionMode(project.projectId);
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'projects-fab',
            onPressed: () {
              if (projectProvider.hasReachedFreeLimit) {
                _showPremiumGuard(context);
              } else {
                _showCreateProjectSheet(context);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  void _showCreateProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProjectSheet(),
    );
  }

  void _showPremiumGuard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PremiumGuard(
        requiredLevel: PremiumType.monthly,
        featureName: AppLocalizations.t('unlimitedProjectsFeature'),
        child: const SizedBox.shrink(),
      ),
    );
  }

  void _enterSelectionMode(String projectId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(projectId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String projectId) {
    setState(() {
      if (!_selectedIds.remove(projectId)) {
        _selectedIds.add(projectId);
      }
    });
  }

  void _batchArchive(ProjectProvider provider) {
    for (final id in _selectedIds.toList()) {
      provider.archiveProject(id);
    }
    _exitSelectionMode();
  }

  void _batchDelete(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t1('deleteNProjectsConfirm', {'n': '${_selectedIds.length}'})),
        content: Text(AppLocalizations.t('softDeleteProjectsHint')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final id in _selectedIds.toList()) {
                provider.deleteProject(id);
              }
              _exitSelectionMode();
            },
            child: Text(AppLocalizations.t('delete'), style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  const _CreateProjectSheet();

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _clientNameController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _rateController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

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
    final provider = context.read<ProjectProvider>();
    final project = await provider.createProject(
      clientName: _clientNameController.text.trim(),
      projectName: _projectNameController.text.trim(),
      hourlyRate: rate,
      clientEmail: _emailController.text.trim(),
      currency: CurrencyFormat.current,
    );
    if (!mounted) return;
    if (project == null) {
      // 免费版达到 3 个项目上限
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('freePlanLimitProjects')),
        ),
      );
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.t('projectCreated'))),
    );
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
            Text(AppLocalizations.t('newProject'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientNameController,
              decoration: InputDecoration(labelText: AppLocalizations.t('clientName')),
              maxLength: 100,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return AppLocalizations.t('errors.clientNameRequired');
                if (s.length > 100) return AppLocalizations.t1('errors.maxLength', {'n': '100'});
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _projectNameController,
              decoration: InputDecoration(labelText: AppLocalizations.t('projectName')),
              maxLength: 100,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return AppLocalizations.t('errors.projectNameRequired');
                if (s.length > 100) return AppLocalizations.t1('errors.maxLength', {'n': '100'});
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateController,
              decoration: InputDecoration(labelText: '${AppLocalizations.t('hourlyRate')} (${CurrencyFormat.symbol()})'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              validator: (v) {
                final val = double.tryParse(v?.trim() ?? '');
                if (val == null || val <= 0) return AppLocalizations.t('errors.invalidRate');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: AppLocalizations.t('clientEmailOptional')),
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return null; // optional
                if (!RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
                  return AppLocalizations.t('errors.invalidEmail');
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.t('createProject')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
