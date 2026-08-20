import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_log.dart';
import '../models/tax_category.dart';
import '../providers/expense_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/project_provider.dart';
import '../services/hive_service.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/currency_format.dart';

class ExpenseFormScreen extends StatefulWidget {
  /// 非空时进入编辑模式，否则为新建
  final ExpenseLog? expense;
  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Software & Subscriptions';
  String? _selectedProjectId;
  bool _isTaxDeductible = true;
  DateTime _selectedDate = DateTime.now();
  String? _receiptUrl;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _amountController.text = e.amount.toStringAsFixed(2);
      _merchantController.text = e.merchant;
      _noteController.text = e.note;
      _selectedCategory = e.category;
      _selectedProjectId = e.projectId;
      _isTaxDeductible = e.isTaxDeductible;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(e.expenseDate);
      _receiptUrl = e.receiptUrl.isNotEmpty ? e.receiptUrl : null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = HiveService.taxCategoryBoxInstance.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final projectProvider = context.watch<ProjectProvider>();
    final projects = projectProvider.activeProjects;
    final isAnnual = context.watch<PremiumProvider>().isAnnual;

    // 崩溃防御：编辑记录的类目可能来自已被删除的自定义类目 —— 下拉框的
    // initialValue 必须能在 items 中找到，否则断言崩溃/静默丢值。
    final categoryNames = categories.map((c) => c.name).toSet();
    final categoryItems = <DropdownMenuItem<String>>[
      ...categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
      if (!categoryNames.contains(_selectedCategory))
        DropdownMenuItem(value: _selectedCategory, child: Text(_selectedCategory)),
    ];

    // 同理：编辑关联了已归档项目的开支时，activeProjects 不含该项目，
    // 注入当前值的 fallback 项保持链接可见且可保留。
    final projectItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text(AppLocalizations.t('none'))),
      ...projects.map((p) => DropdownMenuItem<String?>(value: p.projectId, child: Text(p.projectName))),
    ];
    if (_selectedProjectId != null &&
        !projects.any((p) => p.projectId == _selectedProjectId)) {
      final linked = projectProvider.getProjectById(_selectedProjectId!);
      projectItems.add(
        DropdownMenuItem<String?>(
          value: _selectedProjectId,
          child: Text(linked?.projectName ?? AppLocalizations.t('none')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? AppLocalizations.t('editExpense') : AppLocalizations.t('addExpenseTitle'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('amount'),
                prefixText: '${CurrencyFormat.symbol()} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // 只允许数字 + 最多两位小数
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty) return newValue;
                  final valid = RegExp(r'^\d*\.?\d{0,2}$');
                  return valid.hasMatch(text) ? newValue : oldValue;
                }),
              ],
              validator: (v) {
                final val = double.tryParse((v ?? '').trim());
                if (val == null || val <= 0) return AppLocalizations.t('errors.invalidAmount');
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(labelText: AppLocalizations.t('category')),
              items: [
                ...categoryItems,
                // 自定义类目入口（Annual 专属卖点）：选中即弹创建面板
                if (isAnnual)
                  DropdownMenuItem(
                    value: '__add_category__',
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.t('addCategory'),
                            style: const TextStyle(color: AppTheme.primary)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == '__add_category__') {
                  _showAddCategorySheet();
                  return;
                }
                setState(() {
                  _selectedCategory = v!;
                  final cat = categories.firstWhere((c) => c.name == v);
                  _isTaxDeductible = cat.isTaxDeductibleDefault;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              decoration: InputDecoration(labelText: AppLocalizations.t('merchantOptional')),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.t('date')),
              subtitle: Text(
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _selectedProjectId,
              decoration: InputDecoration(labelText: AppLocalizations.t('linkedProjectOptional')),
              items: projectItems,
              onChanged: (v) => setState(() => _selectedProjectId = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.t('taxDeductible')),
              subtitle: Text(AppLocalizations.t('markTaxDeductibleHint')),
              value: _isTaxDeductible,
              onChanged: (v) => setState(() => _isTaxDeductible = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: AppLocalizations.t('noteOptional')),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildReceiptField(),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saveExpense,
                child: Text(
                  _isEditing ? AppLocalizations.t('saveChanges') : AppLocalizations.t('saveExpense'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _showReceiptSource,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(_receiptUrl == null ? AppLocalizations.t('addReceipt') : AppLocalizations.t('changeReceipt')),
        ),
        if (_receiptUrl != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_receiptUrl!),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  void _showReceiptSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(AppLocalizations.t('takePhoto')),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.t('chooseFromGallery')),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            if (_receiptUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: Text(AppLocalizations.t('removeReceipt'), style: const TextStyle(color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _receiptUrl = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (image == null) return;
      // 复制到应用文档目录，避免 image_picker 的临时路径失效
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(image.path).copy(
        '${dir.path}${Platform.pathSeparator}$fileName',
      );
      if (mounted) setState(() => _receiptUrl = saved.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('errors.attachReceiptFailed'))),
        );
      }
    }
  }

  /// 新建自定义税务类目（Annual 专属）：本地 Hive 即时生效，选中并沿用其
  /// 默认抵扣设置。类目以名称关联记录（与默认类目一致），删除不影响历史记录。
  void _showAddCategorySheet() {
    final nameController = TextEditingController();
    bool deductibleByDefault = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppLocalizations.t('addCategory'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t('categoryName'),
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.t('defaultDeductible')),
                value: deductibleByDefault,
                onChanged: (v) => setSheetState(() => deductibleByDefault = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final exists = HiveService.taxCategoryBoxInstance.values
                      .any((c) => c.name.toLowerCase() == name.toLowerCase());
                  if (exists) {
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.t('categoryAlreadyExists'))),
                      );
                    }
                    return;
                  }
                  final category = TaxCategory(
                    categoryId: const Uuid().v4(),
                    name: name,
                    isDefault: false,
                    isTaxDeductibleDefault: deductibleByDefault,
                    sortOrder: 100 + HiveService.taxCategoryBoxInstance.length,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await HiveService.taxCategoryBoxInstance.put(category.categoryId, category);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (mounted) {
                    setState(() {
                      _selectedCategory = name;
                      _isTaxDeductible = deductibleByDefault;
                    });
                  }
                },
                child: Text(AppLocalizations.t('saveCategory')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    final provider = context.read<ExpenseProvider>();

    if (_isEditing) {
      final e = widget.expense!;
      e
        ..amount = amount
        ..category = _selectedCategory
        ..expenseDate = _selectedDate.millisecondsSinceEpoch
        ..projectId = _selectedProjectId
        ..merchant = _merchantController.text.trim()
        ..note = _noteController.text.trim()
        ..isTaxDeductible = _isTaxDeductible
        ..receiptUrl = _receiptUrl ?? '';
      await provider.updateExpense(e);
    } else {
      await provider.createExpense(
        amount: amount,
        category: _selectedCategory,
        expenseDate: _selectedDate.millisecondsSinceEpoch,
        projectId: _selectedProjectId,
        merchant: _merchantController.text.trim(),
        note: _noteController.text.trim(),
        isTaxDeductible: _isTaxDeductible,
        receiptUrl: _receiptUrl ?? '',
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
