import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_project.dart';
import '../services/hive_service.dart';
import 'premium_provider.dart';

class ProjectProvider extends ChangeNotifier {
  static const Uuid _uuid = Uuid();
  final PremiumProvider premiumProvider;
  List<ClientProject> _projects = [];
  bool _loading = false;

  ProjectProvider(this.premiumProvider);

  List<ClientProject> get projects => _projects.where((p) => !p.isDeleted).toList();
  List<ClientProject> get activeProjects => projects.where((p) => p.status == 'active').toList();
  bool get loading => _loading;
  bool get hasReachedFreeLimit => !premiumProvider.isPremium && activeProjects.length >= 3;

  Future<void> loadProjects() async {
    _loading = true;
    notifyListeners();
    try {
      final box = HiveService.projectBoxInstance;
      _projects = box.values.where((p) => !p.isDeleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ClientProject?> createProject({
    required String clientName,
    required String projectName,
    required double hourlyRate,
    String clientEmail = '',
    String currency = 'USD',
  }) async {
    if (hasReachedFreeLimit) {
      // Free版达到3个项目上限
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = ClientProject(
      projectId: _uuid.v4(),
      clientName: clientName,
      projectName: projectName,
      hourlyRate: hourlyRate,
      clientEmail: clientEmail,
      currency: currency,
      createdAt: now,
      updatedAt: now,
    );
    final box = HiveService.projectBoxInstance;
    await box.put(project.projectId, project);
    await loadProjects();
    return project;
  }

  Future<void> updateProject(ClientProject project) async {
    final box = HiveService.projectBoxInstance;
    final stored = box.get(project.projectId);
    if (stored != null) {
      stored
        ..clientName = project.clientName
        ..clientEmail = project.clientEmail
        ..projectName = project.projectName
        ..hourlyRate = project.hourlyRate
        ..currency = project.currency
        ..status = project.status
        ..syncStatus = 0
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await stored.save();
    }
    await loadProjects();
  }

  Future<void> deleteProject(String projectId) async {
    final box = HiveService.projectBoxInstance;
    final project = box.get(projectId);
    if (project != null) {
      project.isDeleted = true;
      project.syncStatus = 0;
      project.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await project.save();
    }
    await loadProjects();
  }

  Future<void> archiveProject(String projectId) async {
    final box = HiveService.projectBoxInstance;
    final project = box.get(projectId);
    if (project != null) {
      project.status = 'archived';
      project.syncStatus = 0;
      project.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await project.save();
    }
    await loadProjects();
  }

  ClientProject? getProjectById(String projectId) {
    try {
      return _projects.firstWhere((p) => p.projectId == projectId);
    } catch (_) {
      return null;
    }
  }
}
