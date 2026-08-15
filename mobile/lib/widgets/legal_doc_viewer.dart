import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Lightweight in-app viewer for legal/help documents (demo-grade placeholders).
///
/// Shows Privacy Policy (§7.3 — 10 required sections), Terms of Service,
/// or Help & Support contact info without opening an external browser.
class LegalDocViewer extends StatelessWidget {
  final LegalDocType docType;

  const LegalDocViewer({super.key, required this.docType});

  static String titleFor(LegalDocType type) {
    switch (type) {
      case LegalDocType.privacyPolicy:
        return AppLocalizations.t('privacyPolicy');
      case LegalDocType.termsOfService:
        return AppLocalizations.t('termsOfService');
      case LegalDocType.helpSupport:
        return AppLocalizations.t('helpAndSupport');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titleFor(docType))),
      body: docType == LegalDocType.helpSupport
          ? _buildHelp(context)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: docType == LegalDocType.privacyPolicy
                  ? _privacySections()
                  : _termsSections(),
            ),
    );
  }

  // ── Help & Support ──────────────────────────────────────────
  Widget _buildHelp(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent, size: 64, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(AppLocalizations.t('helpNeedHand'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.t('helpResponseTime'),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          _contactRow(Icons.email_outlined, AppLocalizations.t('email'), 'support@freelancehub.app'),
          const SizedBox(height: 12),
          _contactRow(Icons.access_time, AppLocalizations.t('supportHoursLabel'), AppLocalizations.t('supportHoursValue')),
          const SizedBox(height: 32),
          Text(
            AppLocalizations.t('faq'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _faqItem(AppLocalizations.t('faq.exportData.q'), AppLocalizations.t('faq.exportData.a')),
          _faqItem(AppLocalizations.t('faq.cancelSubscription.q'), AppLocalizations.t('faq.cancelSubscription.a')),
          _faqItem(AppLocalizations.t('faq.dataBackup.q'), AppLocalizations.t('faq.dataBackup.a')),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _faqItem(String q, String a) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(q, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(a, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ),
      ],
    );
  }

  // ── Privacy Policy (§7.3 — 10 sections) ─────────────────────
  List<Widget> _privacySections() {
    return [
      _section(AppLocalizations.t('privacy.section1Title'), AppLocalizations.t('privacy.section1Body')),
      _section(AppLocalizations.t('privacy.section2Title'), AppLocalizations.t('privacy.section2Body')),
      _section(AppLocalizations.t('privacy.section3Title'), AppLocalizations.t('privacy.section3Body')),
      _section(AppLocalizations.t('privacy.section4Title'), AppLocalizations.t('privacy.section4Body')),
      _section(AppLocalizations.t('privacy.section5Title'), AppLocalizations.t('privacy.section5Body')),
      _section(AppLocalizations.t('privacy.section6Title'), AppLocalizations.t('privacy.section6Body')),
      _section(AppLocalizations.t('privacy.section7Title'), AppLocalizations.t('privacy.section7Body')),
      _section(AppLocalizations.t('privacy.section8Title'), AppLocalizations.t('privacy.section8Body')),
      _section(AppLocalizations.t('privacy.section9Title'), AppLocalizations.t('privacy.section9Body')),
      _section(AppLocalizations.t('privacy.section10Title'), AppLocalizations.t('privacy.section10Body')),
      const SizedBox(height: 16),
      Text(
        AppLocalizations.t('legalLastUpdated'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textDisabled),
      ),
    ];
  }

  // ── Terms of Service ────────────────────────────────────────
  List<Widget> _termsSections() {
    return [
      _section(AppLocalizations.t('terms.section1Title'), AppLocalizations.t('terms.section1Body')),
      _section(AppLocalizations.t('terms.section2Title'), AppLocalizations.t('terms.section2Body')),
      _section(AppLocalizations.t('terms.section3Title'), AppLocalizations.t('terms.section3Body')),
      _section(AppLocalizations.t('terms.section4Title'), AppLocalizations.t('terms.section4Body')),
      _section(AppLocalizations.t('terms.section5Title'), AppLocalizations.t('terms.section5Body')),
      _section(AppLocalizations.t('terms.section6Title'), AppLocalizations.t('terms.section6Body')),
      _section(AppLocalizations.t('terms.section7Title'), AppLocalizations.t('terms.section7Body')),
      _section(AppLocalizations.t('terms.section8Title'), AppLocalizations.t('terms.section8Body')),
      _section(AppLocalizations.t('terms.section9Title'), AppLocalizations.t('terms.section9Body')),
      _section(AppLocalizations.t('terms.section10Title'), AppLocalizations.t('terms.section10Body')),
      const SizedBox(height: 16),
      Text(
        AppLocalizations.t('legalLastUpdated'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textDisabled),
      ),
    ];
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

enum LegalDocType { privacyPolicy, termsOfService, helpSupport }