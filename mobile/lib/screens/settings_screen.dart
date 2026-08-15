import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // 账户信息（占位，登录功能后接）
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(auth.isLoggedIn ? (auth.user?.userName.isNotEmpty == true ? auth.user!.userName : 'User') : 'Not signed in'),
            subtitle: Text(auth.user?.userEmail ?? 'Sign in to sync your data'),
          ),
          const Divider(),
          // 偏好设置
          const _SectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text(auth.user?.currency ?? 'USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Timezone'),
            subtitle: Text(auth.user?.timezone ?? 'America/New_York'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTimezonePicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(AppLocalizations.isZh ? AppLocalizations.t('chinese') : AppLocalizations.t('english')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, localeProvider),
          ),
          const Divider(),
          // 数据管理
          const _SectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Download all your data (JSON)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Cache'),
            subtitle: const Text('Clear local cached data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmClearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Cloud Sync'),
            subtitle: Text(premium.isAnnual && auth.isLoggedIn ? 'Enabled' : 'Requires an Annual account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: premium.isAnnual && auth.isLoggedIn
                ? () => _manualSync(context)
                : () => Navigator.pushNamed(context, '/premium'),
          ),
          const Divider(),
          // 订阅管理
          const _SectionHeader('Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Subscription'),
            subtitle: Text(premium.isPremium
                ? (premium.isAnnual ? 'Contractor (Annual)' : 'Freelancer (Monthly)')
                : 'Free Plan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/premium'),
          ),
          const Divider(),
          // 关于
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text('${AppConfig.appVersion} (${AppConfig.environment})'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.helpSupport),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(context, LegalDocType.termsOfService),
          ),
          const Divider(),
          // 账户操作
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Sign Out', style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                await auth.logout();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppTheme.danger),
              title: const Text('Delete Account', style: TextStyle(color: AppTheme.danger)),
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
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final json = DataExport.toJsonString();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final filename = 'freelance_hub_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final ok = await Printing.sharePdf(bytes: bytes, filename: filename);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    final sync = context.read<SyncService>();
    final userId = context.read<AuthProvider>().user?.userId;
    if (userId == null || userId == 'local_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with an Annual account to sync.')),
      );
      return;
    }
    if (sync.syncing) return;
    await sync.syncAll(userId: userId);
    if (context.mounted) {
      final ok = sync.status == SyncStatus.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Sync completed' : 'Sync failed: ${sync.lastError ?? 'unknown error'}'),
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
              title: const Text('English'),
              trailing: localeProvider.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                localeProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('中文'),
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
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove unused receipt images. Your projects, time logs and expenses will NOT be deleted. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppTheme.danger)),
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
        SnackBar(content: Text(removed > 0 ? 'Cleared $removed cached file(s)' : 'No cache to clear')),
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
      title: const Text('Delete Account'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will schedule your account for permanent deletion.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All your data will be permanently removed after a 30-day grace period.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'To restore your account during the 30-day period, you must contact support@freelancehub.app. This action cannot be undone from the app.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('Type DELETE to confirm:'),
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }
}
