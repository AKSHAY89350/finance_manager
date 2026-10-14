import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/pending_provider.dart';

class SmsSyncResult {
  final int totalScanned;
  final int newAdded;
  final bool permissionGranted;

  const SmsSyncResult({
    required this.totalScanned,
    required this.newAdded,
    required this.permissionGranted,
  });
}

class SmsSyncService {
  SmsSyncService._();
  static final SmsSyncService instance = SmsSyncService._();

  static const MethodChannel _channel = MethodChannel('com.financeapp.finance_manager/sms');
  bool _initialized = false;

  /// Initializes the live incoming SMS listener and pulls any SMS queued while the app was closed.
  void initialize(WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final body = data['body'] as String? ?? '';
        final sender = data['sender'] as String?;
        final timestampMs = data['timestamp'] as int?;
        final date = timestampMs != null ? DateTime.fromMillisecondsSinceEpoch(timestampMs) : null;

        if (body.isNotEmpty) {
          await ref.read(pendingNotifierProvider.notifier).processIncomingMessage(
                body,
                sender: sender,
                timestamp: date,
              );
        }
      }
    });

    // Process messages that arrived while the app was closed
    _processQueuedSms(ref);
  }

  /// Processes offline-queued messages stored by the native BroadcastReceiver
  Future<int> _processQueuedSms(WidgetRef ref) async {
    try {
      final queued = await _channel.invokeListMethod<Map>('getQueuedSms');
      if (queued == null || queued.isEmpty) return 0;

      int addedCount = 0;
      for (final item in queued) {
        final map = Map<String, dynamic>.from(item);
        final body = map['body'] as String? ?? '';
        final sender = map['sender'] as String?;
        final timestampMs = map['timestamp'] as int?;
        final date = timestampMs != null ? DateTime.fromMillisecondsSinceEpoch(timestampMs) : null;

        if (body.isNotEmpty) {
          final added = await ref.read(pendingNotifierProvider.notifier).processIncomingMessage(
                body,
                sender: sender,
                timestamp: date,
              );
          if (added) addedCount++;
        }
      }
      return addedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if SMS read permission is currently granted
  Future<bool> hasPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Requests SMS permission from the user
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Syncs recent bank messages from the device SMS inbox (e.g. today or last 7 days).
  /// This lets the user import payment SMS received earlier with 1 tap.
  Future<SmsSyncResult> syncRecentInbox(
    WidgetRef ref, {
    int limit = 50,
    int daysBack = 7,
  }) async {
    bool granted = await hasPermission();
    if (!granted) {
      granted = await requestPermission();
    }
    if (!granted) {
      return const SmsSyncResult(totalScanned: 0, newAdded: 0, permissionGranted: false);
    }

    try {
      final messages = await _channel.invokeListMethod<Map>('fetchRecentInboxSms', {
        'limit': limit,
        'daysBack': daysBack,
      });

      if (messages == null || messages.isEmpty) {
        return const SmsSyncResult(totalScanned: 0, newAdded: 0, permissionGranted: true);
      }

      int newAdded = 0;
      for (final item in messages) {
        final map = Map<String, dynamic>.from(item);
        final body = map['body'] as String? ?? '';
        final sender = map['sender'] as String?;
        final timestampMs = map['timestamp'] as int?;
        final date = timestampMs != null ? DateTime.fromMillisecondsSinceEpoch(timestampMs) : null;

        if (body.isNotEmpty) {
          final added = await ref.read(pendingNotifierProvider.notifier).processIncomingMessage(
                body,
                sender: sender,
                timestamp: date,
              );
          if (added) newAdded++;
        }
      }

      return SmsSyncResult(
        totalScanned: messages.length,
        newAdded: newAdded,
        permissionGranted: true,
      );
    } catch (_) {
      return const SmsSyncResult(totalScanned: 0, newAdded: 0, permissionGranted: true);
    }
  }
}
