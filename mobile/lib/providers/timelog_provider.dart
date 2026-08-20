import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/time_log.dart';
import '../services/background_task_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

enum TimerState { idle, running, paused }

class TimelogProvider extends ChangeNotifier {
  static const Uuid _uuid = Uuid();
  static const String _timerStateKey = 'active_timer';

  TimerState _timerState = TimerState.idle;
  String? _currentProjectId;
  // Start of the complete work session. `_startTime` is only the active
  // segment and is cleared while paused.
  int? _sessionStartTime;
  int? _startTime;
  int _accumulatedDuration = 0; // 毫秒
  String _currentTag = '';
  String _currentNote = '';

  List<TimeLog> _timeLogs = [];

  TimerState get timerState => _timerState;
  String? get currentProjectId => _currentProjectId;
  int? get startTime => _startTime;
  String get currentTag => _currentTag;
  String get currentNote => _currentNote;
  List<TimeLog> get timeLogs => _timeLogs.where((t) => !t.isDeleted).toList();

  // 获取当前已运行时长（毫秒）
  int get currentElapsedMs {
    if (_timerState == TimerState.running && _startTime != null) {
      return _accumulatedDuration + (DateTime.now().millisecondsSinceEpoch - _startTime!);
    }
    return _accumulatedDuration;
  }

  void selectProject(String projectId) {
    if (_timerState == TimerState.idle) {
      _currentProjectId = projectId;
      notifyListeners();
    }
  }

  void setTag(String tag) {
    _currentTag = tag;
    notifyListeners();
  }

  void setNote(String note) {
    _currentNote = note;
    notifyListeners();
  }

  Future<void> startTimer() async {
    if (_timerState == TimerState.idle && _currentProjectId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _sessionStartTime = now;
      _startTime = now;
      _timerState = TimerState.running;
      await _persistTimerState();
      // 显示常驻通知；workmanager 前台服务保活仍为可选增强项
      await NotificationService.showTimerRunning(body: _currentNote);
      // 注册晚间提醒任务：系统在 19:00–22:30 窗口内调度，提醒用户停止并保存工时。
      // 失败不阻断计时启动——这只是辅助提醒，主流程已持久化到 Hive。
      try {
        await BackgroundTaskService.registerTimerReminder();
      } catch (e) {
        debugPrint('registerTimerReminder failed: $e');
      }
      notifyListeners();
    }
  }

  Future<void> pauseTimer() async {
    if (_timerState == TimerState.running && _startTime != null) {
      _accumulatedDuration += DateTime.now().millisecondsSinceEpoch - _startTime!;
      _startTime = null;
      _timerState = TimerState.paused;
      await _persistTimerState();
      await NotificationService.showTimerPaused();
      notifyListeners();
    }
  }

  Future<void> resumeTimer() async {
    if (_timerState == TimerState.paused) {
      _startTime = DateTime.now().millisecondsSinceEpoch;
      _timerState = TimerState.running;
      await _persistTimerState();
      await NotificationService.showTimerRunning(body: _currentNote);
      notifyListeners();
    }
  }

  Future<TimeLog?> stopAndSave(double hourlyRate) async {
    if (_timerState == TimerState.idle) return null;

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final totalMs = _accumulatedDuration +
        (_startTime != null ? endTime - _startTime! : 0);
    final durationHours = double.parse((totalMs / 3600000).toStringAsFixed(2));

    // Keep the real first-start timestamp.  Reconstructing from active
    // duration moves paused sessions to the wrong day and corrupts reports.
    final startTime = _sessionStartTime ?? endTime - totalMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final log = TimeLog(
      timeLogId: _uuid.v4(),
      projectId: _currentProjectId ?? '',
      startTime: startTime,
      endTime: endTime,
      duration: durationHours,
      billableAmount: double.parse((durationHours * hourlyRate).toStringAsFixed(2)),
      tag: _currentTag,
      note: _currentNote,
      createdAt: now,
      updatedAt: now,
    );
    await HiveService.timeLogBoxInstance.put(log.timeLogId, log);

    await _resetTimer();
    await _clearTimerState();
    await loadTimeLogs();
    return log;
  }

  Future<void> cancelTimer() async {
    await _resetTimer();
    await _clearTimerState();
    notifyListeners();
  }

  Future<void> _resetTimer() async {
    _timerState = TimerState.idle;
    _currentProjectId = null;
    _sessionStartTime = null;
    _startTime = null;
    _accumulatedDuration = 0;
    _currentTag = '';
    _currentNote = '';
    await NotificationService.cancelTimer();
    // 取消晚间提醒任务：计时已停止/取消，无需再提醒用户。
    // 失败不阻断主流程——任务在下次 startTimer 时会重新注册。
    try {
      await BackgroundTaskService.cancelTimerReminder();
    } catch (e) {
      debugPrint('cancelTimerReminder failed: $e');
    }
  }

  Future<void> loadTimeLogs() async {
    final box = HiveService.timeLogBoxInstance;
    _timeLogs = box.values.where((t) => !t.isDeleted).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();
  }

  Future<void> deleteTimeLog(String timeLogId) async {
    final box = HiveService.timeLogBoxInstance;
    final log = box.get(timeLogId);
    if (log != null) {
      log.isDeleted = true;
      log.syncStatus = 0;
      log.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await log.save();
    }
    await loadTimeLogs();
  }

  Future<void> updateTimeLog(TimeLog log) async {
    final box = HiveService.timeLogBoxInstance;
    final stored = box.get(log.timeLogId);
    if (stored != null) {
      stored
        ..projectId = log.projectId
        ..startTime = log.startTime
        ..endTime = log.endTime
        ..duration = log.duration
        ..isBillable = log.isBillable
        ..billableAmount = log.billableAmount
        ..tag = log.tag
        ..note = log.note
        ..syncStatus = 0
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await stored.save();
    }
    await loadTimeLogs();
  }

  // 异常恢复：App启动时检查是否有未结束的计时
  Future<void> recoverTimer() async {
    final box = HiveService.configBoxInstance;
    final saved = box.get(_timerStateKey);
    if (saved is Map) {
      _timerState = TimerState.values.firstWhere(
        (s) => s.name == saved['state'],
        orElse: () => TimerState.idle,
      );
      _currentProjectId = saved['projectId'] as String?;
      _startTime = (saved['startTime'] as num?)?.toInt();
      _sessionStartTime = (saved['sessionStartTime'] as num?)?.toInt() ?? _startTime;
      _accumulatedDuration = (saved['accumulatedDuration'] as num?)?.toInt() ?? 0;
      _currentTag = (saved['tag'] as String?) ?? '';
      _currentNote = (saved['note'] as String?) ?? '';
      if (_timerState == TimerState.idle || _currentProjectId == null) {
        _timerState = TimerState.idle;
        _sessionStartTime = null;
        _startTime = null;
      } else if (_timerState == TimerState.running && _startTime != null) {
        // 死区时间裁剪：App 被系统杀掉后再重开，_startTime 是杀进程前的绝对时间戳，
        // 若直接恢复会把"锁屏/被杀期间"的墙钟时间全部计入工时 → 向客户多计费。
        // 阈值 60 分钟：连续计时场景下用户短暂切后台不会触发；
        // 超过阈值大概率是被系统冻结后重开，此时保留杀进程前的累积时长，
        // 把 _startTime 置空并切换到 paused，强制用户手动 Resume 确认。
        final now = DateTime.now().millisecondsSinceEpoch;
        final deadZoneMs = now - _startTime!;
        if (deadZoneMs > _recoverDeadZoneThresholdMs) {
          _accumulatedDuration += 0; // accumulatedDuration 已是杀进程前真实累积，无需再加
          _startTime = null;
          _timerState = TimerState.paused;
          await NotificationService.showTimerPaused();
        } else {
          await NotificationService.showTimerRunning(body: _currentNote);
        }
      } else if (_timerState == TimerState.paused) {
        await NotificationService.showTimerPaused();
      }
      notifyListeners();
    }
  }

  // 恢复死区阈值：超过此间隔视为被系统杀进程而非真实连续工作，裁剪掉这段时间。
  // 60 分钟兼顾"午休切后台吃饭"等正常场景，又能拦住"隔夜被杀后重开"这种典型错误计费。
  static const int _recoverDeadZoneThresholdMs = 60 * 60 * 1000;

  Future<void> _persistTimerState() async {
    final box = HiveService.configBoxInstance;
    await box.put(_timerStateKey, {
      'state': _timerState.name,
      'projectId': _currentProjectId,
      'sessionStartTime': _sessionStartTime,
      'startTime': _startTime,
      'accumulatedDuration': _accumulatedDuration,
      'tag': _currentTag,
      'note': _currentNote,
    });
  }

  Future<void> _clearTimerState() async {
    final box = HiveService.configBoxInstance;
    await box.delete(_timerStateKey);
  }
}
