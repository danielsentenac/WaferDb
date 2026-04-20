import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'api_client.dart';
import 'darkfield_metrics.dart';
import 'dialogs.dart';
import 'linkified_text.dart';
import 'models.dart';

void main() {
  runApp(const WaferDbApp());
}

// Strip seconds from stored "YYYY-MM-DD HH:MM:SS" timestamps for display.
String _ts(String? s) {
  if (s == null) return '';
  final m = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}').firstMatch(s);
  return m != null ? m.group(0)! : s;
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
  String? _locationFilter;
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
        locationCode: _locationFilter,
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

  Future<void> _createLocation() async {
    final lookups = _lookups;
    if (lookups == null) return;
    final values = await showCreateLocationDialog(context, lookups);
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final refreshedLookups = await _apiClient.createLocation(values);
      if (!mounted) return;
      _showSnack('Location ${values['name']} created.');
      setState(() => _lookups = refreshedLookups);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<void> _appendWaferHistory() async {
    final detail = _selectedDetail;
    if (detail == null) {
      return;
    }
    final values = await showWaferHistoryDialog(context, detail);
    if (values == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.addWaferHistory(
        detail.wafer.waferId,
        values,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Wafer data updated for ${refreshed.wafer.name}.');
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

  Future<bool> _confirmDelete(String description) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete entry'),
            content: Text('Delete $description?\nThis cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF852020),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runDelete(Future<WaferDetail> Function() action) async {
    setState(() => _busy = true);
    try {
      final refreshed = await action();
      if (!mounted) return;
      setState(() => _selectedDetail = refreshed);
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMetadataHistory(
    int waferId,
    WaferMetadataHistoryEntry entry,
  ) async {
    final detail = _selectedDetail;
    if (detail == null) return;
    final values = await showWaferHistoryDialog(
      context,
      detail,
      initialEntry: entry,
    );
    if (values == null) return;
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.updateMetadataHistory(
        waferId,
        entry.waferMetadataHistoryId,
        values,
      );
      if (!mounted) return;
      _showSnack('History entry updated.');
      setState(() {
        _selectedDetail = refreshed;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
      setState(() => _busy = false);
    }
  }

  Future<void> _deleteMetadataHistory(
    int waferId,
    int historyId,
    String label,
  ) async {
    if (!await _confirmDelete('wafer data entry from $label')) return;
    await _runDelete(
      () => _apiClient.deleteMetadataHistory(waferId, historyId),
    );
  }

  Future<void> _deleteStatus(int waferId, StatusHistoryEntry entry) async {
    if (!await _confirmDelete('${entry.statusLabel} (${_ts(entry.effectiveAt)})'))
      return;
    await _runDelete(
      () => _apiClient.deleteStatus(waferId, entry.waferStatusHistoryId),
    );
  }

  Future<void> _deleteActivity(int waferId, ActivityEntry entry) async {
    if (!await _confirmDelete('${entry.purposeLabel} at ${entry.locationCode}'))
      return;
    await _runDelete(
      () => _apiClient.deleteActivity(waferId, entry.activityId),
    );
  }

  Future<void> _deleteDarkfieldRun(int waferId, DarkfieldRunEntry run) async {
    if (!await _confirmDelete('${run.runType} run (${_ts(run.measuredAt)})')) return;
    await _runDelete(
      () => _apiClient.deleteDarkfieldRun(waferId, run.darkfieldRunId),
    );
  }

  Future<void> _runEdit(
    Future<WaferDetail> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      final refreshed = await action();
      if (!mounted) return;
      _showSnack(successMessage);
      setState(() => _selectedDetail = refreshed);
      await _refreshData(reloadDetail: false);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStatus(int waferId, StatusHistoryEntry entry) async {
    final lookups = _lookups;
    if (lookups == null) return;
    final values = await showStatusDialog(
      context,
      lookups,
      initialEntry: entry,
    );
    if (values == null) return;
    await _runEdit(
      () => _apiClient.updateStatus(waferId, entry.waferStatusHistoryId, values),
      'Status updated.',
    );
  }

  Future<void> _editActivity(int waferId, ActivityEntry entry) async {
    final lookups = _lookups;
    if (lookups == null) return;
    final values = await showActivityDialog(
      context,
      lookups,
      initialEntry: entry,
    );
    if (values == null) return;
    await _runEdit(
      () => _apiClient.updateActivity(waferId, entry.activityId, values),
      'Activity updated.',
    );
  }

  Future<void> _editDarkfieldRun(int waferId, DarkfieldRunEntry run) async {
    final detail = _selectedDetail;
    if (detail == null) return;
    final values = await showDarkfieldRunDialog(
      context,
      detail,
      darkfieldRoot: defaultDarkfieldRoot,
      apiClient: _apiClient,
      initialEntry: run,
    );
    if (values == null) return;
    await _runEdit(
      () => _apiClient.updateDarkfieldRun(waferId, run.darkfieldRunId, values),
      'Darkfield run updated.',
    );
  }

  Future<void> _viewHistoryPhoto(
    int waferId,
    WaferMetadataHistoryEntry entry,
  ) async {
    setState(() => _busy = true);
    try {
      final bytes = await _apiClient.fetchHistoryPhoto(
        waferId,
        entry.waferMetadataHistoryId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _PhotoViewDialog(
          title: 'Box/Identity photo',
          subtitle: _ts(entry.changedAt),
          bytes: bytes,
        ),
      );
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachHistoryPhoto(
    int waferId,
    WaferMetadataHistoryEntry entry,
  ) async {
    final photo = await showCapturePhotoDialog(
      context,
      title: 'Box/Identity photo — ${_ts(entry.changedAt)}',
    );
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final refreshed = await _apiClient.uploadHistoryPhoto(
        waferId,
        entry.waferMetadataHistoryId,
        photo.bytes,
        photo.contentType,
      );
      if (!mounted) return;
      _showSnack('Photo attached.');
      setState(() => _selectedDetail = refreshed);
    } on ApiException catch (error) {
      _showSnack(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
      apiClient: _apiClient,
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 1180;
                    final compact = constraints.maxWidth < 760;
                    final pagePadding = compact ? 12.0 : 24.0;

                    if (narrow) {
                      return Padding(
                        padding: EdgeInsets.all(pagePadding),
                        child: ListView(
                          children: [
                            _Header(
                              apiBase: widget.apiBase,
                              busy: _busy,
                              compact: compact,
                              onRefresh: _refreshData,
                              onCreateWafer: _createWafer,
                              onCreateLocation: _createLocation,
                            ),
                            const SizedBox(height: 18),
                            if (_dashboard != null) ...[
                              _SummaryStrip(
                                dashboard: _dashboard!,
                                compact: compact,
                              ),
                              const SizedBox(height: 18),
                            ],
                            _buildLeftPane(compact: compact, embedded: true),
                            const SizedBox(height: 18),
                            _buildDetailPane(compact: compact, embedded: true),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.all(pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            apiBase: widget.apiBase,
                            busy: _busy,
                            compact: compact,
                            onRefresh: _refreshData,
                            onCreateWafer: _createWafer,
                            onCreateLocation: _createLocation,
                          ),
                          const SizedBox(height: 18),
                          if (_dashboard != null) ...[
                            _SummaryStrip(
                              dashboard: _dashboard!,
                              compact: false,
                            ),
                            const SizedBox(height: 18),
                          ],
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 360,
                                  child: _buildLeftPane(
                                    compact: false,
                                    embedded: false,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _buildDetailPane(
                                    compact: false,
                                    embedded: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildLeftPane({required bool compact, required bool embedded}) {
    const inventoryFieldFill = Color(0xFFE4ECE8);
    final listContent = _wafers.isEmpty
        ? const Center(child: Text('No wafers match the current query.'))
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
                          style: Theme.of(context).textTheme.titleMedium
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
                              label: wafer.statusLabel ?? 'Unassigned',
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
          );

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
            const SizedBox(height: 10),
            const Text(
              'Search the current register, filter by status, and open a wafer to inspect the full timeline.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _refreshData(),
              decoration: InputDecoration(
                labelText: 'Search name or invoice',
                filled: true,
                fillColor: inventoryFieldFill,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _refreshData,
                ),
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status filter',
                filled: true,
                fillColor: inventoryFieldFill,
              ),
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
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _locationFilter,
              decoration: const InputDecoration(
                labelText: 'Location filter',
                filled: true,
                fillColor: inventoryFieldFill,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All locations'),
                ),
                ...?_lookups?.locations.map(
                  (loc) => DropdownMenuItem<String>(
                    value: loc.code,
                    child: Text(loc.displayLabel),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _locationFilter = value);
                _refreshData();
              },
            ),
            const SizedBox(height: 20),
            if (embedded)
              SizedBox(height: compact ? 320 : 420, child: listContent)
            else
              Expanded(child: listContent),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPane({required bool compact, required bool embedded}) {
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
          padding: EdgeInsets.all(compact ? 16 : 22),
          child: embedded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildDetailChildren(detail, compact: compact),
                )
              : ListView(
                  children: _buildDetailChildren(detail, compact: compact),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailChildren(
    WaferDetail detail, {
    required bool compact,
  }) {
    return [
      _buildDetailHeader(detail, compact: compact),
      const SizedBox(height: 20),
      compact
          ? Column(
              children: [
                _MetaCard(label: 'Acquired', value: detail.wafer.acquiredDate),
                const SizedBox(height: 12),
                _MetaCard(
                  label: 'Roughness',
                  value: detail.wafer.roughnessNm == null
                      ? 'n/a'
                      : '${detail.wafer.roughnessNm} nm',
                ),
              ],
            )
          : Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetaCard(label: 'Acquired', value: detail.wafer.acquiredDate),
                _MetaCard(
                  label: 'Roughness',
                  value: detail.wafer.roughnessNm == null
                      ? 'n/a'
                      : '${detail.wafer.roughnessNm} nm',
                ),
              ],
            ),
      const SizedBox(height: 18),
      _SectionPanel(
        title: 'Wafer data history',
        child: detail.metadataHistory.isEmpty
            ? const Text('No wafer data updates recorded yet.')
            : Column(
                children: detail.metadataHistory
                    .map(
                      (entry) => _WaferMetadataHistoryCard(
                        entry: entry,
                        onViewPhoto: entry.hasPhoto
                            ? () =>
                                  _viewHistoryPhoto(detail.wafer.waferId, entry)
                            : null,
                        onAttachPhoto: entry.hasPhoto
                            ? null
                            : () => _attachHistoryPhoto(
                                detail.wafer.waferId,
                                entry,
                              ),
                        onEdit: () => _editMetadataHistory(
                          detail.wafer.waferId,
                          entry,
                        ),
                        onDelete: () => _deleteMetadataHistory(
                          detail.wafer.waferId,
                          entry.waferMetadataHistoryId,
                          _ts(entry.changedAt),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
      const SizedBox(height: 18),
      _SectionPanel(
        title: 'Status history',
        child: detail.statusHistory.isEmpty
            ? const Text('No status changes recorded yet.')
            : Column(
                children: detail.statusHistory
                    .map(
                      (entry) => _StatusHistoryCard(
                        entry: entry,
                        onEdit: () => _editStatus(detail.wafer.waferId, entry),
                        onDelete: () =>
                            _deleteStatus(detail.wafer.waferId, entry),
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
                    .asMap()
                    .entries
                    .map(
                      (e) => _TimelineTile(
                        title:
                            '#${e.key + 1}  ${e.value.purposeLabel} at ${e.value.locationCode}',
                        subtitle:
                            '${e.value.exposureQuantity} ${e.value.exposureUnit}',
                        caption: [
                          if (e.value.startedAt != null) _ts(e.value.startedAt),
                          if (e.value.endedAt != null) _ts(e.value.endedAt),
                          if (e.value.observations != null)
                            e.value.observations,
                        ].whereType<String>().join('  •  '),
                        onEdit: () =>
                            _editActivity(detail.wafer.waferId, e.value),
                        onDelete: () =>
                            _deleteActivity(detail.wafer.waferId, e.value),
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
                children: () {
                      final activityIndexById = {
                        for (final (i, a)
                            in detail.activities.indexed)
                          a.activityId: i + 1,
                      };
                      return detail.darkfieldRuns
                          .map(
                            (run) => _DarkfieldRunCard(
                              run: run,
                              activityIndexById: activityIndexById,
                              onEdit: () =>
                                  _editDarkfieldRun(detail.wafer.waferId, run),
                              onDelete: () =>
                                  _deleteDarkfieldRun(
                                    detail.wafer.waferId,
                                    run,
                                  ),
                            ),
                          )
                          .toList(growable: false);
                    }(),
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
                    title: '${entry.waferName}  •  ${entry.purposeLabel}',
                    subtitle:
                        '${entry.exposureQuantity} ${entry.exposureUnit} at ${entry.displayLocationName}',
                    caption:
                        _ts(entry.endedAt ?? entry.startedAt ?? entry.createdAt),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    ];
  }

  Widget _buildDetailHeader(WaferDetail detail, {required bool compact}) {
    final actionButtonWidth = _uniformActionButtonWidth(context);
    final titleBlock = Column(
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
            _StatusPill(label: detail.wafer.statusLabel ?? 'Unassigned'),
            _MiniPill(label: detail.wafer.waferType),
            if (detail.wafer.waferSizeIn != null)
              _MiniPill(label: '${detail.wafer.waferSizeIn} in'),
            if (detail.wafer.referenceInvoice != null)
              _MiniPill(label: detail.wafer.referenceInvoice!),
          ],
        ),
      ],
    );

    final actions = compact
        ? Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendWaferHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Add history'),
                ),
              ),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendStatus,
                  icon: const Icon(Icons.timeline),
                  label: const Text('Add status'),
                ),
              ),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendActivity,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add activity'),
                ),
              ),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendDarkfieldRun,
                  icon: const Icon(Icons.biotech_outlined),
                  label: const Text('Add darkfield'),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendWaferHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Add history'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendStatus,
                  icon: const Icon(Icons.timeline),
                  label: const Text('Add status'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendActivity,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add activity'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: actionButtonWidth,
                child: FilledButton.tonalIcon(
                  onPressed: _appendDarkfieldRun,
                  icon: const Icon(Icons.biotech_outlined),
                  label: const Text('Add darkfield'),
                ),
              ),
            ],
          );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 16), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 18),
        actions,
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.apiBase,
    required this.busy,
    required this.compact,
    required this.onRefresh,
    required this.onCreateWafer,
    required this.onCreateLocation,
  });

  final String apiBase;
  final bool busy;
  final bool compact;
  final Future<void> Function({bool reloadDetail}) onRefresh;
  final Future<void> Function() onCreateWafer;
  final Future<void> Function() onCreateLocation;

  @override
  Widget build(BuildContext context) {
    final actionButtonWidth = _uniformActionButtonWidth(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WaferDb Console',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Operational client for $apiBase',
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526667)),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        SizedBox(
          width: actionButtonWidth,
          child: OutlinedButton.icon(
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        SizedBox(
          width: actionButtonWidth,
          child: OutlinedButton.icon(
            onPressed: onCreateLocation,
            icon: const Icon(Icons.add_location_outlined),
            label: const Text('Add location'),
          ),
        ),
        SizedBox(
          width: actionButtonWidth,
          child: FilledButton.icon(
            onPressed: onCreateWafer,
            icon: const Icon(Icons.add),
            label: const Text('New wafer'),
          ),
        ),
      ],
    );

    final content = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (busy) ...[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ],
              const SizedBox(height: 16),
              actions,
            ],
          )
        : Row(
            children: [
              Expanded(child: titleBlock),
              if (busy) ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
                const SizedBox(width: 14),
              ],
              Flexible(child: actions),
            ],
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: content,
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.dashboard, required this.compact});

  final DashboardData dashboard;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Tracked wafers',
        value: dashboard.waferCount.toString(),
        accent: const Color(0xFF244549),
      ),
      _MetricCard(
        label: 'Recorded activities',
        value: dashboard.activityCount.toString(),
        accent: const Color(0xFF3C6E71),
      ),
      _MetricCard(
        label: 'Darkfield runs',
        value: dashboard.darkfieldRunCount.toString(),
        accent: const Color(0xFFA55A36),
      ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }
}

double _uniformActionButtonWidth(BuildContext context) {
  const labels = [
    'Refresh',
    'Add location',
    'New wafer',
    'Add history',
    'Add status',
    'Add activity',
    'Add darkfield',
  ];

  final baseStyle =
      Theme.of(context).filledButtonTheme.style?.textStyle?.resolve({}) ??
      Theme.of(context).textTheme.labelLarge ??
      const TextStyle(fontSize: 14);
  final textScaler = MediaQuery.textScalerOf(context);

  double widestLabel = 0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    widestLabel = math.max(widestLabel, painter.width);
  }

  return widestLabel + 86;
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
  const _DarkfieldRunCard({
    required this.run,
    required this.activityIndexById,
    this.onEdit,
    this.onDelete,
  });

  final DarkfieldRunEntry run;
  final Map<int, int> activityIndexById;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
              if (run.activityId != null &&
                  activityIndexById.containsKey(run.activityId))
                _MiniPill(
                  label:
                      'Activity #${activityIndexById[run.activityId]}',
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit run',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete run',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: const Color(0xFF852020),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_ts(run.measuredAt)),
          const SizedBox(height: 4),
          Text(
            run.dataPath,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF556869)),
          ),
          if ((run.summaryNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            LinkifiedText(run.summaryNotes!),
          ],
          if (run.binSummaries.isNotEmpty) _RunCumulativePacSummary(run: run),
          if (run.binSummaries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Bin summaries',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final scannedAreaUm2 = computeDarkfieldScannedAreaUm2(
                  run.binSummaries,
                  summaryNotes: run.summaryNotes,
                );

                return Column(
                  children: List.generate(run.binSummaries.length, (index) {
                    final bin = run.binSummaries[index];

                    // Per-bin PAC % for this bin only.
                    final binPacPct = computeDarkfieldBinPacPercent(
                      bin,
                      scannedAreaUm2,
                    );

                    return Container(
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MiniPill(
                                label: '${bin.particleCount} particles',
                              ),
                              if (binPacPct != null)
                                _PacPill(label: 'PAC', value: binPacPct),
                            ],
                          ),
                          if ((bin.notes ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            LinkifiedText(
                              bin.notes!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _WaferMetadataHistoryCard extends StatelessWidget {
  const _WaferMetadataHistoryCard({
    required this.entry,
    this.onViewPhoto,
    this.onAttachPhoto,
    this.onEdit,
    this.onDelete,
  });

  final WaferMetadataHistoryEntry entry;
  final VoidCallback? onViewPhoto;
  final VoidCallback? onAttachPhoto;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                  _ts(entry.changedAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onViewPhoto != null)
                IconButton(
                  tooltip: 'View box/identity photo',
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: onViewPhoto,
                )
              else if (onAttachPhoto != null)
                IconButton(
                  tooltip: 'Attach box/identity photo',
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: onAttachPhoto,
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit entry',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: const Color(0xFF852020),
                  onPressed: onDelete,
                ),
            ],
          ),
          if ((entry.changeSummary ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            LinkifiedText(entry.changeSummary!),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(label: entry.name),
              _MiniPill(label: 'Acquired ${entry.acquiredDate}'),
              _MiniPill(label: entry.waferType),
              if (entry.waferSizeIn != null)
                _MiniPill(label: '${entry.waferSizeIn} in'),
              if ((entry.referenceInvoice ?? '').isNotEmpty)
                _MiniPill(label: entry.referenceInvoice!),
              if (entry.roughnessNm != null)
                _MiniPill(label: '${entry.roughnessNm} nm'),
            ],
          ),
          if ((entry.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            LinkifiedText(
              entry.notes!,
              style: Theme.of(context).textTheme.bodySmall,
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
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final String caption;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
            margin: const EdgeInsets.only(top: 4),
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
                  LinkifiedText(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit entry',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete entry',
              icon: const Icon(Icons.delete_outline, size: 18),
              color: const Color(0xFF852020),
              onPressed: onDelete,
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

class _PhotoViewDialog extends StatelessWidget {
  const _PhotoViewDialog({
    required this.title,
    required this.subtitle,
    required this.bytes,
  });

  final String title;
  final String subtitle;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: screenHeight * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF556869),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHistoryCard extends StatelessWidget {
  const _StatusHistoryCard({required this.entry, this.onEdit, this.onDelete});

  final StatusHistoryEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
            margin: const EdgeInsets.only(top: 4),
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
                  entry.statusLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_ts(entry.effectiveAt)}'
                  '${entry.clearedAt == null ? '' : '  →  ${_ts(entry.clearedAt)}'}',
                ),
                if ((entry.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  LinkifiedText(
                    entry.notes!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit entry',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete entry',
              icon: const Icon(Icons.delete_outline, size: 18),
              color: const Color(0xFF852020),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _RunCumulativePacSummary extends StatelessWidget {
  const _RunCumulativePacSummary({required this.run});

  final DarkfieldRunEntry run;

  @override
  Widget build(BuildContext context) {
    final cumulativePacPercent = computeDarkfieldCumulativePacPercent(
      run.binSummaries,
      summaryNotes: run.summaryNotes,
    );
    if (cumulativePacPercent == null) return const SizedBox.shrink();

    final baseStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    Widget label;
    if (cumulativePacPercent == 0) {
      label = Text('cum. PAC 0 %', style: baseStyle);
    } else {
      final sci = cumulativePacPercent.toStringAsExponential(2);
      final parts = sci.split('e');
      final mantissa = parts[0];
      final exponent = parts.length == 2 ? parts[1] : '';
      label = RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: 'cum. PAC $mantissa×10'),
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Text(exponent, style: baseStyle.copyWith(fontSize: 11)),
            ),
            TextSpan(text: ' %'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF244549),
              borderRadius: BorderRadius.circular(999),
            ),
            child: label,
          ),
        ],
      ),
    );
  }
}

class _PacPill extends StatelessWidget {
  const _PacPill({required this.label, required this.value});

  final String label; // e.g. 'PAC' or 'cum. PAC'
  final double value;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: const Color(0xFF244549),
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    Widget content;
    if (value == 0) {
      content = Text('$label 0 %', style: baseStyle);
    } else {
      final sci = value.toStringAsExponential(2); // "1.70e-3"
      final parts = sci.split('e');
      final mantissa = parts[0];
      final exponent = parts.length == 2 ? parts[1] : '';

      content = RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: '$label $mantissa×10'),
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Text(exponent, style: baseStyle.copyWith(fontSize: 11)),
            ),
            TextSpan(text: ' %'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EBE6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: content,
    );
  }
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
