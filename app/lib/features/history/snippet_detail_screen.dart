import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/history_entry.dart';
import 'history_providers.dart';

class SnippetDetailScreen extends ConsumerWidget {

  const SnippetDetailScreen({
    super.key,
    required this.entry,
  });
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippet Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
            tooltip: 'Delete Snippet',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Text Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: SelectableText(
                  entry.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions Row
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _insertAtCursor(context),
                    icon: const Icon(Icons.input, size: 18),
                    label: const Text('Insert at Cursor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Text'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Metadata Section
              Text(
                'Metadata',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTile(
                icon: Icons.apps,
                label: 'Source Application',
                value: entry.sourceApp,
              ),
              _buildMetadataTile(
                icon: Icons.access_time,
                label: 'Captured At',
                value: _formatTimestamp(entry.capturedAt),
              ),
              _buildMetadataTile(
                icon: Icons.language,
                label: 'Language',
                value: entry.language ?? 'en (Auto)',
              ),
              _buildMetadataTile(
                icon: Icons.devices,
                label: 'Device Source',
                value: entry.deviceId ?? 'Local Device',
              ),
              _buildMetadataTile(
                icon: Icons.translate,
                label: 'Translation Status',
                value: entry.wasTranslated ? 'Translated' : 'Original Text',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataTile({
    required IconData icon,
    required String label,
    required String value,
  }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

  void _insertAtCursor(BuildContext context) {
    Clipboard.setData(ClipboardData(text: entry.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied & ready to insert at cursor!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: entry.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Snippet?'),
        content: const Text('This action is permanent and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(historyNotifierProvider.notifier).deleteEntry(entry.id);
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
