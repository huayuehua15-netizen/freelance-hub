import 'package:hive/hive.dart';

import '../l10n/app_localizations.dart';

part 'tax_category.g.dart';

@HiveType(typeId: 4)
class TaxCategory extends HiveObject {
  @HiveField(0)
  String categoryId;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isDefault;

  @HiveField(3)
  bool isTaxDeductibleDefault;

  @HiveField(4)
  int sortOrder;

  @HiveField(5)
  int createdAt;

  TaxCategory({
    required this.categoryId,
    required this.name,
    this.isDefault = true,
    this.isTaxDeductibleDefault = true,
    required this.sortOrder,
    required this.createdAt,
  });

  // 默认类目英文名 → l10n key。存储与按名称匹配逻辑一律用英文名（不变），
  // 仅显示层经 [displayNameOf] 本地化；自定义类目不在表内，显示原名。
  static const Map<String, String> _displayKeyByEnglishName = {
    'Software & Subscriptions': 'taxcat.softwareSubscriptions',
    'Office Supplies': 'taxcat.officeSupplies',
    'Internet & Phone': 'taxcat.internetPhone',
    'Hardware & Equipment': 'taxcat.hardwareEquipment',
    'Travel': 'taxcat.travel',
    'Education & Training': 'taxcat.educationTraining',
    'Marketing & Advertising': 'taxcat.marketingAdvertising',
    'Legal & Professional': 'taxcat.legalProfessional',
    'Insurance': 'taxcat.insurance',
    'Other Business Expense': 'taxcat.otherBusinessExpense',
  };

  /// 本实例的显示名（默认类目按当前语言，自定义类目显示用户输入原名）。
  String get displayName => displayNameOf(name);

  /// 任意类目名（存储名）的显示名。
  static String displayNameOf(String storedName) {
    final key = _displayKeyByEnglishName[storedName];
    return key == null ? storedName : AppLocalizations.t(key);
  }

  static List<TaxCategory> getDefaultCategories() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const categories = [
      'Software & Subscriptions',
      'Office Supplies',
      'Internet & Phone',
      'Hardware & Equipment',
      'Travel',
      'Education & Training',
      'Marketing & Advertising',
      'Legal & Professional',
      'Insurance',
      'Other Business Expense',
    ];
    return categories.asMap().entries.map((e) {
      return TaxCategory(
        categoryId: 'default_${e.key}',
        name: e.value,
        isDefault: true,
        isTaxDeductibleDefault: true,
        sortOrder: e.key,
        createdAt: now,
      );
    }).toList();
  }
}
