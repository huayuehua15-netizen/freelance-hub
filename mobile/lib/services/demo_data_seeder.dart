import 'package:uuid/uuid.dart';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import 'hive_service.dart';

/// 预置 Demo 数据（文档 §10）：3 个项目 + 12 条工时 + 4 笔可抵扣开支。
///
/// 首次启动且项目库为空时写入，保证 Demo 验收项 #1「预置数据完整」。
/// 数据完全对齐 §10.2/10.3/10.4：总工时 41.5h、总收入 $2110.00、总开支 $219.97。
class DemoDataSeeder {
  static const Uuid _uuid = Uuid();

  static Future<void> seedIfEmpty() async {
    // 已有数据则跳过，避免覆盖用户真实录入
    if (HiveService.projectBoxInstance.isNotEmpty) return;

    final p1 = _project('Acme Corp', 'billing@acmecorp.com', 'Website Redesign', 45);
    final p2 = _project('StartupXYZ', 'ops@startupxyz.io', 'Mobile UI Kit Design', 50);
    final p3 = _project('Digital Agency Co.', 'pm@digitalagency.co', 'Design Consulting', 60);

    for (final p in [p1, p2, p3]) {
      await HiveService.projectBoxInstance.put(p.projectId, p);
    }

    // Website Redesign（$45/hr）
    await _timeLog(p1, 1, 3.5, 'design', 'Homepage mockup iteration', 45);
    await _timeLog(p1, 3, 4.0, 'dev', 'React component implementation', 45);
    await _timeLog(p1, 5, 2.5, 'meeting', 'Client review call', 45);
    await _timeLog(p1, 7, 5.0, 'design', 'Mobile responsive layouts', 45);
    // Mobile UI Kit Design（$50/hr）
    await _timeLog(p2, 2, 6.0, 'design', 'Component library setup', 50);
    await _timeLog(p2, 4, 3.0, 'design', 'Icon set creation', 50);
    await _timeLog(p2, 6, 4.5, 'dev', 'Figma to Flutter export', 50);
    await _timeLog(p2, 8, 2.0, 'meeting', 'Stakeholder presentation', 50);
    // Design Consulting（$60/hr）
    await _timeLog(p3, 2, 2.0, 'meeting', 'Brand strategy session', 60);
    await _timeLog(p3, 6, 3.5, 'design', 'Design system audit', 60);
    await _timeLog(p3, 9, 1.5, 'other', 'Email correspondence', 60);
    await _timeLog(p3, 11, 4.0, 'design', 'Design guideline document', 60);

    // 可抵扣开支（本月 1/5/10/15 日，均 Tax-Deductible）
    final now = DateTime.now();
    await _expense(DateTime(now.year, now.month, 1), 54.99, 'Software & Subscriptions', 'Adobe Inc.');
    await _expense(DateTime(now.year, now.month, 5), 29.99, 'Software & Subscriptions', 'Vercel Inc.');
    await _expense(DateTime(now.year, now.month, 10), 89.99, 'Hardware & Equipment', 'Amazon Business');
    await _expense(DateTime(now.year, now.month, 15), 45.00, 'Internet & Phone', 'Comcast');
  }

  static ClientProject _project(String client, String email, String name, double rate) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = ClientProject(
      projectId: _uuid.v4(),
      clientName: client,
      clientEmail: email,
      projectName: name,
      hourlyRate: rate,
      createdAt: now,
      updatedAt: now,
    );
    // Keep seed data pending until an Annual user explicitly syncs.  Marking
    // it as already synced made the headline phone-to-Web demo contain no
    // data on a fresh installation.
    p.syncStatus = 0;
    return p;
  }

  static Future<void> _timeLog(
    ClientProject project,
    int daysAgo,
    double hours,
    String tag,
    String note,
    double rate,
  ) async {
    final now = DateTime.now();
    // 结束时间 = 今天 00:00 往前 daysAgo 天的 17:00，保证在过去且自洽
    final end = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysAgo))
        .add(const Duration(hours: 17));
    final endMs = end.millisecondsSinceEpoch;
    final startMs = endMs - (hours * 3600000).round();
    final amount = double.parse((hours * rate).toStringAsFixed(2));

    final t = TimeLog(
      timeLogId: _uuid.v4(),
      projectId: project.projectId,
      startTime: startMs,
      endTime: endMs,
      duration: hours,
      billableAmount: amount,
      tag: tag,
      note: note,
      createdAt: endMs,
      updatedAt: endMs,
    );
    t.syncStatus = 0;
    await HiveService.timeLogBoxInstance.put(t.timeLogId, t);
  }

  static Future<void> _expense(
    DateTime date,
    double amount,
    String category,
    String merchant,
  ) async {
    final e = ExpenseLog(
      expenseId: _uuid.v4(),
      amount: amount,
      currency: 'USD',
      expenseDate: date.millisecondsSinceEpoch,
      category: category,
      isTaxDeductible: true,
      merchant: merchant,
      createdAt: date.millisecondsSinceEpoch,
      updatedAt: date.millisecondsSinceEpoch,
    );
    e.syncStatus = 0;
    await HiveService.expenseBoxInstance.put(e.expenseId, e);
  }
}
