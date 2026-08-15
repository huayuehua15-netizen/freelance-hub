import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/expense_log.dart';
import '../providers/expense_provider.dart';
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
    final projects = context.watch<ProjectProvider>().activeProjects;

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
              value: _selectedCategory,
              decoration: InputDecoration(labelText: AppLocalizations.t('category')),
              items: categories
                  .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (v) {
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
              value: _selectedProjectId,
              decoration: InputDecoration(labelText: AppLocalizations.t('linkedProjectOptional')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocalizations.t('none')),
                ),
                ...projects.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.projectId,
                    child: Text(p.projectName),
                  ),
                ),
              ],
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
