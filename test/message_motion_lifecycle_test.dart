import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/app_snack_bar.dart';

void main() {
  for (final phase in ['entry', 'exit']) {
    testWidgets('a delayed frame cannot skip the whole $phase motion', (
      tester,
    ) async {
      late ScaffoldMessengerState messenger;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AppScaffoldMessenger(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      messenger.showAppSnackBar(const SnackBar(content: Text('first')));
      messenger.showAppSnackBar(const SnackBar(content: Text('second')));
      await tester.pump();
      await tester.pump();
      if (phase == 'exit') {
        await tester.pumpAndSettle();
        messenger.hideCurrentSnackBar();
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));
      final opacity = find.ancestor(
        of: find.text('first'),
        matching: find.byType(Opacity),
      );
      expect(
        tester.widget<Opacity>(opacity).opacity,
        allOf(greaterThan(0), lessThan(1)),
      );
      expect(find.text('second'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(phase == 'entry' ? 'first' : 'second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'dialog overlay finishes exiting before feedback starts entering',
    (tester) async {
      final routes = AppMessageRouteObserver();
      late ScaffoldMessengerState messenger;
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          builder: (context, child) =>
              AppScaffoldMessenger(routeObserver: routes, child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                page = context;
                messenger = ScaffoldMessenger.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      showDialog<void>(
        context: page,
        builder: (context) =>
            const AlertDialog(content: Text('Confirm deletion')),
      );
      await tester.pumpAndSettle();
      Navigator.of(page).pop();
      messenger.showAppSnackBar(const SnackBar(content: Text('Deleted')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(routes.hasExitingOverlay, true);
      final bar = tester.widget<SnackBar>(
        find.byWidgetPredicate((w) => w is SnackBar),
      );
      expect(bar.animation!.value, 0);
      await tester.pumpAndSettle();
      expect(routes.hasExitingOverlay, false);
      expect(bar.animation!.value, 1);
      expect(find.text('Deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final assistive in [false, true]) {
    for (final close in [
      SnackBarClosedReason.dismiss,
      SnackBarClosedReason.hide,
      SnackBarClosedReason.timeout,
      SnackBarClosedReason.action,
    ]) {
      testWidgets(
        'assistive $assistive preserves motion and close reason $close',
        (tester) async {
          late ScaffoldMessengerState messenger;
          var acted = false;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(accessibleNavigation: assistive),
                child: AppScaffoldMessenger(child: child!),
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    messenger = ScaffoldMessenger.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
          final first = messenger.showAppSnackBar(
            SnackBar(
              content: const Text('first'),
              action: close == SnackBarClosedReason.action
                  ? SnackBarAction(label: 'Undo', onPressed: () => acted = true)
                  : null,
            ),
          );
          var finished = false;
          SnackBarClosedReason? closedReason;
          first.closed.then((reason) {
            finished = true;
            closedReason = reason;
          });
          messenger.showAppSnackBar(const SnackBar(content: Text('second')));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          final opacity = find.ancestor(
            of: find.text('first'),
            matching: find.byType(Opacity),
          );
          expect(
            tester.widget<Opacity>(opacity).opacity,
            allOf(greaterThan(0), lessThan(1)),
          );
          await tester.pumpAndSettle();
          if (close == SnackBarClosedReason.timeout) {
            await tester.pump(const Duration(seconds: 4));
          } else if (close == SnackBarClosedReason.action) {
            await tester.tap(find.text('Undo'));
          } else {
            messenger.hideCurrentSnackBar(reason: close);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(finished, false);
          expect(
            tester.widget<Opacity>(opacity).opacity,
            allOf(greaterThan(0), lessThan(1)),
          );
          expect(find.text('second'), findsNothing);
          await tester.pumpAndSettle();
          expect(finished, true);
          expect(closedReason, close);
          expect(acted, close == SnackBarClosedReason.action);
          expect(find.text('second'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(find.text('second'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'assistive navigation leaves reduced motion and semantics unchanged',
    (tester) async {
      late ScaffoldMessengerState messenger;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(accessibleNavigation: true, disableAnimations: true),
            child: AppScaffoldMessenger(child: child!),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                expect(MediaQuery.accessibleNavigationOf(context), true);
                expect(MediaQuery.disableAnimationsOf(context), true);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final message = messenger.showAppSnackBar(
        const SnackBar(content: Text('instant')),
      );
      await tester.pumpAndSettle();
      expect(
        find.ancestor(of: find.text('instant'), matching: find.byType(Opacity)),
        findsNothing,
      );
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
      await tester.pumpAndSettle();
      expect(await message.closed, SnackBarClosedReason.dismiss);
      expect(find.text('instant'), findsNothing);
    },
  );
}
