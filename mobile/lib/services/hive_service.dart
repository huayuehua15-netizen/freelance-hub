import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_info.dart';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import '../models/tax_category.dart';

class HiveService {
  static const String userBox = 'user_info';
  static const String projectBox = 'client_project';
  static const String timeLogBox = 'time_log';
  static const String expenseBox = 'expense_log';
  static const String taxCategoryBox = 'tax_category';
  static const String configBox = 'app_config';

  static Future<void> init() async {
    await Hive.initFlutter();

    // 注册Adapter
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(ClientProjectAdapter());
    Hive.registerAdapter(TimeLogAdapter());
    Hive.registerAdapter(ExpenseLogAdapter());
    Hive.registerAdapter(TaxCategoryAdapter());

    // 打开Box
    await Future.wait([
      Hive.openBox<UserInfo>(userBox),
      Hive.openBox<ClientProject>(projectBox),
      Hive.openBox<TimeLog>(timeLogBox),
      Hive.openBox<ExpenseLog>(expenseBox),
      Hive.openBox<TaxCategory>(taxCategoryBox),
      Hive.openBox(configBox),
    ]);

    await _initDefaultTaxCategories();
  }

  static Future<void> _initDefaultTaxCategories() async {
    final box = Hive.box<TaxCategory>(taxCategoryBox);
    if (box.isEmpty) {
      final defaults = TaxCategory.getDefaultCategories();
      for (final cat in defaults) {
        await box.put(cat.categoryId, cat);
      }
    }
  }

  // 便捷获取Box
  static Box<UserInfo> get userBoxInstance => Hive.box<UserInfo>(userBox);
  static Box<ClientProject> get projectBoxInstance => Hive.box<ClientProject>(projectBox);
  static Box<TimeLog> get timeLogBoxInstance => Hive.box<TimeLog>(timeLogBox);
  static Box<ExpenseLog> get expenseBoxInstance => Hive.box<ExpenseLog>(expenseBox);
  static Box<TaxCategory> get taxCategoryBoxInstance => Hive.box<TaxCategory>(taxCategoryBox);
  static Box get configBoxInstance => Hive.box(configBox);
}
