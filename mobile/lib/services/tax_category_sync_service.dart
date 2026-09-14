import 'package:flutter/foundation.dart';
import '../models/tax_category.dart';
import '../services/hive_service.dart';
import '../services/api_service.dart';

/// 自定义税务类目的云端同步（B5）。
///
/// 复用后端现有端点，零后端改动：
/// - POST /tax-category（Annual 专属）：创建云端类目，body 传 {name, isDeductible}
/// - GET  /tax-category/list：返回系统默认 + 本人自定义（含 isCustom/isDeductible/name/categoryId）
///
/// 设计取舍：
/// - 云端 → 本地：拉取合并，按 name（大小写不敏感）去重，本地已存在同名则
///   跳过云端项；只合并 isCustom 类目（系统默认本地 Hive 已有 default_0..9）。
/// - 本地 → 云端：创建类目时若已登录则非阻断推送；推送失败不回滚本地创建
///   （类目创建是即时可用的本地操作），下次进创建面板时会重试。
/// - 不新增 Hive 字段：云端类目直接映射为本地 TaxCategory 模型
///   （isDeductible → isTaxDeductibleDefault，isCustom → isDefault=false），
///   因此不需要改 Hive typeId/跑 build_runner。
class TaxCategorySyncService {
  TaxCategorySyncService._();

  /// 拉取云端自定义类目并合并进本地 Hive。返回新合并的条数。
  /// 任何失败（离线/未登录/403）静默返回 0 —— 类目同步是增强功能，
  /// 绝不阻断启动与主流程。
  static Future<int> pullAndMerge() async {
    try {
      final res = await ApiService().get('/tax-category/list');
      final data = Map<String, dynamic>.from(res['data'] as Map? ?? const {});
      final list = (data['categories'] as List? ?? const []);
      final box = HiveService.taxCategoryBoxInstance;

      // 本地已有类目名（大小写不敏感去重基准）
      final localNames =
          box.values.map((c) => c.name.toLowerCase()).toSet();

      var merged = 0;
      var index = 0;
      for (final raw in list) {
        index += 1;
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if (item['isDeleted'] == true) continue;
        if (item['isCustom'] != true) continue; // 系统默认本地已播种
        final name = (item['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        if (localNames.contains(name.toLowerCase())) continue;

        final createdAtMs = item['serverCreateTime'] is String
            ? DateTime.tryParse(item['serverCreateTime'] as String)
                    ?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;

        final category = TaxCategory(
          categoryId: (item['categoryId'] as String?) ?? name,
          name: name,
          isDefault: false,
          isTaxDeductibleDefault: item['isDeductible'] != false,
          sortOrder: 100 + index,
          createdAt: createdAtMs,
        );
        await box.put(category.categoryId, category);
        localNames.add(name.toLowerCase());
        merged += 1;
      }
      return merged;
    } catch (e) {
      debugPrint('TaxCategory pullAndMerge failed (non-blocking): $e');
      return 0;
    }
  }

  /// 把本地新建的自定义类目推送到云端。失败静默（不影响本地创建成功）。
  static Future<void> pushLocalCategory(TaxCategory category) async {
    try {
      await ApiService().post('/tax-category', data: {
        'name': category.name,
        'isDeductible': category.isTaxDeductibleDefault,
      });
    } catch (e) {
      debugPrint('TaxCategory push failed (non-blocking): $e');
    }
  }
}
