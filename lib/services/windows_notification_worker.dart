import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit/models/reminder_alarm_spec.dart';
import 'package:timezone/timezone.dart' as tz;

/// All Windows notification FFI calls belong to this long-lived isolate.
/// Returning a Future from the plugin does not make its native calls nonblocking.
class WindowsNotificationWorker {
  WindowsNotificationWorker({
    this.backendFactory = NativeWindowsNotificationBackend.new,
  });

  final WindowsNotificationBackend Function() backendFactory;
  final Map<int, Completer<Object?>> _pending = {};
  ReceivePort? _messages;
  ReceivePort? _errors;
  ReceivePort? _exits;
  Isolate? _isolate;
  SendPort? _commands;
  Future<void>? _starting;
  Completer<void>? _ready;
  int _nextId = 0;
  bool _disposed = false;
  void Function(String?)? onNotificationTap;

  Future<void> initialize() => _starting ??= _start();

  Future<void> _start() async {
    if (_disposed) throw StateError('Notification worker disposed');
    final ready = _ready = Completer<void>();
    _messages = ReceivePort()
      ..listen((message) {
        if (message is SendPort) {
          _commands = message;
          ready.complete();
        } else if (message is _NotificationTap) {
          onNotificationTap?.call(message.payload);
        } else if (message is _Reply) {
          final completer = _pending.remove(message.id);
          if (message.error == null) {
            completer?.complete(message.value);
          } else {
            completer?.completeError(
              StateError(message.error!),
              StackTrace.fromString(message.stack ?? ''),
            );
          }
        }
      });
    _errors = ReceivePort()
      ..listen(
        (error) =>
            _fail(StateError('Windows notification worker failed: $error')),
      );
    _exits = ReceivePort()
      ..listen((_) => _fail(StateError('Windows notification worker exited')));
    try {
      _isolate = await Isolate.spawn(
        _runWindowsNotifications,
        (_messages!.sendPort, backendFactory),
        onError: _errors!.sendPort,
        onExit: _exits!.sendPort,
        debugName: 'Orbit Windows notifications',
      );
      await ready.future;
    } catch (error, stack) {
      _fail(error, stack);
      rethrow;
    }
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_ready?.isCompleted == false) _ready!.completeError(error, stack);
    for (final completer in _pending.values) {
      completer.completeError(error, stack);
    }
    _pending.clear();
    _commands = null;
    _messages?.close();
    _errors?.close();
    _exits?.close();
    _starting = null;
  }

  Future<Object?> _request(String operation, [Object? data]) async {
    await initialize();
    if (_disposed) throw StateError('Notification worker disposed');
    final id = ++_nextId;
    final result = Completer<Object?>();
    _pending[id] = result;
    _commands!.send((id, operation, data));
    return result.future;
  }

  Future<List<int>> pendingIds() async =>
      (await _request('pending'))! as List<int>;

  Future<void> cancel(int id) async {
    await _request('cancel', id);
  }

  Future<void> schedule(ReminderAlarmSpec spec) async {
    await _request('schedule', spec);
  }

  Future<void> show(int id, String title, String body, String payload) async {
    await _request('show', (id, title, body, payload));
  }

  Future<String?> launchPayload() async => await _request('launch') as String?;

  /// Used by tests; the application keeps the COM notification callback alive
  /// until process exit instead of repeatedly creating and destroying it.
  void dispose() {
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _fail(StateError('Notification worker disposed'));
  }
}

abstract interface class WindowsNotificationBackend {
  Future<void> initialize(void Function(String?) onTap);
  Future<List<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule(ReminderAlarmSpec spec);
  Future<void> show(int id, String title, String body, String payload);
  Future<String?> launchPayload();
}

class NativeWindowsNotificationBackend implements WindowsNotificationBackend {
  NativeWindowsNotificationBackend({
    this.initializationSettings = const WindowsInitializationSettings(
      appName: 'Orbit',
      appUserModelId: 'com.must.orbit',
      guid: '7f8d9c2a-4b1e-4f6a-9c3d-2e1f0a9b8c7d',
    ),
  });

  final WindowsInitializationSettings initializationSettings;
  final _plugin = FlutterLocalNotificationsWindows();

  @override
  Future<void> initialize(void Function(String?) onTap) async {
    final initialized = await _plugin.initialize(
      initializationSettings,
      onNotificationReceived: (response) => onTap(response.payload),
    );
    if (!initialized) throw StateError('Windows notifications unavailable');
  }

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((n) => n.id).toList();

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> schedule(ReminderAlarmSpec spec) => _plugin.zonedScheduleRawXml(
    spec.notificationId,
    windowsReminderXml(spec),
    tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      spec.fireAt.millisecondsSinceEpoch,
    ),
    const WindowsNotificationDetails(),
  );

  @override
  Future<void> show(int id, String title, String body, String payload) =>
      _plugin.show(
        id,
        title,
        body,
        payload: payload,
        details: const WindowsNotificationDetails(),
      );

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }
}

/// System dismiss stops the Windows alarm sound without cancelling repetitions.
String windowsReminderXml(ReminderAlarmSpec spec) {
  String escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  final strong = spec.strong.enabled;
  final ack = jsonEncode({
    'action': 'ack',
    'rule': spec.ruleId,
    'session': spec.sessionId,
  });
  return '<toast launch="${escape(spec.payload)}" ${strong ? 'scenario="alarm" duration="long"' : ''}>'
      '<visual><binding template="ToastGeneric"><text>${escape(spec.title)}</text>'
      '<text>${escape(spec.body)}</text></binding></visual>'
      '${strong ? '<audio src="ms-winsoundevent:Notification.Looping.Alarm${spec.strong.windowsSound.clamp(1, 10)}" loop="true"/>' : ''}'
      '<actions>${spec.ruleId != null && spec.acknowledgeLabel.isNotEmpty ? '<action content="${escape(spec.acknowledgeLabel)}" '
                'arguments="${escape(ack)}" activationType="foreground"/>' : ''}'
      '${strong ? '<action content="${escape(spec.stopLabel)}" arguments="dismiss" activationType="system"/>' : ''}'
      '</actions></toast>';
}

class _Reply {
  const _Reply(this.id, {this.value, this.error, this.stack});
  final int id;
  final Object? value;
  final String? error;
  final String? stack;
}

class _NotificationTap {
  const _NotificationTap(this.payload);
  final String? payload;
}

@pragma('vm:entry-point')
Future<void> _runWindowsNotifications(
  (SendPort, WindowsNotificationBackend Function()) configuration,
) async {
  final (host, factory) = configuration;
  final backend = factory();
  await backend.initialize((payload) => host.send(_NotificationTap(payload)));
  final commands = ReceivePort();
  host.send(commands.sendPort);
  // Sequential processing preserves cancellation/scheduling order even if
  // settings changes and foreground requests arrive together.
  await for (final message in commands) {
    final (id, operation, data) = message as (int, String, Object?);
    try {
      Object? value;
      switch (operation) {
        case 'pending':
          value = await backend.pendingIds();
        case 'cancel':
          await backend.cancel(data! as int);
        case 'schedule':
          await backend.schedule(data! as ReminderAlarmSpec);
        case 'show':
          final (notificationId, title, body, payload) =
              data! as (int, String, String, String);
          await backend.show(notificationId, title, body, payload);
        case 'launch':
          value = await backend.launchPayload();
        default:
          throw ArgumentError('Unknown notification operation: $operation');
      }
      host.send(_Reply(id, value: value));
    } catch (error, stack) {
      host.send(_Reply(id, error: '$error', stack: '$stack'));
    }
  }
}
