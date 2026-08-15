import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../utils/data_export.dart';
import '../widgets/legal_doc_viewer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _currencies = ['USD', 'EUR', 'GBP', 'CNY', 'JPY', 'CAD', 'AUD'];
  static const _timezones = [
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Paris',
    'Asia/Shanghai',
    'Asia/Tokyo',
    'UTC',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final premium = context.watch<PremiumProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('settings'))),
      body: ListView(
        children: [
          // 账户信息（占位，登录功能后接）
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(auth.isLoggedIn ? (auth.user?.userName.isNotEmpty == true ? auth.user!.userName : 'User') : AppLocalizations.t('notSignedIn')),
            subtitle: Text(auth.user?.userEmail ?? AppLocalizations.t('signInToSyncHint')),
          ),
          const Divider(),
          // 偏好设置
          _SectionHeader(AppLocalizations.t('preferences')),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: Text(AppLocalizations.t('currency')),
            subtitle: Text(auth.user?.currency ?? 'USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(AppLocalizations.t('timezone')),
            subtitle: Text(auth.user?.timezone ?? 'America/New_York'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTimezonePicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppLocalizations.t('language')),
            subtitle: Text(AppLocalizations.isZh ? AppLocalizations.t('chinese') : AppLocalizations.t('english')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, localeProvider),
          ),
          const Divider(),
          // 数据管理
          _SectionHeader(AppLocalizations.t('dataManagement')),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(AppLocalizations.t('exportData')),
            subtitle: Text(AppLocalizations.t('exportDataHint')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(AppLocalizations.t('clearCache')),
            subtitle: Text(AppLocalizations.t('clearCacheHint')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmClearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(AppLocalizations.t('cloudSync')),
            subtitle: Text(premium.isAnnual && auth.isLoggedIn ? AppLocalizations.t('enabled') : AppLocalizations.t('requiresAnnualAccount')),
            trailing: const Icon(Icons.chevron_right),
            onTap: premium.isAnnual && auth.isLoggedIn
                ? () => _manualSync(context)
                : () => Navigator.pushNamed(context, '/premium'),
          ),
          const Divider(),
          // 订阅管理
          _SectionHeader(AppLocalizations.t('subscription')),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(AppLocalizations.t('subscription')),
            subtitle: Text(premium.isPremium
                ? (premium.isAnnual ? AppLocalizations.t('planContractorAnnual') : AppLocalizations.t('planFreelancerMonthly'))
                : AppLocalizations.t('freePlan')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/premium'),
          ),
          const Divider(),
          // 关于
          _SectionHeader(AppLocalizations.t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.t('version')),
            subtitle: Text('${AppConfig.appVersion} (${AppConfig.environment})'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(AppLocalizations.t('helpAndSupport')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.helpSupport),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(AppLocalizations.t('privacyPolicy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(AppLocalizations.t('termsOfService')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.termsOfService),
          ),
          const Divider(),
          // 账户操作
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: Text(AppLocalizations.t('logout'), style: const TextStyle(color: AppTheme.danger)),
              onTap: () async {
                await auth.logout();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppTheme.danger),
              title: Text(AppLocalizations.t('deleteAccount'), style: const TextStyle(color: AppTheme.danger)),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text('Freelance Hub v${AppConfig.appVersion}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textDisabled)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLegalDoc(BuildContext context, LegalDocType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalDocViewer(docType: type)),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    try {
      await auth.deleteAccount();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t1('errors.deleteAccountFailed', {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final json = DataExport.toJsonString();
      final filename = 'freelance_hub_export_${DateTime.now().millisecondsSinceEpoch}.json';
      // 修复 M1:此前用 Printing.sharePdf 分享 JSON,语义错配(PDF 通道分享文本)
      // 改用 share_plus 的 Share.share 分享 JSON 文本,subject 提供文件名建议
      await Share.share(json, subject: filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('dataExported'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t('exportFailed'))),
        );
      }
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    final sync = context.read<SyncService>();
    final userId = context.read<AuthProvider>().user?.userId;
    if (userId == null || userId == 'local_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t('signInToSyncAnnualHint'))),
      );
      return;
    }
    if (sync.syncing) return;
    await sync.syncAll(userId: userId);
    if (context.mounted) {
      final ok = sync.status == SyncStatus.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? AppLocalizations.t('syncCompleted') : AppLocalizations.t1('syncFailed', {'error': sync.lastError ?? AppLocalizations.t('errors.unknown')})),
        ),
      );
    }
  }

  void _showCurrencyPicker(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final current = auth.user?.currency ?? 'USD';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _currencies
              .map((c) => ListTile(
                    title: Text(c),
                    trailing: current == c ? const Icon(Icons.check, color: AppTheme.primary) : null,
                    onTap: () {
                      auth.updatePreferences(currency: c);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showTimezonePicker(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final current = auth.user?.timezone ?? 'America/New_York';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _timezones
              .map((tz) => ListTile(
                    title: Text(tz),
                    trailing: current == tz ? const Icon(Icons.check, color: AppTheme.primary) : null,
                    onTap: () {
                      auth.updatePreferences(timezone: tz);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LocaleProvider localeProvider) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.t('english')),
              trailing: localeProvider.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                localeProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.t('chinese')),
              trailing: localeProvider.locale.languageCode == 'zh'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                localeProvider.setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('clearCache')),
        content: Text(
          AppLocalizations.t('clearCacheConfirm'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('clear'), style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    int removed = 0;
    try {
      // 收集仍被引用（未删除且带收据）的文件路径
      final referenced = HiveService.expenseBoxInstance.values
          .where((e) => !e.isDeleted && e.receiptUrl.isNotEmpty)
          .map((e) => e.receiptUrl)
          .toSet();
      final dir = await getApplicationDocumentsDirectory();
      if (dir.existsSync()) {
        for (final f in dir.listSync()) {
          if (f is File && f.path.contains('receipt_') && !referenced.contains(f.path)) {
            await f.delete();
            removed++;
          }
        }
      }
    } catch (_) {
      // 清理失败不阻断，仅提示
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(removed > 0 ? AppLocalizations.t1('clearedNCachedFiles', {'n': '$removed'}) : AppLocalizations.t('noCacheToClear'))),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
      ),
    );
  }
}

/// GDPR confirmation dialog — requires typing "DELETE" to enable the confirm button.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final match = _controller.text.trim() == 'DELETE';
      if (match != _canConfirm) setState(() => _canConfirm = match);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.t('deleteAccount')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.t('deleteAccountSchedule'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.t('deleteAccountGracePeriod'),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.t('deleteAccountRestore'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.t('typeDeleteToConfirm')),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.t('cancel')),
        ),
        TextButton(
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          child: Text(AppLocalizations.t('deleteAccount')),
        ),
      ],
    );
  }
}
