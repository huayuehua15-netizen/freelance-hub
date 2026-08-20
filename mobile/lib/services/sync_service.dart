import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import 'api_service.dart';
import 'hive_service.dart';

enum SyncStatus { idle, syncing, success, failed }

class SyncService extends ChangeNotifier {
  final ApiService _api = ApiService();
  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  final Uuid _uuid = const Uuid();

  /// 数据归属门禁：本地 Hive 库由单一所有者占用。换账号登录时，
  /// 旧账号的数据绝不允许上传到新账号的云端（数据泄露级问题）。
  /// - 首次同步时以当前登录用户认领（游客数据归首个登录账号）
  /// - 所有者与当前用户不一致 → 跳过推送，仅拉取
  static const String _ownerKey = 'data_owner_id';

  bool _ownershipMismatch = false;
  bool get ownershipMismatch => _ownershipMismatch;

  SyncStatus get status => _status;
  bool get syncing => _status == SyncStatus.syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 每台安装生成并持久化的设备 ID（用于多端识别/审计）。
  /// 不能用固定常量：同账号两台设备会互相干扰归属判断。
  String get _deviceId {
    final box = HiveService.configBoxInstance;
    var id = box.get('device_id') as String?;
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      box.put('device_id', id);
    }
    return id;
  }

  /// 账号注销/本地清库时清空归属，允许下一个账号认领。
  static Future<void> clearOwnership() async {
    await HiveService.configBoxInstance.delete(_ownerKey);
  }

  /// Full incremental sync for one authenticated account.
  ///
  /// The local database is shared by the app, so the cursor must be scoped to
  /// the account.  A global cursor could otherwise cause a second user on the
  /// same device to miss their first pull entirely.
  Future<void> syncAll({required String userId}) async {
    if (_status == SyncStatus.syncing) return;
    _status = SyncStatus.syncing;
    _lastError = null;
    _ownershipMismatch = false;
    notifyListeners();

    var pushFailed = false;
    try {
      // 0. 归属门禁：本地数据不属于当前账号时禁止推送（防跨账号泄露）
      final configBox = HiveService.configBoxInstance;
      final owner = configBox.get(_ownerKey) as String?;
      final canPush = owner == null || owner == userId;
      if (owner == null) {
        await configBox.put(_ownerKey, userId);
      } else if (!canPush) {
        _ownershipMismatch = true;
      }

      // 1. 推送本地 syncStatus=0 的记录（批量 upsert）。
      //    单类失败不阻断后续类别，更不阻断拉取 —— 否则一条被服务端
      //    持续拒绝的记录会让设备永远拉不到远端变更。
      if (canPush) {
        for (final push in [_pushProjects, _pushTimeLogs, _pushExpenses]) {
          try {
            await push();
          } catch (e) {
            _lastError = e.toString();
            pushFailed = true;
          }
        }
      }
      // 2. 拉取服务端 lastSyncTime 之后的更新
      final highestServerTime = await _pullAllChanges(userId);
      // 3. 更新同步时间（拉取成功即可推进游标，未推送的记录保持 syncStatus=0 待重试）
      await _updateLastSyncTime(userId, highestServerTime);
      _status = pushFailed || _ownershipMismatch ? SyncStatus.failed : SyncStatus.success;
      if (_ownershipMismatch) {
        _lastError = 'Local data belongs to a different account; push skipped.';
      }
    } catch (e) {
      _lastError = e.toString();
      _status = SyncStatus.failed;
      // 失败时保留本地数据，不删除
    } finally {
      notifyListeners();
    }
  }

  int _sinceMs(String userId) {
    final box = HiveService.configBoxInstance;
    final saved = box.get('last_sync_time_$userId');
    if (saved is int) return saved;
    return _lastSyncTime?.millisecondsSinceEpoch ?? 0;
  }

  // ---- 推送：本地 syncStatus=0 的记录批量 upsert 到后端 ----

  Future<void> _pushProjects() async {
    final dirty = HiveService.projectBoxInstance.values.where((p) => p.syncStatus == 0).toList();
    if (dirty.isEmpty) return;
    final response = await _api.post('/project/batch-upsert', data: {
      'projects': dirty.map(_projectToJson).toList(),
      'deviceId': _deviceId,
    });
    await _applyPushResults(dirty, response, (p) => p.projectId);
  }

  Future<void> _pushTimeLogs() async {
    final dirty = HiveService.timeLogBoxInstance.values.where((t) => t.syncStatus == 0).toList();
    if (dirty.isEmpty) return;
    final response = await _api.post('/timelog/batch-upsert', data: {
      'timeLogs': dirty.map(_timeLogToJson).toList(),
      'deviceId': _deviceId,
    });
    await _applyPushResults(dirty, response, (t) => t.timeLogId);
  }

  Future<void> _pushExpenses() async {
    final dirty = HiveService.expenseBoxInstance.values.where((e) => e.syncStatus == 0).toList();
    if (dirty.isEmpty) return;
    final response = await _api.post('/expense/batch-upsert', data: {
      'expenses': dirty.map(_expenseToJson).toList(),
      'deviceId': _deviceId,
    });
    await _applyPushResults(dirty, response, (e) => e.expenseId);
  }

  Future<void> _applyPushResults(
    List<dynamic> dirty,
    Map<String, dynamic> response,
    String Function(dynamic record) idOf,
  ) async {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
    final results = (data['results'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final byId = <String, Map<String, dynamic>>{};
    for (final result in results) {
      final id = result['projectId'] ?? result['timeLogId'] ?? result['expenseId'];
      if (id is String) byId[id] = result;
    }

    final failed = <String>[];
    for (final record in dirty) {
      final id = idOf(record);
      final result = byId[id];
      final status = result?['status'];
      if (status == 'created' || status == 'updated') {
        record.syncStatus = 1;
        await record.save();
      } else if (status == 'conflict') {
        record.syncStatus = 2;
        await record.save();
        failed.add(id);
      } else {
        // Missing/errored records remain pending.  Marking them successful
        // would silently discard the only copy of a local change.
        failed.add(id);
      }
    }
    if (failed.isNotEmpty) {
      // 不抛错：部分记录失败不应阻断其余类别推送和拉取。
      // 记录保持待同步状态，下次 syncAll 自动重试。
      debugPrint('Sync: ${failed.length} record(s) pending retry: ${failed.join(', ')}');
    }
  }

  // ---- 拉取：服务端 lastSyncTime 之后的更新，合并到本地（LWW） ----

  Future<int> _pullAllChanges(String userId) async {
    final since = _sinceMs(userId);
    var highestServerTime = since;
    highestServerTime = await _pullProjects(since, highestServerTime);
    highestServerTime = await _pullTimeLogs(since, highestServerTime);
    highestServerTime = await _pullExpenses(since, highestServerTime);
    return highestServerTime;
  }

  Future<int> _pullProjects(int since, int highestServerTime) async {
    final box = HiveService.projectBoxInstance;
    String? cursor;
    do {
      final res = await _api.get('/project/pull', query: {'since': since, if (cursor != null) 'cursor': cursor});
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final records = (data['data'] as List?) ?? const [];
      for (final r in records) {
        final map = Map<String, dynamic>.from(r as Map);
        final pid = map['projectId'] as String;
        final serverTs = _parseServerTime(map['serverUpdateTime']);
        highestServerTime = serverTs > highestServerTime ? serverTs : highestServerTime;
        final local = box.get(pid);
        if (local == null) {
          await box.put(pid, _projectFromServer(map));
        } else if (serverTs > local.updatedAt) {
          // 本地有未推送修改：server 版本即使更新也只标记冲突，绝不覆盖本地数据
          if (local.syncStatus == 0) {
            local.syncStatus = 2;
            await local.save();
          } else {
            await box.put(pid, _projectFromServer(map));
          }
        }
      }
      cursor = data['hasMore'] == true && data['nextCursor'] != null ? '${data['nextCursor']}' : null;
    } while (cursor != null);
    return highestServerTime;
  }

  Future<int> _pullTimeLogs(int since, int highestServerTime) async {
    final box = HiveService.timeLogBoxInstance;
    String? cursor;
    do {
      final res = await _api.get('/timelog/pull', query: {'since': since, if (cursor != null) 'cursor': cursor});
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final records = (data['data'] as List?) ?? const [];
      for (final r in records) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = map['timeLogId'] as String;
        final serverTs = _parseServerTime(map['serverUpdateTime']);
        highestServerTime = serverTs > highestServerTime ? serverTs : highestServerTime;
        final local = box.get(id);
        if (local == null) {
          await box.put(id, _timeLogFromServer(map));
        } else if (serverTs > local.updatedAt) {
          if (local.syncStatus == 0) {
            local.syncStatus = 2;
            await local.save();
          } else {
            await box.put(id, _timeLogFromServer(map));
          }
        }
      }
      cursor = data['hasMore'] == true && data['nextCursor'] != null ? '${data['nextCursor']}' : null;
    } while (cursor != null);
    return highestServerTime;
  }

  Future<int> _pullExpenses(int since, int highestServerTime) async {
    final box = HiveService.expenseBoxInstance;
    String? cursor;
    do {
      final res = await _api.get('/expense/pull', query: {'since': since, if (cursor != null) 'cursor': cursor});
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final records = (data['data'] as List?) ?? const [];
      for (final r in records) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = map['expenseId'] as String;
        final serverTs = _parseServerTime(map['serverUpdateTime']);
        highestServerTime = serverTs > highestServerTime ? serverTs : highestServerTime;
        final local = box.get(id);
        if (local == null) {
          await box.put(id, _expenseFromServer(map));
        } else if (serverTs > local.updatedAt) {
          if (local.syncStatus == 0) {
            local.syncStatus = 2;
            await local.save();
          } else {
            await box.put(id, _expenseFromServer(map));
          }
        }
      }
      cursor = data['hasMore'] == true && data['nextCursor'] != null ? '${data['nextCursor']}' : null;
    } while (cursor != null);
    return highestServerTime;
  }

  /// Keep the last observed server timestamp.  Pull uses an inclusive boundary,
  /// so retaining this value is safe even when a write races with sync.
  Future<void> _updateLastSyncTime(String userId, int timestamp) async {
    final box = HiveService.configBoxInstance;
    await box.put('last_sync_time_$userId', timestamp);
    _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // ---- 实体转 JSON / 反序列化 ----

  Map<String, dynamic> _projectToJson(ClientProject p) => {
        'projectId': p.projectId,
        'clientName': p.clientName,
        'clientEmail': p.clientEmail,
        'projectName': p.projectName,
        'hourlyRate': p.hourlyRate,
        'currency': p.currency,
        'status': p.status,
        'isDeleted': p.isDeleted,
        'clientUpdatedAt': p.updatedAt,
      };

  Map<String, dynamic> _timeLogToJson(TimeLog t) => {
        'timeLogId': t.timeLogId,
        'projectId': t.projectId,
        'startTime': t.startTime,
        'endTime': t.endTime,
        'duration': t.duration,
        'isBillable': t.isBillable,
        'billableAmount': t.billableAmount,
        'tag': t.tag,
        'note': t.note,
        'isDeleted': t.isDeleted,
        'clientUpdatedAt': t.updatedAt,
      };

  Map<String, dynamic> _expenseToJson(ExpenseLog e) => {
        'expenseId': e.expenseId,
        'projectId': e.projectId,
        'amount': e.amount,
        'currency': e.currency,
        'expenseDate': e.expenseDate,
        'category': e.category,
        'isTaxDeductible': e.isTaxDeductible,
        'merchant': e.merchant,
        'note': e.note,
        'receiptUrl': e.receiptUrl,
        'isDeleted': e.isDeleted,
        'clientUpdatedAt': e.updatedAt,
      };

  ClientProject _projectFromServer(Map<String, dynamic> map) {
    final ts = _parseServerTime(map['serverUpdateTime']);
    return ClientProject(
      projectId: map['projectId'] as String,
      clientName: (map['clientName'] as String?) ?? '',
      clientEmail: (map['clientEmail'] as String?) ?? '',
      projectName: (map['projectName'] as String?) ?? '',
      hourlyRate: ((map['hourlyRate'] as num?) ?? 0).toDouble(),
      currency: (map['currency'] as String?) ?? 'USD',
      status: (map['status'] as String?) ?? 'active',
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      syncStatus: 1,
      serverUpdateTime: ts,
      createdAt: _parseServerTime(map['serverCreateTime']),
      updatedAt: ts,
    );
  }

  TimeLog _timeLogFromServer(Map<String, dynamic> map) {
    final ts = _parseServerTime(map['serverUpdateTime']);
    return TimeLog(
      timeLogId: map['timeLogId'] as String,
      projectId: (map['projectId'] as String?) ?? '',
      startTime: ((map['startTime'] as num?) ?? 0).toInt(),
      endTime: (map['endTime'] as num?)?.toInt(),
      duration: ((map['duration'] as num?) ?? 0).toDouble(),
      isBillable: (map['isBillable'] as bool?) ?? true,
      billableAmount: ((map['billableAmount'] as num?) ?? 0).toDouble(),
      tag: (map['tag'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      syncStatus: 1,
      serverUpdateTime: ts,
      createdAt: _parseServerTime(map['serverCreateTime']),
      updatedAt: ts,
    );
  }

  ExpenseLog _expenseFromServer(Map<String, dynamic> map) {
    final ts = _parseServerTime(map['serverUpdateTime']);
    return ExpenseLog(
      expenseId: map['expenseId'] as String,
      projectId: map['projectId'] as String?,
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      currency: (map['currency'] as String?) ?? 'USD',
      expenseDate: ((map['expenseDate'] as num?) ?? 0).toInt(),
      category: (map['category'] as String?) ?? '',
      isTaxDeductible: (map['isTaxDeductible'] as bool?) ?? true,
      merchant: (map['merchant'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      receiptUrl: (map['receiptUrl'] as String?) ?? '',
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      syncStatus: 1,
      serverUpdateTime: ts,
      createdAt: _parseServerTime(map['serverCreateTime']),
      updatedAt: ts,
    );
  }

  /// 服务端 serverUpdateTime 可能是 ISO 字符串或毫秒时间戳，统一转 int。
  int _parseServerTime(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }
}
