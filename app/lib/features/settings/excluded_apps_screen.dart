import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import 'settings_providers.dart';

class ExcludedAppsScreen extends ConsumerStatefulWidget {
  const ExcludedAppsScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ExcludedAppsScreen()));

  @override
  ConsumerState<ExcludedAppsScreen> createState() => _ExcludedAppsScreenState();
}

class _ExcludedAppsScreenState extends ConsumerState<ExcludedAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  int _tabIndex = 0; // 0 = All, 1 = Excluded Only, 2 = Banking & Pay

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installedAppsAsync = ref.watch(installedAppsProvider);
    final exclusionAsync = ref.watch(exclusionListProvider);

    final exclusions = exclusionAsync.value ?? [];
    final exclusionSet = exclusions.toSet();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Excluded Applications'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGhost,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${exclusions.length} Excluded',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: installedAppsAsync.when(
        data: (apps) {
          final filteredApps = apps.where((app) {
            // Text search
            if (_filter.isNotEmpty) {
              final query = _filter.toLowerCase();
              final matchesName = app.appName.toLowerCase().contains(query);
              final matchesPkg = app.packageName.toLowerCase().contains(query);
              if (!matchesName && !matchesPkg) return false;
            }

            // Tab filter
            if (_tabIndex == 1) {
              return exclusionSet.contains(app.packageName);
            } else if (_tabIndex == 2) {
              return app.isBankingApp;
            }
            return true;
          }).toList();

          final bankingCount = apps.where((a) => a.isBankingApp).length;

          return Column(
            children: [
              // Search & Filter Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: AppColors.cardSurface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _filter = val),
                      decoration: InputDecoration(
                        hintText: 'Search apps by name or package...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filter = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All (${apps.length})', 0),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Excluded (${exclusions.length})',
                            1,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip('Banking & Pay ($bankingCount)', 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),

              // Helper message
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Turn switch ON to block keystroke capture in that application.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // App List
              Expanded(
                child: filteredApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 48,
                              color: AppColors.textDisabled,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter.isNotEmpty
                                  ? 'No installed apps matching "$_filter"'
                                  : 'No apps found in this category',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredApps.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isExcluded = exclusionSet.contains(
                            app.packageName,
                          );

                          return KeyFlowCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _buildAppIcon(app.appIcon),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              app.appName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (app.isBankingApp) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentOrange
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Banking',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.accentOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        app.packageName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isExcluded,
                                  onChanged: (val) {
                                    ref
                                        .read(settingsControllerProvider)
                                        .toggleAppExclusion(app.packageName);
                                  },
                                  activeThumbColor: AppColors.accentOrange,
                                  activeTrackColor: AppColors.accentOrange
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Scanning installed apps...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        error: (err, _) =>
            Center(child: Text('Error loading installed apps: $err')),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _tabIndex == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _tabIndex = index),
      backgroundColor: AppColors.cardSurface,
      selectedColor: AppColors.primaryGhost,
      side: BorderSide(
        color: isSelected ? AppColors.primaryLight : AppColors.cardBorder,
      ),
    );
  }

  Widget _buildAppIcon(Uint8List? iconBytes) {
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          iconBytes,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackIcon(),
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: AppColors.cardBorder,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.android, size: 22, color: AppColors.textMuted),
  );
}
