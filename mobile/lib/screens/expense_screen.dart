import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/expense_log.dart';
import '../models/tax_category.dart';
import '../providers/expense_provider.dart';
import '../providers/premium_provider.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';
import '../utils/free_tier_gate.dart';
import '../widgets/empty_state.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String? _selectedCategory; // null 表示全部
  bool _deductibleOnly = false; // deductible filter toggle
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    // Free 版仅当月（付费墙承诺）：列表同步受限并显示升级提示
    final isFree = context.watch<PremiumProvider>().isFree;
    final allExpenses = FreeTierGate.visible(expenseProvider.expenses, isFree, (e) => e.expenseDate);
    var expenses = allExpenses;
    if (_selectedCategory != null) {
      expenses = expenses.where((e) => e.category == _selectedCategory).toList();
    }
    if (_deductibleOnly) {
      expenses = expenses.where((e) => e.isTaxDeductible).toList();
    }
    final categories = allExpenses.map((e) => e.category).toSet().toList()..sort();

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text(AppLocalizations.t1('nSelected', {'n': '${_selectedIds.length}'})),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _batchDelete(context, expenseProvider),
                ),
              ],
            )
          : AppBar(
              title: Text(AppLocalizations.t('expenses')),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedCategory == null && !_deductibleOnly ? Icons.filter_list : Icons.filter_list_off,
                    color: _selectedCategory == null && !_deductibleOnly ? null : AppTheme.primary,
                  ),
                  onPressed: () => _showFilter(context, categories),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      '${AppLocalizations.t('thisMonth')} ${CurrencyFormat.money(expenseProvider.totalThisMonth)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [
          // Free 版历史锁定提示：说明为何看不到更早的记录
          if (isFree)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/premium'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.t('freeHistoryLocked'),
                          style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          // Filter chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(AppLocalizations.t('deductibleOnly')),
                  selected: _deductibleOnly,
                  onSelected: (v) => setState(() => _deductibleOnly = v),
                  selectedColor: AppTheme.success.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.success,
                ),
                const SizedBox(width: 8),
                if (_selectedCategory != null)
                  Chip(
                    label: Text(TaxCategory.displayNameOf(_selectedCategory!), style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _selectedCategory = null),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
          Expanded(
            child: expenseProvider.loading
                ? const Center(child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: AppLocalizations.t('noExpenses'),
                        subtitle: AppLocalizations.t('noExpensesHint'),
                        buttonText: AppLocalizations.t('addExpenseTitle'),
                        onButtonPressed: () => Navigator.pushNamed(context, '/expense-form'),
                      )
                    : RefreshIndicator(
                        onRefresh: () => expenseProvider.loadExpenses(),
                        child: _buildGroupedList(context, expenses),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'expenses-fab',
        onPressed: () => Navigator.pushNamed(context, '/expense-form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilter(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.t('allCategories')),
              trailing: _selectedCategory == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
              onTap: () {
                setState(() => _selectedCategory = null);
                Navigator.pop(context);
              },
            ),
            ...categories.map((c) => ListTile(
                  title: Text(TaxCategory.displayNameOf(c)),
                  trailing: _selectedCategory == c ? const Icon(Icons.check, color: AppTheme.primary) : null,
                  onTap: () {
                    setState(() => _selectedCategory = c);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  // 按日期分组展示（expenses 已按 expenseDate 倒序）。
  // 预先展开为 header/item 扁平序列，用 ListView.builder 惰性构建：
  // 此前的非 builder ListView 一次性实例化全部行，长列表（Annual 用户
  // 全量历史）会拖慢首帧并放大内存占用。
  Widget _buildGroupedList(BuildContext context, List<ExpenseLog> expenses) {
    final entries = <_GroupedRow>[];
    String? lastDateKey;

    for (final expense in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense.expenseDate);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (key != lastDateKey) {
        lastDateKey = key;
        entries.add(_GroupedRow.header(key));
      }
      entries.add(_GroupedRow.item(expense));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final row = entries[index];
        if (row.isHeader) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              row.headerKey!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          );
        }
        return _buildExpenseItem(context, row.expense!);
      },
    );
  }

  Widget _buildExpenseItem(BuildContext context, ExpenseLog expense) {
    final expenseProvider = context.read<ExpenseProvider>();

    if (_selectionMode) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: _selectedIds.contains(expense.expenseId),
            onChanged: (_) => _toggleSelect(expense.expenseId),
          ),
          title: Text(TaxCategory.displayNameOf(expense.category)),
          subtitle: expense.merchant.isNotEmpty ? Text(expense.merchant) : null,
          trailing: Text(
            CurrencyFormat.money(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          selected: _selectedIds.contains(expense.expenseId),
          onTap: () => _toggleSelect(expense.expenseId),
        ),
      );
    }

    return Dismissible(
      key: ValueKey(expense.expenseId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // 删除不可逆（软删后界面无恢复入口）：先二次确认，避免误滑丢数据
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(AppLocalizations.t('deleteExpense')),
                content: Text(AppLocalizations.t('deleteExpenseConfirm')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t('cancel'))),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppLocalizations.t('delete'), style: const TextStyle(color: AppTheme.danger)),
                  ),
                ],
              ),
            ) ??
            false;
        return confirmed;
      },
      onDismissed: (_) async {
        await expenseProvider.deleteExpense(expense.expenseId);
        if (!context.mounted) return;
        // 撤销入口：删除是软删，撤销即复位标记，误操作不再等同永久丢失
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('expenseDeleted')),
            action: SnackBarAction(
              label: AppLocalizations.t('undo'),
              onPressed: () => expenseProvider.restoreExpense(expense.expenseId),
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: expense.isTaxDeductible
                ? AppTheme.success.withValues(alpha: 0.1)
                : AppTheme.border,
            child: Icon(
              _categoryIcon(expense.category),
              color: expense.isTaxDeductible ? AppTheme.success : AppTheme.textSecondary,
            ),
          ),
          title: Text(TaxCategory.displayNameOf(expense.category)),
          subtitle: expense.merchant.isNotEmpty ? Text(expense.merchant) : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormat.money(expense.amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (expense.isTaxDeductible)
                Text(
                  AppLocalizations.t('deductible'),
                  style: const TextStyle(fontSize: 11, color: AppTheme.success),
                ),
            ],
          ),
          onTap: () => Navigator.pushNamed(context, '/expense-form', arguments: expense),
          onLongPress: () => _enterSelectionMode(expense.expenseId),
        ),
      ),
    );
  }

  void _enterSelectionMode(String expenseId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(expenseId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String expenseId) {
    setState(() {
      if (!_selectedIds.remove(expenseId)) {
        _selectedIds.add(expenseId);
      }
    });
  }

  void _batchDelete(BuildContext context, ExpenseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t1('deleteNExpensesConfirm', {'n': '${_selectedIds.length}'})),
        content: Text(AppLocalizations.t('softDeleteExpensesHint')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t('cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // await 化：部分失败时给用户反馈，而不是静默吞掉
              try {
                await Future.wait(_selectedIds.map((id) => provider.deleteExpense(id)));
              } catch (e, st) {
                // 记录根因（JSON 解析、磁盘、Hive box 锁、网络等）以便线上排查；
                // 仅 debugPrint 不上报 Sentry：批量删除失败属于用户预期内的操作风险。
                debugPrint('Batch delete expenses failed: $e\n$st');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.t('errors.unknown'))),
                  );
                }
              }
              _exitSelectionMode();
            },
            child: Text(AppLocalizations.t('delete'), style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Software & Subscriptions':
        return Icons.subscriptions;
      case 'Office Supplies':
        return Icons.inventory_2_outlined;
      case 'Internet & Phone':
        return Icons.wifi;
      case 'Hardware & Equipment':
        return Icons.devices;
      case 'Travel':
        return Icons.flight_takeoff;
      case 'Education & Training':
        return Icons.school;
      case 'Marketing & Advertising':
        return Icons.campaign;
      case 'Legal & Professional':
        return Icons.gavel;
      case 'Insurance':
        return Icons.shield_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

/// 分组列表的扁平行模型：日期分组头或开支条目。
class _GroupedRow {
  final bool isHeader;
  final String? headerKey;
  final ExpenseLog? expense;

  const _GroupedRow._(this.isHeader, this.headerKey, this.expense);

  factory _GroupedRow.header(String key) => _GroupedRow._(true, key, null);

  factory _GroupedRow.item(ExpenseLog e) => _GroupedRow._(false, null, e);
}
