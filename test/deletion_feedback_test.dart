import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/session/deletion_feedback.dart';
import 'package:orbit/l10n/app_localizations.dart';

void main() {
  testWidgets('deletion undo snackbar dismisses automatically', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDeletionUndo(
                  context: context,
                  container: ProviderScope.containerOf(context),
                  ids: const ['session-id'],
                  message: 'Course deleted',
                ),
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Course deleted'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Course deleted'), findsNothing);
  });
}
