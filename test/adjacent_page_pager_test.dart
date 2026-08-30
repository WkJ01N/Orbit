import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/adjacent_page_pager.dart';

void main() {
  Future<({AdjacentPagePagerController controller, int Function() page})>
  pumpPager(WidgetTester tester, {bool reduceMotion = false}) async {
    final controller = AdjacentPagePagerController();
    var page = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: StatefulBuilder(
                builder: (context, setState) => AdjacentPagePager(
                  pageKey: page,
                  controller: controller,
                  reduceMotion: reduceMotion,
                  previousChild: ColoredBox(
                    color: Colors.red,
                    child: Text('previous-${page - 1}'),
                  ),
                  nextChild: ColoredBox(
                    color: Colors.green,
                    child: Text('next-${page + 1}'),
                  ),
                  onSwipeToPrevious: () => setState(() => page--),
                  onSwipeToNext: () => setState(() => page++),
                  child: ColoredBox(
                    color: Colors.blue,
                    child: Text('current-$page'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (controller: controller, page: () => page);
  }

  double translationX(WidgetTester tester, String key) {
    final transform = tester.widget<Transform>(find.byKey(Key(key)));
    return transform.transform.getTranslation().x;
  }

  testWidgets('horizontal drag follows the pointer and reveals next page', (
    tester,
  ) async {
    await pumpPager(tester);

    final gesture = await tester.startGesture(const Offset(150, 100));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(translationX(tester, 'adjacent-page-current'), closeTo(-60, 0.1));
    expect(translationX(tester, 'adjacent-page-next'), closeTo(240, 0.1));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('short drag snaps back without committing navigation', (
    tester,
  ) async {
    final harness = await pumpPager(tester);

    final gesture = await tester.startGesture(const Offset(150, 100));
    await gesture.moveBy(const Offset(-50, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.page(), 0);
    expect(translationX(tester, 'adjacent-page-current'), 0);
  });

  testWidgets('committed drag updates exactly one page', (tester) async {
    final harness = await pumpPager(tester);

    final gesture = await tester.startGesture(const Offset(150, 100));
    await gesture.moveBy(const Offset(-100, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.page(), 1);
    expect(find.text('current-1'), findsOneWidget);
  });

  testWidgets('controller navigation is animated and rejects reentry', (
    tester,
  ) async {
    final harness = await pumpPager(tester);

    harness.controller.animateToNext();
    harness.controller.animateToNext();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(translationX(tester, 'adjacent-page-current'), lessThan(0));
    await tester.pumpAndSettle();

    expect(harness.page(), 1);
  });

  testWidgets('reduced motion commits controller navigation immediately', (
    tester,
  ) async {
    final harness = await pumpPager(tester, reduceMotion: true);

    await harness.controller.animateToPrevious();
    await tester.pump();

    expect(harness.page(), -1);
    expect(translationX(tester, 'adjacent-page-current'), 0);
  });

  testWidgets('vertical scrolling gesture does not navigate', (tester) async {
    final harness = await pumpPager(tester);

    await tester.drag(find.byType(AdjacentPagePager), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(harness.page(), 0);
  });
}
