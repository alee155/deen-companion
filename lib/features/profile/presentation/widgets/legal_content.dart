import 'package:deen_companion/features/profile/presentation/screens/legal_text_screen.dart';

/// Condensed, mobile-friendly versions of the full Privacy Policy and Terms
/// documents. Keep these in sync with the hosted HTML versions used for
/// the Play Console listing — this is the quick-reference copy shown
/// in-app.
class LegalContent {
  LegalContent._();

  static List<LegalSection> privacySections = [
    LegalSection(
      'No accounts, no sign-up',
      'Deen Companion has no login or account system. We never collect your '
          'name, email, or phone number, because the app never asks for them.',
    ),
    LegalSection(
      'Location data',
      'If you use Prayer Times or Qibla Direction, the app requests your '
          "device location to calculate accurate results for where you are. "
          "Your coordinates are sent only to the prayer-times provider for "
          "that calculation — never stored on our servers or linked to an "
          "identity. You can deny or revoke this permission anytime in your "
          "device settings.",
    ),
    LegalSection(
      'What stays on your device',
      'Favorites and Recent Activity are saved locally on your device only, '
          'and are never transmitted to us. Uninstalling the app or clearing '
          'its storage permanently deletes this data.',
    ),
    LegalSection(
      'No ads, no analytics, no selling data',
      "This app doesn't contain advertising or analytics SDKs, and we don't "
          "sell or share your data with third parties for marketing purposes.",
    ),
    LegalSection(
      'Third-party content sources',
      'Quran, Hadith, Dua, and prayer-time content is fetched from '
          'third-party APIs over an encrypted connection. These requests do '
          'not include any personal or account information.',
    ),
    LegalSection(
      'Full policy',
      'The complete Privacy Policy, including our Play Store Data Safety '
          'disclosures, is available at the link in the app listing.',
    ),
  ];

  static const termsSections = [
    LegalSection(
      'Religious content disclaimer',
      'Deen Companion is an educational and devotional aid, not a substitute '
          'for consulting qualified Islamic scholars. Quran translations, '
          'Hadith gradings, and similar content are sourced from third-party '
          'providers and may reflect scholarly interpretation or disagreement.',
    ),
    LegalSection(
      'Prayer times & Qibla accuracy',
      'Prayer times and Qibla direction are calculated estimates based on '
          'your location, device compass, and standard calculation methods. '
          'For anything time-critical, please verify with your local mosque '
          'or religious authority rather than relying solely on the app.',
    ),
    LegalSection(
      'Local data, no cloud backup',
      "Favorites and Recent Activity live only on your device. We don't "
          'operate a server that stores or backs up this data, so it cannot '
          'be recovered if you uninstall the app or switch devices.',
    ),
    LegalSection(
      'Acceptable use',
      "Please don't use the app unlawfully, attempt to reverse-engineer it, "
          'or misrepresent religious content sourced through it.',
    ),
    LegalSection(
      'No warranty',
      'The app is provided "as is," without warranties of accuracy or '
          'uninterrupted availability, to the extent permitted by law.',
    ),
    LegalSection(
      'Full terms',
      'The complete Terms & Conditions are available at the link in the app '
          'listing.',
    ),
  ];
}
