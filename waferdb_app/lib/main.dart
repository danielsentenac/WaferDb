import 'package:flutter/material.dart';

import 'app_config.dart';
import 'api_client.dart';
import 'dialogs.dart';
import 'models.dart';

void main() {
  runApp(const WaferDbApp());
}

class WaferDbApp extends StatelessWidget {
  const WaferDbApp({super.key});

  @override
  Widget build(BuildContext context) {
    const steel = Color(0xFF244549);
    const sand = Color(0xFFF2EDE0);
    const copper = Color(0xFFA55A36);

    return MaterialApp(
      title: 'WaferDb Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: steel,
          secondary: copper,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF182324),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.88),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: steel.withValues(alpha: 0.08)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: sand,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: steel,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const WaferHomePage(apiBase: defaultApiBase),
    );
  }
}

class WaferHomePage extends StatefulWidget {
  const WaferHomePage({super.key, required this.apiBase});

  final String apiBase;

  @override
  State<WaferHomePage> createState() => _WaferHomePageState();
}

class _WaferHomePageState extends State<WaferHomePage> {
  late final ApiClient _apiClient;
  final TextEditingController _searchController = TextEditingController();

  LookupBundle? _lookups;
  DashboardData? _dashboard;
  List<WaferSummary> _wafers = const [];
  WaferDetail? _selectedDetail;
  int? _selectedWaferId;
  String? _statusFilter;
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(widget.apiBase);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final lookups = await _apiClient.fetchLookups();
      final dashboard = await _apiClient.fetchDashboard();
      final wafers = await _apiClient.fetchWafers();
      WaferDetail? detail;
      int? selectedWaferId;
      if (wafers.isNotEmpty) {
        selectedWaferId = wafers.first.waferId;
        detail = await _apiClient.fetchWaferDetail(selectedWaferId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lookups = lookups;
        _dashboard = dashboard;
        _wafers = wafers;
        _selectedWaferId = selectedWaferId;
        _selectedDetail = detail;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _refreshData({bool reloadDetail = true}) async {
    setState(() {
      _busy = true;
    });
    try {
      final dashboard = await _apiClient.fetchDashboard();
      final wafers = await _apiClient.fetchWafers(
        query: _searchController.text.trim(),
        statusCode: _statusFilter,
      );
      WaferDetail? detail = _selectedDetail;
      int? selectedWaferId = _selectedWaferId;
      if (wafers.isEmpty) {
        detail = null;
        selectedWaferId = null;
      } else if (reloadDetail) {
        selectedWaferId =
            wafers.any((wafer) => wafer.waferId == _selectedWaferId)
            ? _selectedWaferId
            : wafers.first.waferId;
        detail = selectedWaferId == null
            ? null
            : await _apiClient.fetchWaferDetail(selectedWaferId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = dashboard;
        _wafers = wafers;
        _selectedWaferId = selectedWaferId;
        _selectedDetail = detail;
      });
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _selectWafer(int waferId) async {
    setState(() {
      _busy = true;
      _selectedWaferId = waferId;
    });
    try {
      final detail = await _apiClient.fetchWaferDetail(waferId);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDetail = detail;
      });
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _createWafer() async {
    final lookups = _lookups;
    if (lookups == null) {
      return;
    }
    final values = await showCreateWaferDialog(context, lookups);
    if (values == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final detail = await _apiClient.createWafer(values);
      if (!mounted) {
        return;
      }
      _showSnack('Wafer ${detail.wafer.name} created.');
      setState(() {
        _selectedWaferId = detail.wafer.waferId;
        _selectedDetail = detail;
      });
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _appendStatus() async {
    final lookups = _lookups;
    final detail = _selectedDetail;
    if (lookups == null || detail == null) {
      return;
    }
    final values = await showStatusDialog(context, lookups);
    if (values == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.addStatus(
        detail.wafer.waferId,
        values,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Status appended for ${refreshed.wafer.name}.');
      setState(() {
        _selectedDetail = refreshed;
      });
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _appendActivity() async {
    final lookups = _lookups;
    final detail = _selectedDetail;
    if (lookups == null || detail == null) {
      return;
    }
    final values = await showActivityDialog(context, lookups);
    if (values == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.addActivity(
        detail.wafer.waferId,
        values,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Activity appended for ${refreshed.wafer.name}.');
      setState(() {
        _selectedDetail = refreshed;
      });
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _appendDarkfieldRun() async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    final values = await showDarkfieldRunDialog(
      context,
      detail,
      darkfieldRoot: defaultDarkfieldRoot,
    );
    if (values == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.addDarkfieldRun(
        detail.wafer.waferId,
        values,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Darkfield run appended for ${refreshed.wafer.name}.');
      setState(() {
        _selectedDetail = refreshed;
      });
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? const Color(0xFF852020)
            : const Color(0xFF244549),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8F5EF), Color(0xFFE1ECE8), Color(0xFFD5E5EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _ErrorView(
                  apiBase: widget.apiBase,
                  message: _errorMessage!,
                  onRetry: _loadInitial,
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _Header(
                        apiBase: widget.apiBase,
                        busy: _busy,
                        onRefresh: _refreshData,
                        onCreateWafer: _createWafer,
                      ),
                      const SizedBox(height: 18),
                      if (_dashboard != null) ...[
                        _SummaryStrip(dashboard: _dashboard!),
                        const SizedBox(height: 18),
                      ],
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 1180;
                            if (narrow) {
                              return ListView(
                                children: [
                                  _buildLeftPane(),
                                  const SizedBox(height: 18),
                                  _buildDetailPane(),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 360, child: _buildLeftPane()),
                                const SizedBox(width: 18),
                                Expanded(child: _buildDetailPane()),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLeftPane() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wafer inventory',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Search the current register, filter by status, and open a wafer to inspect the full timeline.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _refreshData(),
              decoration: InputDecoration(
                labelText: 'Search name or invoice',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _refreshData,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status filter'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ...?_lookups?.statuses.map(
                  (status) => DropdownMenuItem<String>(
                    value: status.code,
                    child: Text(status.label),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _wafers.isEmpty
                  ? const Center(
                      child: Text('No wafers match the current query.'),
                    )
                  : ListView.separated(
                      itemCount: _wafers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final wafer = _wafers[index];
                        final selected = wafer.waferId == _selectedWaferId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _selectWafer(wafer.waferId),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF244549)
                                  : const Color(0xFFF3EEE2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wafer.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: selected ? Colors.white : null,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${wafer.waferType}  •  ${wafer.acquiredDate}',
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white70
                                          : const Color(0xFF556869),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label:
                                            wafer.statusLabel ?? 'Unassigned',
                                        selected: selected,
                                      ),
                                      if (wafer.waferSizeIn != null)
                                        _MiniPill(
                                          label: '${wafer.waferSizeIn} in',
                                          selected: selected,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPane() {
    final detail = _selectedDetail;
    if (detail == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Select a wafer to inspect it.'),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Card(
        key: ValueKey<int>(detail.wafer.waferId),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: ListView(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.wafer.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusPill(
                              label: detail.wafer.statusLabel ?? 'Unassigned',
                            ),
                            _MiniPill(label: detail.wafer.waferType),
                            if (detail.wafer.waferSizeIn != null)
                              _MiniPill(
                                label: '${detail.wafer.waferSizeIn} in',
                              ),
                            if (detail.wafer.referenceInvoice != null)
                              _MiniPill(label: detail.wafer.referenceInvoice!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _appendStatus,
                        icon: const Icon(Icons.timeline),
                        label: const Text('Add status'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _appendActivity,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add activity'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: _appendDarkfieldRun,
                        icon: const Icon(Icons.biotech_outlined),
                        label: const Text('Add darkfield'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _MetaCard(
                    label: 'Acquired',
                    value: detail.wafer.acquiredDate,
                  ),
                  _MetaCard(
                    label: 'Roughness',
                    value: detail.wafer.roughnessNm == null
                        ? 'n/a'
                        : '${detail.wafer.roughnessNm} nm',
                  ),
                  _MetaCard(
                    label: 'Size label',
                    value: detail.wafer.waferSizeLabel ?? 'n/a',
                  ),
                ],
              ),
              if ((detail.wafer.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionPanel(title: 'Notes', child: Text(detail.wafer.notes!)),
              ],
              const SizedBox(height: 18),
              _SectionPanel(
                title: 'Status history',
                child: detail.statusHistory.isEmpty
                    ? const Text('No status changes recorded yet.')
                    : Column(
                        children: detail.statusHistory
                            .map(
                              (entry) => _TimelineTile(
                                title: entry.statusLabel,
                                subtitle:
                                    '${entry.effectiveAt}${entry.clearedAt == null ? '' : '  →  ${entry.clearedAt}'}',
                                caption: entry.notes ?? entry.statusCode,
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: 18),
              _SectionPanel(
                title: 'Activities',
                child: detail.activities.isEmpty
                    ? const Text('No activities recorded yet.')
                    : Column(
                        children: detail.activities
                            .map(
                              (activity) => _TimelineTile(
                                title:
                                    '${activity.purposeLabel} at ${activity.locationCode}',
                                subtitle:
                                    '${activity.exposureQuantity} ${activity.exposureUnit}',
                                caption: [
                                  if (activity.startedAt != null)
                                    activity.startedAt,
                                  if (activity.endedAt != null)
                                    activity.endedAt,
                                  if (activity.observations != null)
                                    activity.observations,
                                ].whereType<String>().join('  •  '),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: 18),
              _SectionPanel(
                title: 'Darkfield runs',
                child: detail.darkfieldRuns.isEmpty
                    ? const Text('No darkfield runs linked to this wafer yet.')
                    : Column(
                        children: detail.darkfieldRuns
                            .map((run) => _DarkfieldRunCard(run: run))
                            .toList(growable: false),
                      ),
              ),
              if ((_dashboard?.recentActivities ?? const []).isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionPanel(
                  title: 'Recent facility activity',
                  child: Column(
                    children: _dashboard!.recentActivities
                        .map(
                          (entry) => _TimelineTile(
                            title:
                                '${entry.waferName}  •  ${entry.purposeLabel}',
                            subtitle:
                                '${entry.exposureQuantity} ${entry.exposureUnit} at ${entry.locationName}',
                            caption:
                                entry.endedAt ??
                                entry.startedAt ??
                                entry.createdAt ??
                                '',
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.apiBase,
    required this.busy,
    required this.onRefresh,
    required this.onCreateWafer,
  });

  final String apiBase;
  final bool busy;
  final Future<void> Function({bool reloadDetail}) onRefresh;
  final Future<void> Function() onCreateWafer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WaferDb Console',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operational client for $apiBase',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF526667),
                    ),
                  ),
                ],
              ),
            ),
            if (busy) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 14),
            ],
            OutlinedButton.icon(
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onCreateWafer,
              icon: const Icon(Icons.add),
              label: const Text('New wafer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.dashboard});

  final DashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Tracked wafers',
            value: dashboard.waferCount.toString(),
            accent: const Color(0xFF244549),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Recorded activities',
            value: dashboard.activityCount.toString(),
            accent: const Color(0xFF3C6E71),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Darkfield runs',
            value: dashboard.darkfieldRunCount.toString(),
            accent: const Color(0xFFA55A36),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 8,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: const Color(0xFF6B797A),
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DarkfieldRunCard extends StatelessWidget {
  const _DarkfieldRunCard({required this.run});

  final DarkfieldRunEntry run;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${run.runType} run',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (run.activityId != null)
                _MiniPill(label: 'Activity #${run.activityId}'),
            ],
          ),
          const SizedBox(height: 6),
          Text(run.measuredAt),
          const SizedBox(height: 4),
          Text(
            run.dataPath,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF556869)),
          ),
          if ((run.summaryNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(run.summaryNotes!),
          ],
          if (run.binSummaries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Bin summaries',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...run.binSummaries.map(
              (bin) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bin.binLabel ?? 'Bin ${bin.binOrder}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniPill(label: '${bin.particleCount} particles'),
                        if (_binSizeRange(bin) != null)
                          _MiniPill(label: _binSizeRange(bin)!),
                        if (bin.totalAreaUm2 != null)
                          _MiniPill(label: '${bin.totalAreaUm2} um2'),
                        if (bin.particleDensityCm2 != null)
                          _MiniPill(label: '${bin.particleDensityCm2} cm2'),
                      ],
                    ),
                    if ((bin.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bin.notes!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.caption,
  });

  final String title;
  final String subtitle;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFA55A36),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(caption, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFF244549),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE5EBE6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white70 : const Color(0xFF244549),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String? _binSizeRange(DarkfieldBinSummaryEntry bin) {
  if (bin.minSizeUm == null && bin.maxSizeUm == null) {
    return null;
  }
  if (bin.minSizeUm != null && bin.maxSizeUm != null) {
    return '${bin.minSizeUm}-${bin.maxSizeUm} um';
  }
  if (bin.minSizeUm != null) {
    return '>= ${bin.minSizeUm} um';
  }
  return '<= ${bin.maxSizeUm} um';
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.apiBase,
    required this.message,
    required this.onRetry,
  });

  final String apiBase;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: SizedBox(
          width: 640,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend connection failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text('API endpoint: $apiBase'),
                const SizedBox(height: 10),
                Text(message),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
