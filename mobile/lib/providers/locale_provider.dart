import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/hive_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> loadLocale() async {
    final saved = HiveService.configBoxInstance.get('locale');
    if (saved is String && saved.isNotEmpty) {
      _locale = Locale(saved);
      AppLocalizations.current = _locale;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    AppLocalizations.current = locale;
    await HiveService.configBoxInstance.put('locale', locale.languageCode);
    notifyListeners();
  }
}
