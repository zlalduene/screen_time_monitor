import 'dart:convert';

import 'package:flutter/services.dart';

/// 与原生层通信的通道封装。
class MonitorApi {
  static const MethodChannel _channel =
      MethodChannel('screen_time_monitor/monitor');

  static Future<MonitorSnapshot> snapshot() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('snapshot');
    if (raw == null) {
      throw StateError('原生层未返回数据');
    }
    return MonitorSnapshot.fromMap(raw);
  }

  static Future<void> startMonitor() async {
    await _channel.invokeMethod<bool>('startMonitor');
  }

  static Future<bool> openUsageAccess() async {
    return await _channel.invokeMethod<bool>('openUsageAccess') ?? false;
  }

  static Future<bool> openNotificationSettings() async {
    return await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;
  }

  static Future<bool> openBatterySettings() async {
    return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
  }

  static Future<bool> requestIgnoreBattery() async {
    return await _channel.invokeMethod<bool>('requestIgnoreBattery') ?? false;
  }

  static Future<void> requestNotificationPermission() async {
    await _channel.invokeMethod<bool>('requestNotificationPermission');
  }

  static Future<void> setHideFromRecents(bool hidden) async {
    await _channel.invokeMethod<bool>('setHideFromRecents', hidden);
  }
}

class MonitorSnapshot {
  final Overview overview;
  final List<AppUsage> apps;
  final List<ScreenEventItem> recent;
  final PermissionStatus permissions;
  final bool hideFromRecents;

  const MonitorSnapshot({
    required this.overview,
    required this.apps,
    required this.recent,
    required this.permissions,
    required this.hideFromRecents,
  });

  factory MonitorSnapshot.fromMap(Map<String, dynamic> map) {
    return MonitorSnapshot(
      overview: Overview.fromMap(
        (map['overview'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      apps: ((map['apps'] as List?) ?? const [])
          .map((e) => AppUsage.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      recent: ((map['recent'] as List?) ?? const [])
          .map((e) => ScreenEventItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      permissions: PermissionStatus.fromMap(
        (map['permissions'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      hideFromRecents: map['hideFromRecents'] == true,
    );
  }
}

class Overview {
  final bool screenOn;
  final DateTime? lastOnAt;
  final DateTime? lastOffAt;
  final Duration? sinceLastOff;
  final Duration? session;
  final int todayOnCount;
  final Duration todayOn;
  final List<ScreenEventItem> todayEvents;
  final bool onAtDayStart;
  final DateTime now;

  const Overview({
    required this.screenOn,
    required this.lastOnAt,
    required this.lastOffAt,
    required this.sinceLastOff,
    required this.session,
    required this.todayOnCount,
    required this.todayOn,
    required this.todayEvents,
    required this.onAtDayStart,
    required this.now,
  });

  factory Overview.fromMap(Map<String, dynamic> map) {
    return Overview(
      screenOn: map['screenOn'] == true,
      lastOnAt: _date(map['lastOnAt']),
      lastOffAt: _date(map['lastOffAt']),
      sinceLastOff: _duration(map['sinceLastOffMs']),
      session: _duration(map['sessionMs']),
      todayOnCount: _int(map['todayOnCount']),
      todayOn: Duration(milliseconds: _int(map['todayOnMs'])),
      todayEvents: ((map['todayEvents'] as List?) ?? const [])
          .map((e) => ScreenEventItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      onAtDayStart: map['onAtDayStart'] == true,
      now: _date(map['now']) ?? DateTime.now(),
    );
  }
}

class ScreenEventItem {
  final bool on;
  final DateTime at;
  final Duration? gap;

  const ScreenEventItem({required this.on, required this.at, this.gap});

  factory ScreenEventItem.fromMap(Map<String, dynamic> map) {
    return ScreenEventItem(
      on: _int(map['type']) == 1,
      at: _date(map['ts']) ?? DateTime.now(),
      gap: _duration(map['gapMs']),
    );
  }
}

class AppUsage {
  final String packageName;
  final String label;
  final Duration duration;
  final Uint8List? icon;

  const AppUsage({
    required this.packageName,
    required this.label,
    required this.duration,
    required this.icon,
  });

  factory AppUsage.fromMap(Map<String, dynamic> map) {
    Uint8List? icon;
    final rawIcon = map['icon'];
    if (rawIcon is String && rawIcon.isNotEmpty) {
      try {
        icon = base64Decode(rawIcon);
      } catch (_) {
        icon = null;
      }
    }
    return AppUsage(
      packageName: map['package'] as String? ?? '',
      label: map['label'] as String? ?? '',
      duration: Duration(milliseconds: _int(map['ms'])),
      icon: icon,
    );
  }
}

class PermissionStatus {
  final bool usage;
  final bool notification;
  final bool battery;
  final int sdk;

  const PermissionStatus({
    required this.usage,
    required this.notification,
    required this.battery,
    required this.sdk,
  });

  factory PermissionStatus.fromMap(Map<String, dynamic> map) {
    return PermissionStatus(
      usage: map['usage'] == true,
      notification: map['notification'] == true,
      battery: map['battery'] == true,
      sdk: _int(map['sdk']),
    );
  }
}

DateTime? _date(dynamic value) {
  final ms = _intOrNull(value);
  if (ms == null || ms <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

Duration? _duration(dynamic value) {
  final ms = _intOrNull(value);
  if (ms == null || ms <= 0) return null;
  return Duration(milliseconds: ms);
}

int _int(dynamic value) => _intOrNull(value) ?? 0;

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
