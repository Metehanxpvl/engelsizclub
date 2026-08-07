import 'package:shared_preferences/shared_preferences.dart';

const _kWelcomeAcceptedKey = 'tibbi_hosgeldin_kabul_v1';

/// Bilgilendirme kartı kapatma anahtarları.
const kDismissHomeDisclaimer = 'info_dismiss_home_disclaimer_v1';
const kDismissPubmedInfo = 'info_dismiss_pubmed_v1';
const kDismissLibraryInfo = 'info_dismiss_library_v1';

Future<bool> isMedicalWelcomeAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kWelcomeAcceptedKey) == true;
}

Future<void> acceptMedicalWelcome() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kWelcomeAcceptedKey, true);
}

Future<bool> isInfoCardDismissed(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) == true;
}

Future<void> dismissInfoCard(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, true);
}
