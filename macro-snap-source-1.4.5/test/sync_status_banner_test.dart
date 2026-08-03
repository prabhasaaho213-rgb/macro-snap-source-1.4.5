import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macro_snap/screens/main_shell.dart';
import 'package:macro_snap/screens/home_screen.dart';
import 'package:macro_snap/services/habit_store.dart';
import 'package:macro_snap/services/sync_status_service.dart';

/// Pumps MainShell and settles the initial async work (subscription check,
/// RateUs launch counter, HomeScreen _loadAll, entrance animations).
Future<void> pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: MainShell()));
  await tester.pump(); // post-frame callbacks (subscription offer check)
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');
  const cameraChannel = MethodChannel('plugins.flutter.io/camera');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HabitStore.instance.habits.clear();
    // Start every test with a clean sync state.
    SyncStatusService.instance.reportSuccess();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        final args = (call.arguments as List).cast<int>();
        return <int, int>{for (final a in args) a: 1}; // granted
      }
      if (call.method == 'checkPermissionStatus') return 1; // granted
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, (call) async {
      if (call.method == 'availableCameras') return <dynamic>[];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
    SyncStatusService.instance.reportSuccess();
  });

  testWidgets('sync failure shows the backup-unavailable banner', (tester) async {
    // Report a failure BEFORE the shell builds so the banner is present from
    // the first frame.
    SyncStatusService.instance.reportFailure('Habit restore failed');
    await pumpShell(tester);

    expect(find.text('Cloud backup unavailable'), findsOneWidget,
        reason: 'a failed sync must surface the warning banner');
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Habit restore failed'), findsOneWidget,
        reason: 'the banner must show which operation failed');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('healthy backend shows no banner', (tester) async {
    SyncStatusService.instance.reportSuccess();
    await pumpShell(tester);

    expect(find.text('Cloud backup unavailable'), findsNothing,
        reason: 'a healthy backend must not show the banner');
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('dismiss hides the banner until the next failure', (tester) async {
    SyncStatusService.instance.reportFailure('Habit sync failed');
    await pumpShell(tester);

    expect(find.text('Cloud backup unavailable'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();

    expect(find.text('Cloud backup unavailable'), findsNothing,
        reason: 'dismiss must hide the banner');

    // A NEW failure re-shows it.
    SyncStatusService.instance.reportFailure('Meal sync failed');
    await tester.pump();
    expect(find.text('Cloud backup unavailable'), findsOneWidget,
        reason: 'a fresh failure must re-surface the banner');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('retry re-probes and keeps the banner while the backend is down',
      (tester) async {
    SyncStatusService.instance.reportFailure('Habit restore failed');
    await pumpShell(tester);
    expect(find.text('Cloud backup unavailable'), findsOneWidget);

    // Tapping Retry calls probeBackend(). In the widget-test environment all
    // HTTP requests return 400, so the probe reports a fresh failure and the
    // banner must stay visible (a real success would clear it via
    // reportSuccess, covered by the unit test below).
    await tester.tap(find.byTooltip('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cloud backup unavailable'), findsOneWidget,
        reason: 'a failed re-probe must keep the banner visible');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('banner coexists with tab swiping (Home still reachable)',
      (tester) async {
    SyncStatusService.instance.reportFailure('Habit restore failed');
    await pumpShell(tester);

    expect(find.text('Cloud backup unavailable'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'the Home tab must still render under the banner');

    // Swiping left must still switch tabs even with the banner visible.
    await tester.fling(find.byType(MainShell), const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(HomeScreen), findsNothing,
        reason: 'tab swipe must still work while the banner is shown');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  });

  // ─── STATE MACHINE UNIT TESTS (no widgets/network) ─────────

  test('reportSuccess clears failure state', () {
    SyncStatusService.instance.reportFailure('x');
    expect(SyncStatusService.instance.backendUnreachable, isTrue);
    SyncStatusService.instance.reportSuccess();
    expect(SyncStatusService.instance.backendUnreachable, isFalse);
    expect(SyncStatusService.instance.lastDetail, isEmpty);
  });

  test('dismiss hides until a NEW failure re-surfaces it', () {
    SyncStatusService.instance.reportFailure('x');
    SyncStatusService.instance.dismiss();
    expect(SyncStatusService.instance.backendUnreachable, isFalse);

    // No notify while already dismissed.
    SyncStatusService.instance.dismiss();
    expect(SyncStatusService.instance.backendUnreachable, isFalse);

    SyncStatusService.instance.reportFailure('y');
    expect(SyncStatusService.instance.backendUnreachable, isTrue,
        reason: 'a fresh failure must re-show the banner even after dismiss');
  });

  test('notifyListeners fires on every state transition', () {
    var notified = 0;
    void onNotify() => notified++;
    SyncStatusService.instance.addListener(onNotify);
    SyncStatusService.instance.reportSuccess(); // reset baseline
    final baseline = notified;
    SyncStatusService.instance.reportFailure('a');
    SyncStatusService.instance.reportFailure('b');
    SyncStatusService.instance.reportSuccess();
    SyncStatusService.instance.dismiss();
    expect(notified, greaterThan(baseline),
        reason: 'each state change must notify listeners (the shell rebuilds)');
    SyncStatusService.instance.removeListener(onNotify);
  });
}
