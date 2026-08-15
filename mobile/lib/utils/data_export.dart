import 'dart:convert';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import '../services/hive_service.dart';

/// 数据导出：把本地项目/工时/开支序列化为 JSON，供设置页导出分享。
class DataExport {
  /// 收集全部未删除数据为 Map 结构。
  static Map<String, dynamic> collect() {
    final projects = HiveService.projectBoxInstance.values
        .where((p) => !p.isDeleted)
        .map(_project)
        .toList();
    final timeLogs = HiveService.timeLogBoxInstance.values
        .where((t) => !t.isDeleted)
        .map(_timeLog)
        .toList();
    final expenses = HiveService.expenseBoxInstance.values
        .where((e) => !e.isDeleted)
        .map(_expense)
        .toList();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Freelance Hub',
      'projects': projects,
      'timeLogs': timeLogs,
      'expenses': expenses,
    };
  }

  /// 生成带缩进的可读 JSON 字符串。
  static String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(collect());

  static Map<String, dynamic> _project(ClientProject p) => {
        'projectId': p.projectId,
        'clientName': p.clientName,
        'clientEmail': p.clientEmail,
        'projectName': p.projectName,
        'hourlyRate': p.hourlyRate,
        'currency': p.currency,
        'status': p.status,
        'createdAt': p.createdAt,
        'updatedAt': p.updatedAt,
      };

  static Map<String, dynamic> _timeLog(TimeLog t) => {
        'timeLogId': t.timeLogId,
        'projectId': t.projectId,
        'startTime': t.startTime,
        'endTime': t.endTime,
        'duration': t.duration,
        'isBillable': t.isBillable,
        'billableAmount': t.billableAmount,
        'tag': t.tag,
        'note': t.note,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
      };

  static Map<String, dynamic> _expense(ExpenseLog e) => {
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
        'createdAt': e.createdAt,
        'updatedAt': e.updatedAt,
      };
}
