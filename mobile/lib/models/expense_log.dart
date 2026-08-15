import 'package:hive/hive.dart';

part 'expense_log.g.dart';

@HiveType(typeId: 3)
class ExpenseLog extends HiveObject {
  @HiveField(0)
  String expenseId;

  @HiveField(1)
  String? projectId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String currency;

  @HiveField(4)
  int expenseDate; // 开支发生日期

  @HiveField(5)
  String category;

  @HiveField(6)
  bool isTaxDeductible;

  @HiveField(7)
  String merchant;

  @HiveField(8)
  String note;

  @HiveField(9)
  String receiptUrl;

  @HiveField(10)
  bool isDeleted;

  @HiveField(11)
  int syncStatus;

  @HiveField(12)
  int? serverUpdateTime;

  @HiveField(13)
  int createdAt;

  @HiveField(14)
  int updatedAt;

  ExpenseLog({
    required this.expenseId,
    this.projectId,
    required this.amount,
    this.currency = 'USD',
    required this.expenseDate,
    required this.category,
    this.isTaxDeductible = true,
    this.merchant = '',
    this.note = '',
    this.receiptUrl = '',
    this.isDeleted = false,
    this.syncStatus = 0,
    this.serverUpdateTime,
    required this.createdAt,
    required this.updatedAt,
  });
}
