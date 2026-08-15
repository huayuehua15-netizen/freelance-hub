import 'package:hive/hive.dart';

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
