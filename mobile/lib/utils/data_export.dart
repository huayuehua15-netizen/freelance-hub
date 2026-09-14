import 'dart:convert';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import '../services/hive_service.dart';
import 'free_tier_gate.dart';

/// 数据导出：把本地项目/工时/开支序列化为 JSON，供设置页导出分享。
class DataExport {
  /// 收集全部未删除数据为 Map 结构。
  static Map<String, dynamic> collect({bool isFree = false}) {
    final projects = HiveService.projectBoxInstance.values
        .where((p) => !p.isDeleted)
        .map(_project)
        .toList();
    final timeLogs = FreeTierGate.visible(
      HiveService.timeLogBoxInstance.values.where((t) => !t.isDeleted).toList(),
      isFree,
      (t) => t.startTime,
    ).map(_timeLog).toList();
    final expenses = FreeTierGate.visible(
      HiveService.expenseBoxInstance.values.where((e) => !e.isDeleted).toList(),
      isFree,
      (e) => e.expenseDate,
    ).map(_expense).toList();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Freelance Hub',
      'projects': projects,
      'timeLogs': timeLogs,
      'expenses': expenses,
    };
  }

  /// 生成带缩进的可读 JSON 字符串。
  static String toJsonString({bool isFree = false}) =>
      const JsonEncoder.withIndent('  ').convert(collect(isFree: isFree));

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
        // 只导出文件名：完整路径会带出设备目录结构（隐私泄漏），
        // 且本机绝对路径在其它设备上无意义。
        // 进一步净化文件名：历史数据可能存了用户原始拍照名（极少），含
        // Windows 非法字符 / 控制字符 / 首尾空格/点时会导致后续导入或分享场景
        // （如通过邮件附件、网盘、zip 解压）失败。统一替换为下划线。
        'receiptFile': e.receiptUrl.isEmpty
            ? ''
            : _sanitizeReceiptFilename(
                e.receiptUrl.split(RegExp(r'[/\\]')).last,
              ),
        'createdAt': e.createdAt,
        'updatedAt': e.updatedAt,
      };

  /// 净化收据文件名：去掉控制字符、Windows 非法字符、首尾空格/点。
  /// 空结果返回空串，与上游 isEmpty 判断保持一致。
  static String _sanitizeReceiptFilename(String name) {
    final cleaned = name
        // 替换 Windows / 多数文件系统不允许的字符及控制字符为下划线
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        // 去掉首尾空格和点（Windows 不允许以点结尾的文件名）
        .replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
    return cleaned;
  }
}
