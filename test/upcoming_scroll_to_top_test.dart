import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/features/upcoming/upcoming_scroll_to_top.dart';
import 'package:orbit/l10n/app_localizations.dart';

const _floatingKey = Key('upcoming-back-to-top-floating');
const _footerKey = Key('upcoming-back-to-top-footer');
const _spaceKey = Key('upcoming-back-to-top-footer-space');

Future<void> _pumpList(
  WidgetTester tester, {
  int count = 20,
  double itemExtent = 100,
  bool reduceMotion = false,
  ThemeData? theme,
  Locale locale = const Locale('zh', 'Hans'),
  void Function(int)? onBuild,
  EdgeInsets safePadding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          padding: safePadding,
        ),
        child: Scaffold(
          body: UpcomingScrollToTop(
            sliver: SliverFixedExtentList.builder(
              itemExtent: itemExtent,
              itemCount: count,
              itemBuilder: (context, index) {
                onBuild?.call(index);
                return ColoredBox(
                  key: Key('course-$index'),
                  color: index.isEven ? Colors.teal.shade50 : Colors.white,
                  child: Center(child: Text('课程 $index')),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> _jump(WidgetTester tester, double offset) async {
  _position(tester).jumpTo(offset);
  await tester.pumpAndSettle();
}

double _progress(WidgetTester tester, Key key) {
  final builder = tester.widget<AnimatedBuilder>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(AnimatedBuilder),
    ),
  );
  return (builder.animation as Animation<double>).value;
}

void main() {
  testWidgets('progress follows each drag update before scrolling stops', (
    tester,
  ) async {
    await _pumpList(tester);
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(0, -350));
    await tester.pump();
    final position = _position(tester);
    expect(
      _progress(tester, _floatingKey),
      closeTo(position.pixels / position.maxScrollExtent, .0001),
    );
    final previous = _progress(tester, _floatingKey);
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(_progress(tester, _floatingKey), greaterThan(previous));
    expect(
      _progress(tester, _floatingKey),
      closeTo(position.pixels / position.maxScrollExtent, .0001),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'course removal at the bottom and subsequent growth refresh state',
    (tester) async {
      await _pumpList(tester);
      await _jump(tester, _position(tester).maxScrollExtent);
      expect(find.byKey(_footerKey).hitTestable(), findsOneWidget);
      await _pumpList(tester, count: 3);
      expect(_position(tester).maxScrollExtent, 0);
      expect(find.byKey(_footerKey), findsNothing);
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      await _pumpList(tester);
      expect(_position(tester).maxScrollExtent, greaterThan(0));
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      await _jump(tester, 400);
      expect(find.byKey(_floatingKey).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'footer transfer reverses continuously with only the target interactive',
    (tester) async {
      await _pumpList(tester);
      final extent = _position(tester).maxScrollExtent;
      await _jump(tester, extent - 80);
      double opacity(Key key) => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.byKey(key), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      _position(tester).jumpTo(extent);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final floatingOpacity = opacity(_floatingKey);
      final footerOpacity = opacity(_footerKey);
      expect(floatingOpacity, inExclusiveRange(0.0, 1.0));
      expect(footerOpacity, inExclusiveRange(0.0, 1.0));
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      expect(find.byKey(_footerKey).hitTestable(), findsOneWidget);
      _position(tester).jumpTo(extent - 40);
      await tester.pump();
      await tester.pump();
      expect(opacity(_floatingKey), closeTo(floatingOpacity, 0.001));
      expect(opacity(_footerKey), closeTo(footerOpacity, 0.001));
      expect(find.byKey(_floatingKey).hitTestable(), findsOneWidget);
      expect(find.byKey(_footerKey).hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(opacity(_floatingKey), 1);
      expect(opacity(_footerKey), 0);
      expect(_position(tester).maxScrollExtent, extent);
    },
  );

  testWidgets('floating button avoids the system bottom safe area', (
    tester,
  ) async {
    await _pumpList(tester, safePadding: const EdgeInsets.only(bottom: 24));
    await _jump(tester, 400);
    expect(tester.getRect(find.byKey(_floatingKey)).bottom, 560);
    await _jump(tester, _position(tester).maxScrollExtent);
    expect(tester.getRect(find.byKey(_footerKey)).bottom, 560);
  });

  testWidgets(
    'half-screen threshold, top hysteresis, and lazy course building',
    (tester) async {
      final built = <int>{};
      await _pumpList(tester, onBuild: built.add);
      expect(built.length, lessThan(20));
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      await _jump(tester, 290);
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      await _jump(tester, 320);
      expect(find.byKey(_floatingKey).hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byKey(_floatingKey)), const Size(56, 56));
      final rect = tester.getRect(find.byKey(_floatingKey));
      expect(rect.right, 384);
      expect(rect.bottom, 584);
      await _jump(tester, 100);
      expect(find.byKey(_floatingKey).hitTestable(), findsOneWidget);
      await _jump(tester, 48);
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      await _jump(tester, 0);
      expect(_progress(tester, _floatingKey), 0);
    },
  );

  testWidgets(
    'progress follows current fraction immediately and reaches a full ring',
    (tester) async {
      await _pumpList(tester);
      final extent = _position(tester).maxScrollExtent;
      _position(tester).jumpTo(extent / 2);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_progress(tester, _floatingKey), greaterThan(0));
      expect(_progress(tester, _floatingKey), closeTo(0.5, .001));
      await tester.pumpAndSettle();
      expect(_progress(tester, _floatingKey), closeTo(0.5, 0.001));
      await _jump(tester, extent);
      expect(_progress(tester, _footerKey), 1);
    },
  );

  testWidgets(
    'footer is centered below the last course without changing extent',
    (tester) async {
      await _pumpList(tester);
      final extent = _position(tester).maxScrollExtent;
      await _jump(tester, extent);
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      expect(find.byKey(_footerKey).hitTestable(), findsOneWidget);
      final rect = tester.getRect(find.byKey(_footerKey));
      expect(rect.center.dx, 200);
      expect(
        rect.top,
        greaterThan(tester.getRect(find.byKey(const Key('course-19'))).bottom),
      );
      expect(rect.bottom, lessThanOrEqualTo(584));
      expect(tester.getSize(find.byKey(_spaceKey)).height, 88);
      await _jump(tester, extent - 20);
      expect(find.byKey(_footerKey).hitTestable(), findsOneWidget);
      await _jump(tester, extent - 40);
      expect(find.byKey(_floatingKey).hitTestable(), findsOneWidget);
      expect(find.byKey(_footerKey).hitTestable(), findsNothing);
      expect(_position(tester).maxScrollExtent, extent);
      expect(tester.getSize(find.byKey(_spaceKey)).height, 88);
    },
  );

  testWidgets('short non-scrollable lists do not gain artificial overflow', (
    tester,
  ) async {
    await _pumpList(tester, count: 5);
    expect(_position(tester).maxScrollExtent, 0);
    expect(tester.getSize(find.byKey(_spaceKey)).height, 16);
    expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
    expect(find.byKey(_footerKey), findsNothing);
  });

  testWidgets('slightly overflowing lists still offer the footer action', (
    tester,
  ) async {
    await _pumpList(tester, count: 6, itemExtent: 101);
    expect(_position(tester).maxScrollExtent, lessThan(300));
    await _jump(tester, _position(tester).maxScrollExtent);
    expect(find.byKey(_footerKey).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(_footerKey));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 0);
    expect(find.byKey(_footerKey).hitTestable(), findsNothing);
  });

  testWidgets(
    'appearance reverses from its current value rather than resetting',
    (tester) async {
      await _pumpList(tester);
      _position(tester).jumpTo(400);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(_floatingKey),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      final showing = opacity();
      expect(showing, inExclusiveRange(0.0, 1.0));
      _position(tester).jumpTo(0);
      await tester.pump();
      await tester.pump();
      final reversing = opacity();
      expect(reversing, greaterThanOrEqualTo(showing));
      expect(reversing, lessThan(1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(opacity(), lessThan(reversing));
      _position(tester).jumpTo(400);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'return is animated, repeated presses do not restart, drag interrupts',
    (tester) async {
      await _pumpList(tester);
      await _jump(tester, 1000);
      await tester.tap(find.byKey(_floatingKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final duringReturn = _position(tester).pixels;
      expect(duringReturn, inExclusiveRange(0.0, 1000.0));
      await tester.tap(find.byKey(_floatingKey));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_position(tester).pixels, lessThan(duringReturn));
      final gesture = await tester.startGesture(const Offset(100, 200));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      final interrupted = _position(tester).pixels;
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_position(tester).pixels, interrupted);
      expect(interrupted, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_floatingKey));
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
    },
  );

  testWidgets('mouse wheel interrupts return and permits another return', (
    tester,
  ) async {
    await _pumpList(tester);
    await _jump(tester, 1000);
    await tester.tap(find.byKey(_floatingKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(100, 200),
        scrollDelta: Offset(0, 120),
      ),
    );
    await tester.pump();
    final interrupted = _position(tester).pixels;
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_position(tester).pixels, interrupted);
    expect(interrupted, greaterThan(0));
    await tester.tap(find.byKey(_floatingKey));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, 0);
  });

  testWidgets('reduced motion, dark custom theme, localized keyboard action', (
    tester,
  ) async {
    await _pumpList(
      tester,
      reduceMotion: true,
      theme: AppTheme.dark(seed: Colors.purple),
      locale: const Locale('en'),
    );
    await _jump(tester, 800);
    expect(find.byTooltip('Back to top').hitTestable(), findsOneWidget);
    expect(
      _progress(tester, _floatingKey),
      closeTo(800 / _position(tester).maxScrollExtent, 0.001),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_position(tester).pixels, 0);
    await tester.pumpAndSettle();
    expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
  });

  testWidgets(
    'resizing and shrinking courses recomputes overflow and visibility',
    (tester) async {
      await _pumpList(tester);
      await _jump(tester, _position(tester).maxScrollExtent);
      tester.view.physicalSize = const Size(1000, 2400);
      await tester.pumpAndSettle();
      expect(_position(tester).maxScrollExtent, 0);
      expect(find.byKey(_floatingKey).hitTestable(), findsNothing);
      expect(find.byKey(_footerKey), findsNothing);
      await _pumpList(tester, count: 2);
      expect(_position(tester).maxScrollExtent, 0);
      expect(find.byKey(_footerKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'variable-height list keeps a stable progress basis while scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpcomingScrollToTop(
              sliver: SliverList.builder(
                itemCount: 80,
                itemBuilder: (context, i) => SizedBox(
                  height: [60.0, 240.0, 90.0, 160.0][i % 4],
                  child: Text('Row $i'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final basis = _position(tester).maxScrollExtent;
      final gesture = await tester.startGesture(const Offset(200, 500));
      await gesture.moveBy(const Offset(0, -350));
      await tester.pump();
      expect(
        _progress(tester, _floatingKey),
        closeTo(_position(tester).pixels / basis, .001),
      );
      final previous = _progress(tester, _floatingKey);
      await gesture.moveBy(const Offset(0, -170));
      await tester.pump();
      expect(_progress(tester, _floatingKey), greaterThan(previous));
      expect(
        _progress(tester, _floatingKey),
        closeTo(_position(tester).pixels / basis, .001),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        _progress(tester, _floatingKey),
        closeTo(
          _position(tester).pixels / _position(tester).maxScrollExtent,
          .001,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
