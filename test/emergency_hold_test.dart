import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/reminder/emergency_hold_button.dart';

void main() {
  testWidgets(
    'whole bar holds for five seconds through rebuilds inside a scroll view',
    (tester) async {
      var stopped = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (c, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      EmergencyHoldButton(
                        enabled: true,
                        onComplete: () async {
                          stopped++;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final target = find.byKey(const Key('emergency-hold'));
      final gesture = await tester.startGesture(
        tester.getTopLeft(target) + const Offset(8, 28),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('emergency-hold-progress')),
            )
            .value,
        closeTo(.4, .01),
      );
      rebuild(() {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(stopped, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(stopped, 1);
      await gesture.up();
      await tester.pump();
      expect(stopped, 1);
    },
  );
  testWidgets(
    'early release, leaving bounds and backgrounding cancel the hold',
    (tester) async {
      var stopped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyHoldButton(
              enabled: true,
              onComplete: () async {
                stopped++;
              },
            ),
          ),
        ),
      );
      final target = find.byKey(const Key('emergency-hold'));
      var gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(stopped, 0);
      gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 500));
      await tester.pump(const Duration(seconds: 6));
      await gesture.up();
      expect(stopped, 0);
      gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      await gesture.up();
      expect(stopped, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
}
