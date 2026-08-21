import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import 'look_activity_models.dart';
import 'look_monitor_service.dart';

class LookMonitorScreen extends StatefulWidget {
  const LookMonitorScreen({super.key, required this.service});

  final LookMonitorService service;

  @override
  State<LookMonitorScreen> createState() => _LookMonitorScreenState();
}

class _LookMonitorScreenState extends State<LookMonitorScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.service.status;
    final consent = widget.service.consentState;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.remove_red_eye_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Look System Application',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [_buildStatusBadge(status), const SizedBox(width: 16)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Transparency & Privacy Notice Banner
            _buildPrivacyBanner(consent),

            const SizedBox(height: 16),

            // 2. Active Application & Live Control Card
            _buildLiveStatusCard(status),

            const SizedBox(height: 16),

            // 3. Quick Action Controls
            _buildControlBar(status),

            const SizedBox(height: 24),

            // 4. Recent Activity Stream
            Text(
              'Recent Activity Logs (Privacy-Sanitized)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(LookMonitoringStatus status) {
    Color bg;
    Color dot;
    String text;

    switch (status) {
      case LookMonitoringStatus.active:
        bg = const Color(0x2E00D4AA);
        dot = AppColors.secondary;
        text = 'Monitoring Active';
        break;
      case LookMonitoringStatus.paused:
        bg = const Color(0x2EFF9A3C);
        dot = AppColors.accentOrange;
        text = 'Paused';
        break;
      case LookMonitoringStatus.stopped:
        bg = const Color(0x2E737373);
        dot = Colors.grey;
        text = 'Stopped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: dot,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner(LookConsentState consent) {
    final isGranted = consent == LookConsentState.granted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.secondary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transparent Workplace Monitoring',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isGranted
                      ? 'Capturing active window metadata & idle intervals only. No keystrokes, passwords, or communications are recorded.'
                      : 'Monitoring is suspended because consent has not been provided.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isGranted,
            activeThumbColor: AppColors.secondary,
            onChanged: (val) {
              widget.service.setConsent(
                val ? LookConsentState.granted : LookConsentState.revoked,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(LookMonitoringStatus status) {
    final isRunning = status == LookMonitoringStatus.active;

    return KeyFlowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Foreground App',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                Text(
                  widget.service.isCurrentlyIdle
                      ? 'Status: IDLE'
                      : 'Status: ACTIVE',
                  style: TextStyle(
                    color: widget.service.isCurrentlyIdle
                        ? AppColors.accentOrange
                        : AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isRunning
                  ? widget.service.currentApp
                  : 'Monitoring Paused / Suspended',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isRunning
                  ? 'Window: ${widget.service.currentWindowTitle}'
                  : 'No telemetry is currently recorded.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(LookMonitoringStatus status) {
    final isActive = status == LookMonitoringStatus.active;

    return Row(
      children: [
        if (isActive) ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.pause, size: 18),
              label: const Text('Pause 15m'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.elevatedSurface,
              ),
              onPressed: () =>
                  widget.service.pauseMonitoring(const Duration(minutes: 15)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              label: const Text('Pause 1 Hour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.elevatedSurface,
              ),
              onPressed: () =>
                  widget.service.pauseMonitoring(const Duration(hours: 1)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Stop'),
            onPressed: () => widget.service.stopMonitoring(),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume Monitoring'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => widget.service.resumeMonitoring(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityList() {
    final logs = widget.service.activityLogs;

    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'No activity intervals recorded yet.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (ctx, idx) {
        final item = logs[idx];
        return Card(
          color: AppColors.cardSurface,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySubtle,
              child: Text(
                item.appName.isNotEmpty ? item.appName[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              item.appName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.appCategory} • ${item.durationSeconds}s duration (${item.idleSeconds}s idle)\n${item.windowTitle}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            trailing: Text(
              '${item.startedAt.hour.toString().padLeft(2, '0')}:${item.startedAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
