import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/settings/privacy_policy_page.dart';
import 'package:orbit/l10n/app_localizations.dart';

Widget _host({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const PrivacyPolicyPage(),
);

void main() {
  testWidgets('privacy page spells out what is collected and deleted', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('What is collected'), findsOneWidget);
    expect(find.text('Where it is stored'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Your controls'), 200);
    expect(find.text('Keeping and deleting'), findsOneWidget);
    expect(find.text('Beta notice'), findsOneWidget);
    expect(find.text('Your controls'), findsOneWidget);
  });

  testWidgets('traditional Chinese readers get traditional copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
      ),
    );

    expect(find.text('隱私政策'), findsOneWidget);
    expect(find.text('收集哪些資料'), findsOneWidget);
  });

  testWidgets('simplified Chinese readers get simplified copy', (tester) async {
    await tester.pumpWidget(_host(locale: const Locale('zh')));

    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('收集哪些数据'), findsOneWidget);
  });
}
