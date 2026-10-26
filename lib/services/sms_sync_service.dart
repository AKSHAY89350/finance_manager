import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/pending_provider.dart';

class SmsSyncResult {
  final int totalScanned;
  final int newAdded;
  final bool permissionGranted;
  final int? latestTimestamp;
  final String? lastSyncTimeFormatted;

  const SmsSyncResult({
    required this.totalScanned,
    required this.newAdded,
    required this.permissionGranted,
    this.latestTimestamp,
    this.lastSyncTimeFormatted,
  });
}

class SmsSyncService {
  SmsSyncService._();
  static final SmsSyncService instance = SmsSyncService._();

  static const MethodChannel _channel = MethodChannel('com.financeapp.finance_manager/sms');
  static const String _keyLastSyncTimestamp = 'sms_last_sync_timestamp';
  static const String _keyLastSyncTimeStr = 'sms_last_sync_time_str';

  bool _initialized = false;
  bool _isSyncing = false;

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
          if (timestampMs != null) {
            final cur = await getLastSyncTimestamp();
            if (timestampMs > cur) {
              await setLastSyncTimestamp(timestampMs);
            }
          }
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

      final rawList = <Map<String, dynamic>>[];
      int maxTs = 0;
      for (final item in queued) {
        final map = Map<String, dynamic>.from(item);
        final ts = map['timestamp'] as int? ?? 0;
        if (ts > maxTs) maxTs = ts;
        rawList.add(map);
      }

      final addedCount = await ref
          .read(pendingNotifierProvider.notifier)
          .processIncomingMessagesBatch(rawList);

      if (maxTs > 0) {
        final cur = await getLastSyncTimestamp();
        if (maxTs > cur) {
          await setLastSyncTimestamp(maxTs);
        }
      }

      return addedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Gets the last synced SMS timestamp (in milliseconds since epoch)
  Future<int> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastSyncTimestamp) ?? 0;
  }

  /// Formats human-friendly string for the last sync time (e.g. "Today at 05:32 PM")
  Future<String?> getLastSyncTimeFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSyncTimeStr);
  }

  /// Updates the last sync timestamp in persistent storage
  Future<void> setLastSyncTimestamp(int timestamp) async {
    if (timestamp <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSyncTimestamp, timestamp);

    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(dt);
    final String formatted;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      formatted = 'Today at $timeStr';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      formatted = 'Yesterday at $timeStr';
    } else {
      formatted = '${DateFormat('dd MMM yyyy').format(dt)}, $timeStr';
    }
    await prefs.setString(_keyLastSyncTimeStr, formatted);
  }

  /// Resets the sync timestamp to allow a full rescan from scratch
  Future<void> resetSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSyncTimestamp);
    await prefs.remove(_keyLastSyncTimeStr);
  }

  /// Checks if SMS permissions are currently granted via native Android API
  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkSmsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests SMS permissions from the user via native Android system prompt
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Syncs bank messages from device SMS inbox starting strictly AFTER the last synced timestamp.
  /// If forceFullScan is true, scans past messages according to daysBack.
  Future<SmsSyncResult> syncRecentInbox(
    WidgetRef ref, {
    int limit = 200,
    int daysBack = 7,
    bool forceFullScan = false,
  }) async {
    if (_isSyncing) {
      final lastTimeStr = await getLastSyncTimeFormatted();
      return SmsSyncResult(
        totalScanned: 0,
        newAdded: 0,
        permissionGranted: true,
        lastSyncTimeFormatted: lastTimeStr,
      );
    }
    _isSyncing = true;

    try {
      bool granted = await hasPermission();
      if (!granted) {
        granted = await requestPermission();
      }
      if (!granted) {
        _isSyncing = false;
        return const SmsSyncResult(totalScanned: 0, newAdded: 0, permissionGranted: false);
      }

      final lastSync = forceFullScan ? 0 : await getLastSyncTimestamp();
      // Safe buffer: 2 seconds overlap to guard against identical timestamps
      final querySince = (lastSync > 2000) ? (lastSync - 2000) : 0;

      final messages = await _channel.invokeListMethod<Map>('fetchRecentInboxSms', {
        'limit': limit,
        'daysBack': daysBack,
        'sinceTimestamp': querySince,
      });

      if (messages == null || messages.isEmpty) {
        final lastTimeStr = await getLastSyncTimeFormatted();
        _isSyncing = false;
        return SmsSyncResult(
          totalScanned: 0,
          newAdded: 0,
          permissionGranted: true,
          latestTimestamp: lastSync,
          lastSyncTimeFormatted: lastTimeStr,
        );
      }

      int maxTimestampSeen = lastSync;
      final rawList = <Map<String, dynamic>>[];

      for (final item in messages) {
        final map = Map<String, dynamic>.from(item);
        final ts = map['timestamp'] as int? ?? 0;
        if (ts > maxTimestampSeen) {
          maxTimestampSeen = ts;
        }
        rawList.add(map);
      }

      final newAdded = await ref
          .read(pendingNotifierProvider.notifier)
          .processIncomingMessagesBatch(rawList);

      if (maxTimestampSeen > lastSync) {
        await setLastSyncTimestamp(maxTimestampSeen);
      } else if (lastSync == 0 && rawList.isNotEmpty) {
        await setLastSyncTimestamp(DateTime.now().millisecondsSinceEpoch);
      }

      final lastTimeStr = await getLastSyncTimeFormatted();
      _isSyncing = false;
      return SmsSyncResult(
        totalScanned: messages.length,
        newAdded: newAdded,
        permissionGranted: true,
        latestTimestamp: maxTimestampSeen,
        lastSyncTimeFormatted: lastTimeStr,
      );
    } catch (_) {
      _isSyncing = false;
      final lastTimeStr = await getLastSyncTimeFormatted();
      return SmsSyncResult(
        totalScanned: 0,
        newAdded: 0,
        permissionGranted: true,
        lastSyncTimeFormatted: lastTimeStr,
      );
    }
  }

  /// Automatically triggered whenever user opens or resumes the app.
  /// Runs silently in background without prompting permissions if not granted.
  Future<int> syncOnAppOpen(WidgetRef ref) async {
    final granted = await hasPermission();
    if (!granted) return 0;

    final result = await syncRecentInbox(ref, limit: 150);
    return result.newAdded;
  }
}
