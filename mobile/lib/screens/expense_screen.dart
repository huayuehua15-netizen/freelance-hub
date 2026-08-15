import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_log.dart';
import '../providers/expense_provider.dart';
import '../config/app_theme.dart';
import '../utils/currency_format.dart';
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
    final allExpenses = expenseProvider.expenses;
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
              title: Text('${_selectedIds.length} selected'),
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
              title: const Text('Expenses'),
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
                      'This Month ${CurrencyFormat.money(expenseProvider.totalThisMonth)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [
          // Filter chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Deductible Only'),
                  selected: _deductibleOnly,
                  onSelected: (v) => setState(() => _deductibleOnly = v),
                  selectedColor: AppTheme.success.withOpacity(0.15),
                  checkmarkColor: AppTheme.success,
                ),
                const SizedBox(width: 8),
                if (_selectedCategory != null)
                  Chip(
                    label: Text(_selectedCategory!, style: const TextStyle(fontSize: 12)),
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
                        title: 'No Expenses Yet',
                        subtitle: 'Track your business expenses and mark them as tax-deductible.',
                        buttonText: 'Add Expense',
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
              title: const Text('All Categories'),
              trailing: _selectedCategory == null ? const Icon(Icons.check, color: AppTheme.primary) : null,
              onTap: () {
                setState(() => _selectedCategory = null);
                Navigator.pop(context);
              },
            ),
            ...categories.map((c) => ListTile(
                  title: Text(c),
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

  // 按日期分组展示（expenses 已按 expenseDate 倒序）
  Widget _buildGroupedList(BuildContext context, List<ExpenseLog> expenses) {
    final rows = <Widget>[];
    String? lastDateKey;

    for (final expense in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense.expenseDate);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (key != lastDateKey) {
        lastDateKey = key;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }
      rows.add(_buildExpenseItem(context, expense));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: rows,
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
          title: Text(expense.category),
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
        await expenseProvider.deleteExpense(expense.expenseId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted')),
          );
        }
        return true;
      },
      onDismissed: (_) {},
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: expense.isTaxDeductible
                ? AppTheme.success.withOpacity(0.1)
                : AppTheme.border,
            child: Icon(
              _categoryIcon(expense.category),
              color: expense.isTaxDeductible ? AppTheme.success : AppTheme.textSecondary,
            ),
          ),
          title: Text(expense.category),
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
                const Text(
                  'Deductible',
                  style: TextStyle(fontSize: 11, color: AppTheme.success),
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
        title: Text('Delete ${_selectedIds.length} expense(s)?'),
        content: const Text('Expenses will be soft-deleted and hidden from lists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final id in _selectedIds.toList()) {
                provider.deleteExpense(id);
              }
              _exitSelectionMode();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
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
