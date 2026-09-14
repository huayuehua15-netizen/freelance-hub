import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_project.dart';
import '../services/hive_service.dart';
import 'premium_provider.dart';
import '../utils/currency_format.dart';

class ProjectProvider extends ChangeNotifier {
  static const Uuid _uuid = Uuid();
  final PremiumProvider premiumProvider;
  List<ClientProject> _projects = [];
  List<ClientProject> _activeProjectsCache = const [];
  bool _loading = false;

  ProjectProvider(this.premiumProvider);

  // _projects 在 loadProjects 时已完成 !isDeleted 过滤与排序（所有增删改
  // 后都会调用），getter 直接返回缓存列表，消除每帧 O(n) 冗余拷贝。只读。
  List<ClientProject> get projects => _projects;
  List<ClientProject> get activeProjects => _activeProjectsCache;
  bool get loading => _loading;
  bool get hasReachedFreeLimit => !premiumProvider.isPremium && activeProjects.length >= 3;

  Future<void> loadProjects() async {
    _loading = true;
    notifyListeners();
    try {
      final box = HiveService.projectBoxInstance;
      _projects = box.values.where((p) => !p.isDeleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      // activeProjects 缓存：随 loadProjects 一并刷新，getter O(1)
      _activeProjectsCache =
          _projects.where((p) => p.status == 'active').toList();
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
    String? currency,
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
      currency: currency ?? CurrencyFormat.current,
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

  /// 归档恢复：归档确认弹窗承诺「可随时恢复」，此为兑现该承诺的实现。
  Future<void> restoreProject(String projectId) async {
    final box = HiveService.projectBoxInstance;
    final project = box.get(projectId);
    if (project != null && project.status == 'archived') {
      project.status = 'active';
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
