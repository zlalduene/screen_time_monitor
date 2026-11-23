import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/monitor_api.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  MonitorSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MonitorApi.startMonitor();
    _load(showSpinner: true);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MonitorApi.startMonitor();
      _load(showSpinner: false);
      _startTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 后台不再轮询，省电
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted && _snapshot == null) {
      setState(() => _loading = true);
    }
    try {
      final snapshot = await MonitorApi.snapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: palette.bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            color: palette.accent,
            backgroundColor: palette.surface,
            onRefresh: () => _load(showSpinner: false),
            child: _buildBody(palette),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette palette) {
    if (_loading && _snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.4),
          Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
          ),
        ],
      );
    }

    if (_snapshot == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          Text(
            '读取数据失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_error ?? '未知错误'}',
            style: TextStyle(fontSize: 13, color: palette.inkMuted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _load(),
            child: const Text('重试'),
          ),
        ],
      );
    }

    final data = _snapshot!;
    final overview = data.overview;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        _buildHeader(palette, data),
        const SizedBox(height: 22),
        _buildHeroCard(palette, overview),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: '今日亮屏次数',
                value: '${overview.todayOnCount}',
                unit: '次',
                palette: palette,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: '今日累计亮屏',
                value: _formatDuration(overview.todayOn),
                palette: palette,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildSectionTitle(palette, '应用使用时长', '今天'),
        const SizedBox(height: 12),
        if (!data.permissions.usage)
          _buildUsagePermissionCard(palette)
        else if (data.apps.isEmpty)
          _buildEmptyCard(palette, '今天还没有应用使用记录')
        else
          _buildAppList(palette, data.apps),
        const SizedBox(height: 28),
        _buildSectionTitle(palette, '亮屏 / 息屏记录', '最近'),
        const SizedBox(height: 12),
        _buildEventCard(palette, data.recent),
        const SizedBox(height: 28),
        _buildSectionTitle(palette, '监控状态', '权限'),
        const SizedBox(height: 12),
        _buildPermissionCard(palette, data.permissions),
        const SizedBox(height: 12),
        _buildRecentsCard(palette, data.hideFromRecents),
        const SizedBox(height: 12),
        _buildKeepAliveTips(palette),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '数据仅保存在本机，不会上传到任何服务器',
            style: TextStyle(fontSize: 11, color: palette.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppPalette palette, MonitorSnapshot data) {
    final running = data.permissions.usage;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCREEN TIME',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(DateTime.now()),
                style: TextStyle(
                  fontSize: 25,
                  height: 1.1,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: running ? palette.accentSoft : palette.surfaceAlt,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: running ? palette.accent : palette.warm,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  running ? '记录中' : '待授权',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: running ? palette.accent : palette.warm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(AppPalette palette, Overview overview) {
    final screenOn = overview.screenOn;
    final Duration? primary = screenOn
        ? overview.session
        : (overview.lastOffAt == null
            ? null
            : overview.now.difference(overview.lastOffAt!));
    final label = screenOn ? '本次亮屏' : '已息屏';

    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: screenOn ? palette.accent : palette.inkMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                screenOn ? '屏幕亮起' : '屏幕熄灭',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const Spacer(),
              Text(
                screenOn ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.inkMuted),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              primary == null ? '—' : _formatDuration(primary),
              style: TextStyle(
                fontSize: 36,
                height: 1.05,
                letterSpacing: -1.0,
                fontWeight: FontWeight.w600,
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '开屏距上次息屏',
                style: TextStyle(fontSize: 12, color: palette.inkMuted),
              ),
              const Spacer(),
              Text(
                overview.sinceLastOff == null
                    ? '—'
                    : _formatDuration(overview.sinceLastOff!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: overview.sinceLastOff == null
                      ? palette.inkMuted
                      : palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DayTimeline(overview: overview, palette: palette),
        ],
      ),
    );
  }

  Widget _buildAppList(AppPalette palette, List<AppUsage> apps) {
    final maxMs = apps.first.duration.inMilliseconds;
    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        children: [
          for (var i = 0; i < apps.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  _AppIcon(app: apps[i], palette: palette),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apps[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Container(
                                height: 4,
                                color: palette.surfaceAlt,
                              ),
                              FractionallySizedBox(
                                widthFactor: maxMs <= 0
                                    ? 0
                                    : (apps[i]
                                            .duration
                                            .inMilliseconds /
                                        maxMs)
                                        .clamp(0.02, 1.0)
                                        .toDouble(),
                                child: Container(
                                  height: 4,
                                  color: palette.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _formatDuration(apps[i].duration),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(AppPalette palette, List<ScreenEventItem> events) {
    if (events.isEmpty) {
      return _buildEmptyCard(palette, '暂无亮屏 / 息屏记录');
    }
    final items = events.take(9).toList();
    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    _formatTime(items[i].at),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: items[i].on ? palette.accent : palette.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    items[i].on ? '亮屏' : '息屏',
                    style: TextStyle(fontSize: 12.5, color: palette.inkMuted),
                  ),
                  const Spacer(),
                  if (items[i].on && items[i].gap != null)
                    Text(
                      '间隔 ${_formatDuration(items[i].gap!)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsagePermissionCard(AppPalette palette) {
    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '需要“使用情况访问”权限',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '授权后才能统计每个应用的使用时长。亮屏 / 息屏记录不受影响。',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF10130F)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await MonitorApi.openUsageAccess();
              },
              child: const Text('去开启权限', style: TextStyle(fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(AppPalette palette, PermissionStatus status) {
    return _card(
      palette,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          _PermissionRow(
            palette: palette,
            title: '使用情况访问',
            subtitle: '读取应用使用时长',
            enabled: status.usage,
            onTap: () => MonitorApi.openUsageAccess(),
          ),
          Divider(height: 1, color: palette.line),
          _PermissionRow(
            palette: palette,
            title: '通知权限',
            subtitle: '保持后台记录服务运行',
            enabled: status.notification,
            onTap: () => MonitorApi.openNotificationSettings(),
          ),
          Divider(height: 1, color: palette.line),
          _PermissionRow(
            palette: palette,
            title: '电池优化白名单',
            subtitle: '避免系统清理后台进程',
            enabled: status.battery,
            onTap: () async {
              if (status.battery) {
                await MonitorApi.openBatterySettings();
              } else {
                await MonitorApi.requestIgnoreBattery();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentsCard(AppPalette palette, bool hidden) {
    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '从最近任务中隐藏',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hidden
                      ? '最近任务里看不到本应用，不会手滑划掉；从通知栏或桌面图标进入'
                      : '最近任务里可以看到本应用，划掉后靠保活自动恢复',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: hidden,
            onChanged: (value) async {
              await MonitorApi.setHideFromRecents(value);
              if (mounted) _load(showSpinner: false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKeepAliveTips(AppPalette palette) {
    const tips = [
      '开启「从最近任务中隐藏」后，划最近任务不会影响记录',
      '系统设置里允许「自启动」「后台弹出界面」',
      '电池策略设为「无限制」，关闭省电模式',
    ];
    return _card(
      palette,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '让后台记录更稳定',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < tips.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tips[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(AppPalette palette, String text) {
    return _card(
      palette,
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: palette.inkMuted),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(AppPalette palette, String title, String trailing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: palette.ink,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(fontSize: 11, color: palette.inkMuted),
        ),
      ],
    );
  }

  Widget _card(
    AppPalette palette, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final AppPalette palette;

  const _StatTile({
    required this.label,
    required this.value,
    required this.palette,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: palette.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final AppUsage app;
  final AppPalette palette;

  const _AppIcon({required this.app, required this.palette});

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.memory(
          icon,
          width: 38,
          height: 38,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        app.label.isEmpty ? '?' : app.label.substring(0, 1),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.inkMuted,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final AppPalette palette;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _PermissionRow({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? palette.accent : palette.warm,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
            Text(
              enabled ? '已开启' : '未开启',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: enabled ? palette.accent : palette.warm,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: palette.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  final Overview overview;
  final AppPalette palette;

  const _DayTimeline({required this.overview, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 16,
          width: double.infinity,
          child: CustomPaint(
            painter: _TimelinePainter(
              events: overview.todayEvents,
              onAtDayStart: overview.onAtDayStart,
              now: overview.now,
              palette: palette,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in const ['00', '06', '12', '18', '24'])
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.4,
                  color: palette.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<ScreenEventItem> events;
  final bool onAtDayStart;
  final DateTime now;
  final AppPalette palette;

  _TimelinePainter({
    required this.events,
    required this.onAtDayStart,
    required this.now,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(track, Paint()..color = palette.surfaceAlt);

    final dayStart = DateTime(now.year, now.month, now.day);
    final dayMs = Duration.millisecondsPerDay;

    double x(DateTime time) {
      final ratio =
          time.difference(dayStart).inMilliseconds / dayMs;
      return ratio.clamp(0.0, 1.0).toDouble() * size.width;
    }

    final segments = <List<DateTime>>[];
    DateTime? openAt = onAtDayStart ? dayStart : null;
    for (final event in events) {
      if (event.on) {
        openAt = event.at;
      } else if (openAt != null) {
        segments.add([openAt, event.at]);
        openAt = null;
      }
    }
    if (openAt != null) {
      segments.add([openAt, now]);
    }

    canvas.save();
    canvas.clipRRect(track);
    final segmentPaint = Paint()..color = palette.accent;
    for (final segment in segments) {
      final left = x(segment[0]);
      final right = x(segment[1]);
      if (right - left < 1.5) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, right, size.height),
          const Radius.circular(3),
        ),
        segmentPaint,
      );
    }
    canvas.restore();

    final nowX = x(now);
    canvas.drawLine(
      Offset(nowX, -2),
      Offset(nowX, size.height + 2),
      Paint()
        ..color = palette.ink.withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.events != events ||
        oldDelegate.onAtDayStart != onAtDayStart ||
        oldDelegate.palette != palette;
  }
}

String _formatDate(DateTime time) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${time.month}月${time.day}日 · 周${weekdays[time.weekday - 1]}';
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds;
  if (total < 60) return '$total 秒';
  if (total < 3600) return '${duration.inMinutes} 分钟';
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分';
}
