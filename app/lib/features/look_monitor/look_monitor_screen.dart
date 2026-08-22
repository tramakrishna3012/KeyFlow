import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'look_activity_models.dart';
import 'look_monitor_service.dart';

final lookMonitorServiceProvider = ChangeNotifierProvider<LookMonitorService>(
  (ref) => LookMonitorService()..startSession(),
);

class LookMonitorScreen extends ConsumerStatefulWidget {
  const LookMonitorScreen({super.key});

  @override
  ConsumerState<LookMonitorScreen> createState() => _LookMonitorScreenState();
}

class _LookMonitorScreenState extends ConsumerState<LookMonitorScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final monitor = ref.watch(lookMonitorServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final session = monitor.currentSession;
    final apps = session?.applications ?? [];
    final filteredApps = apps.where((app) {
      final matchesCat =
          _selectedCategory == 'All' || app.category == _selectedCategory;
      final matchesQuery =
          _searchQuery.isEmpty ||
          app.appName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.remove_red_eye_outlined, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(
              'Look System Monitor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Privacy Exclusions',
            onPressed: () => _showPrivacyModal(context, monitor),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Offline Queue (${monitor.offlineQueue.length})',
            onPressed: () async {
              final count = await monitor.flushOfflineQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synced $count items successfully.')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionControlCard(context, monitor),
            const SizedBox(height: 16),
            _buildMetricsRow(context, monitor),
            const SizedBox(height: 16),
            _buildFilterBar(context),
            const SizedBox(height: 16),
            Text(
              'Session Application Hierarchy',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (filteredApps.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No activity records captured in this session yet.',
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredApps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  return _buildApplicationCard(context, app);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControlCard(
    BuildContext context,
    LookMonitorService monitor,
  ) {
    final status = monitor.status;
    final isActive = status == LookMonitoringStatus.active;
    final isPaused = status == LookMonitoringStatus.paused;

    Color statusColor;
    String statusText;
    switch (status) {
      case LookMonitoringStatus.active:
        statusColor = Colors.greenAccent;
        statusText = 'MONITORING ACTIVE';
        break;
      case LookMonitoringStatus.paused:
        statusColor = Colors.amberAccent;
        statusText = 'SESSION PAUSED';
        break;
      case LookMonitoringStatus.stopped:
      case LookMonitoringStatus.completed:
        statusColor = Colors.redAccent;
        statusText = 'MONITORING STOPPED';
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                if (monitor.offlineQueue.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.cloud_off, size: 16),
                    label: Text(
                      '${monitor.offlineQueue.length} offline queued',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Active App: ${monitor.currentApp}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Window: ${monitor.currentWindowTitle}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (!isActive)
                  FilledButton.icon(
                    onPressed: monitor.startSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Session'),
                  ),
                if (isActive)
                  FilledButton.tonalIcon(
                    onPressed: monitor.pauseSession,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                if (isPaused)
                  FilledButton.icon(
                    onPressed: monitor.resumeSession,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                if (isActive || isPaused)
                  OutlinedButton.icon(
                    onPressed: monitor.stopSession,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Session'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, LookMonitorService monitor) {
    final session = monitor.currentSession;
    final totalSec =
        session?.applications.fold<int>(
          0,
          (sum, a) => sum + a.totalDurationSeconds,
        ) ??
        0;
    final appCount = session?.applications.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Session Duration',
            value: '${(totalSec / 60).toStringAsFixed(1)} min',
            icon: Icons.timer_outlined,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Apps Used',
            value: '$appCount',
            icon: Icons.apps_outlined,
            color: Colors.purpleAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Privacy Status',
            value: 'Protected',
            icon: Icons.lock_outline,
            color: Colors.tealAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    ),
  );

  Widget _buildFilterBar(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search applications & keywords...',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
      const SizedBox(width: 8),
      DropdownButton<String>(
        value: _selectedCategory,
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All Categories')),
          DropdownMenuItem(value: 'Development', child: Text('Development')),
          DropdownMenuItem(value: 'Browsing', child: Text('Browsing')),
          DropdownMenuItem(
            value: 'Communication',
            child: Text('Communication'),
          ),
          DropdownMenuItem(value: 'Productivity', child: Text('Productivity')),
          DropdownMenuItem(value: 'Design', child: Text('Design')),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedCategory = val);
        },
      ),
    ],
  );

  Widget _buildApplicationCard(
    BuildContext context,
    MonitoredApplication app,
  ) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
        child: Text(
          app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
      ),
      title: Text(
        app.appName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${app.category} • ${(app.totalDurationSeconds / 60).toStringAsFixed(1)} min • ${app.activityTimeline.length} events',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity Timeline:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...app.activityTimeline
                  .take(5)
                  .map(
                    (evt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${evt.windowTitle} (${evt.durationSeconds}s)',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (app.textRecords.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Permitted Text Records:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...app.textRecords
                    .take(3)
                    .map(
                      (rec) => Card(
                        color: Colors.black26,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Icon(
                                rec.isExcluded ? Icons.lock : Icons.notes,
                                size: 14,
                                color: rec.isExcluded
                                    ? Colors.redAccent
                                    : Colors.tealAccent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rec.isExcluded
                                      ? '[Excluded by Privacy Filter]'
                                      : rec.sanitizedPreview,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: rec.isExcluded
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  void _showPrivacyModal(BuildContext context, LookMonitorService monitor) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Exclusions'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add applications to exclude from text and window monitoring:',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Application Name (e.g. 1Password, Bitwarden)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: monitor.privacyExclusions
                    .map(
                      (rule) => Chip(
                        label: Text(rule.appName),
                        onDeleted: () =>
                            monitor.removePrivacyExclusion(rule.appName),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                monitor.addPrivacyExclusion(textController.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add & Close'),
          ),
        ],
      ),
    );
  }
}
