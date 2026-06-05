import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/l10n/locale_utils.dart';
void main() {
  test('三種語言關鍵字串非空', () {
    for (final locale in supportedAppLocales) {
      final l10n = lookupL10n(locale);
      expect(l10n.navGrid.isNotEmpty, true);
      expect(l10n.navUpcoming.isNotEmpty, true);
      expect(l10n.navImport.isNotEmpty, true);
      expect(l10n.navSettings.isNotEmpty, true);
      expect(l10n.leadTimeOption(120).isNotEmpty, true);
      expect(l10n.notificationTitle(60).isNotEmpty, true);
      expect(l10n.notificationCheckInTitle('PHYS102', 'C508').isNotEmpty, true);
      expect(l10n.notificationNextDayBody(3, '09:00').isNotEmpty, true);
    }
  });
}
