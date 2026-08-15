import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_log.dart';
import '../models/tax_category.dart';
import '../services/hive_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<ExpenseLog> _expenses = [];
  bool _loading = false;

  List<ExpenseLog> get expenses => _expenses.where((e) => !e.isDeleted).toList();
  bool get loading => _loading;

  double get totalThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    return expenses
        .where((e) => e.expenseDate >= monthStart)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get taxDeductibleThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    return expenses
        .where((e) => e.expenseDate >= monthStart && e.isTaxDeductible)
        .fold(0, (sum, e) => sum + e.amount);
  }

  Future<void> loadExpenses() async {
    _loading = true;
    notifyListeners();
    try {
      final box = HiveService.expenseBoxInstance;
      _expenses = box.values.where((e) => !e.isDeleted).toList()
        ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ExpenseLog?> createExpense({
    required double amount,
    required String category,
    required int expenseDate,
    String? projectId,
    String merchant = '',
    String note = '',
    bool? isTaxDeductible,
    String currency = 'USD',
    String receiptUrl = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Category supplies the default only.  A user's explicit choice in the
    // form must win; otherwise an unchecked deductible switch is ignored.
    TaxCategory? taxCat;
    for (final c in HiveService.taxCategoryBoxInstance.values) {
      if (c.name == category) {
        taxCat = c;
        break;
      }
    }
    final effectiveDeductible = isTaxDeductible ?? taxCat?.isTaxDeductibleDefault ?? true;

    final expense = ExpenseLog(
      expenseId: const Uuid().v4(),
      projectId: projectId,
      amount: amount,
      currency: currency,
      expenseDate: expenseDate,
      category: category,
      isTaxDeductible: effectiveDeductible,
      merchant: merchant,
      note: note,
      receiptUrl: receiptUrl,
      syncStatus: 0,
      createdAt: now,
      updatedAt: now,
    );

    final box = HiveService.expenseBoxInstance;
    await box.put(expense.expenseId, expense);
    await loadExpenses();
    return expense;
  }

  Future<void> updateExpense(ExpenseLog expense) async {
    final box = HiveService.expenseBoxInstance;
    final stored = box.get(expense.expenseId);
    if (stored != null) {
      stored
        ..projectId = expense.projectId
        ..amount = expense.amount
        ..currency = expense.currency
        ..expenseDate = expense.expenseDate
        ..category = expense.category
        ..isTaxDeductible = expense.isTaxDeductible
        ..merchant = expense.merchant
        ..note = expense.note
        ..receiptUrl = expense.receiptUrl
        ..syncStatus = 0
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      await stored.save();
    }
    await loadExpenses();
  }

  Future<void> deleteExpense(String expenseId) async {
    final box = HiveService.expenseBoxInstance;
    final expense = box.get(expenseId);
    if (expense != null) {
      expense.isDeleted = true;
      expense.syncStatus = 0;
      expense.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await expense.save();
    }
    await loadExpenses();
  }

  List<ExpenseLog> getExpensesByDateRange(DateTime startDate, DateTime endDate) {
    final start = startDate.millisecondsSinceEpoch;
    final end = endDate.millisecondsSinceEpoch;
    return expenses
        .where((e) => e.expenseDate >= start && e.expenseDate <= end)
        .toList();
  }

  double getTaxDeductibleTotal() {
    return expenses
        .where((e) => e.isTaxDeductible)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get monthlyTotal {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    return expenses
        .where((e) => e.expenseDate >= monthStart)
        .fold(0, (sum, e) => sum + e.amount);
  }
}
