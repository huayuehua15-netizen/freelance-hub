import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/premium_provider.dart';
import '../../l10n/app_localizations.dart';

class PremiumGuard extends StatelessWidget {
  final Widget child;
  final PremiumType requiredLevel; // free / monthly / annual
  final String? featureName;

  const PremiumGuard({
    super.key,
    required this.child,
    this.requiredLevel = PremiumType.monthly,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();

    bool hasAccess = false;
    switch (requiredLevel) {
      case PremiumType.free:
        hasAccess = true;
        break;
      case PremiumType.monthly:
        hasAccess = premium.isPremium;
        break;
      case PremiumType.annual:
        hasAccess = premium.isAnnual;
        break;
    }

    if (hasAccess) return child;

    return _LockedFeature(
      featureName: featureName,
      requiredLevel: requiredLevel,
    );
  }
}

class _LockedFeature extends StatelessWidget {
  final String? featureName;
  final PremiumType requiredLevel;

  const _LockedFeature({this.featureName, required this.requiredLevel});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              featureName ?? AppLocalizations.t('premiumFeature'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              requiredLevel == PremiumType.annual
                  ? AppLocalizations.t('requiresAnnualContractor')
                  : AppLocalizations.t('requiresFreelancerSubscription'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
              child: Text(AppLocalizations.t('upgrade')),
            ),
          ],
        ),
      ),
    );
  }
}
