import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'darkfield_import.dart';
import 'models.dart';

Future<Map<String, String>?> showCreateWaferDialog(
  BuildContext context,
  LookupBundle lookups,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _CreateWaferDialog(lookups: lookups),
  );
}

Future<Map<String, String>?> showStatusDialog(
  BuildContext context,
  LookupBundle lookups, {
  StatusHistoryEntry? initialEntry,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _StatusDialog(lookups: lookups, initialEntry: initialEntry),
  );
}

Future<Map<String, String>?> showWaferHistoryDialog(
  BuildContext context,
  WaferDetail detail, {
  WaferMetadataHistoryEntry? initialEntry,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) =>
        _WaferHistoryDialog(detail: detail, initialEntry: initialEntry),
  );
}

Future<Map<String, String>?> showActivityDialog(
  BuildContext context,
  LookupBundle lookups, {
  ActivityEntry? initialEntry,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _ActivityDialog(lookups: lookups, initialEntry: initialEntry),
  );
}

Future<({Uint8List bytes, String contentType})?> showCapturePhotoDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<({Uint8List bytes, String contentType})>(
    context: context,
    builder: (context) => _CapturePhotoDialog(title: title),
  );
}

Future<Map<String, String>?> showCreateLocationDialog(
  BuildContext context,
  LookupBundle lookups,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _CreateLocationDialog(lookups: lookups),
  );
}

Future<Map<String, String>?> showDarkfieldRunDialog(
  BuildContext context,
  WaferDetail detail, {
  required String darkfieldRoot,
  required ApiClient apiClient,
  DarkfieldRunEntry? initialEntry,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _DarkfieldRunDialog(
      detail: detail,
      darkfieldRoot: darkfieldRoot,
      apiClient: apiClient,
      initialEntry: initialEntry,
    ),
  );
}

class _CapturePhotoDialog extends StatefulWidget {
  const _CapturePhotoDialog({required this.title});

  final String title;

  @override
  State<_CapturePhotoDialog> createState() => _CapturePhotoDialogState();
}

class _CapturePhotoDialogState extends State<_CapturePhotoDialog> {
  Uint8List? _photoBytes;
  String? _photoContentType;
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _capturing
                      ? null
                      : () => _acquire(_captureStatusPhoto),
                  icon: _capturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _capturing
                        ? 'Capturing…'
                        : (_photoBytes == null
                              ? 'Snapshot photo'
                              : 'Retake photo'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _capturing
                      ? null
                      : () => _acquire(_pickPhotoFromFile),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(
                    _photoBytes == null ? 'From file' : 'Replace from file',
                  ),
                ),
                if (_photoBytes != null)
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _photoBytes = null;
                      _photoContentType = null;
                    }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            if (_photoBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _photoBytes!,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_photoBytes == null || _capturing)
              ? null
              : () => Navigator.of(context).pop((
                  bytes: _photoBytes!,
                  contentType: _photoContentType ?? 'image/jpeg',
                )),
          child: const Text('Attach photo'),
        ),
      ],
    );
  }

  Future<void> _acquire(Future<_CapturedPhoto> Function() source) async {
    setState(() => _capturing = true);
    try {
      final photo = await source();
      if (!mounted) {
        return;
      }
      setState(() {
        _photoBytes = photo.bytes;
        _photoContentType = photo.contentType;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg != 'No file selected.') {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }
}

class _CreateWaferDialog extends StatefulWidget {
  const _CreateWaferDialog({required this.lookups});

  final LookupBundle lookups;

  @override
  State<_CreateWaferDialog> createState() => _CreateWaferDialogState();
}

class _CreateWaferDialogState extends State<_CreateWaferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _acquiredDateController;
  late final TextEditingController _invoiceController;
  late final TextEditingController _roughnessController;
  late final TextEditingController _typeController;
  late final TextEditingController _sizeInController;
  late final TextEditingController _notesController;
  String? _initialStatusCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _acquiredDateController = TextEditingController(text: _todayDate());
    _invoiceController = TextEditingController();
    _roughnessController = TextEditingController();
    _typeController = TextEditingController(text: 'silicon');
    _sizeInController = TextEditingController(text: '3');
    _notesController = TextEditingController();
    _initialStatusCode = widget.lookups.statuses.isNotEmpty
        ? widget.lookups.statuses.first.code
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _acquiredDateController.dispose();
    _invoiceController.dispose();
    _roughnessController.dispose();
    _typeController.dispose();
    _sizeInController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register Wafer'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogTextField(
                  controller: _nameController,
                  label: 'Wafer name',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _acquiredDateController,
                  label: 'Acquired date',
                  hint: 'YYYY-MM-DD',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _invoiceController,
                  label: 'Invoice reference',
                ),
                _DialogTextField(
                  controller: _roughnessController,
                  label: 'Roughness (nm)',
                ),
                _DialogTextField(
                  controller: _typeController,
                  label: 'Wafer type',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _sizeInController,
                  label: 'Wafer size (inches)',
                ),
                _DialogDropdownField<String>(
                  initialValue: _initialStatusCode,
                  label: 'Initial status',
                  items: widget.lookups.statuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status.code,
                          child: Text(status.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _initialStatusCode = value),
                ),
                const SizedBox(height: 12),
                _DialogTextField(
                  controller: _notesController,
                  label: 'Notes',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      {
        'name': _nameController.text.trim(),
        'acquiredDate': _acquiredDateController.text.trim(),
        'referenceInvoice': _invoiceController.text.trim(),
        'roughnessNm': _roughnessController.text.trim(),
        'waferType': _typeController.text.trim(),
        'waferSizeIn': _sizeInController.text.trim(),
        'initialStatusCode': _initialStatusCode ?? '',
        'notes': _notesController.text.trim(),
      }..removeWhere((_, value) => value.trim().isEmpty),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.lookups, this.initialEntry});

  final LookupBundle lookups;
  final StatusHistoryEntry? initialEntry;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _effectiveAtController;
  late final TextEditingController _clearedAtController;
  late final TextEditingController _notesController;
  String? _statusCode;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _effectiveAtController = TextEditingController(
      text: entry?.effectiveAt ?? _nowTimestamp(),
    );
    _clearedAtController = TextEditingController(text: entry?.clearedAt ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _statusCode = entry?.statusCode ??
        (widget.lookups.statuses.isNotEmpty ? widget.lookups.statuses.first.code : null);
  }

  @override
  void dispose() {
    _effectiveAtController.dispose();
    _clearedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialEntry == null ? 'Append Status' : 'Edit Status'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogDropdownField<String>(
                  initialValue: _statusCode,
                  label: 'Status',
                  items: widget.lookups.statuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status.code,
                          child: Text(status.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _statusCode = value),
                ),
                const SizedBox(height: 12),
                _DialogTextField(
                  controller: _effectiveAtController,
                  label: 'Effective at',
                  hint: 'YYYY-MM-DD HH:MM',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _clearedAtController,
                  label: 'Cleared at',
                  hint: 'Optional',
                ),
                _DialogTextField(
                  controller: _notesController,
                  label: 'Notes',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final values = <String, String>{
      'statusCode': _statusCode ?? '',
      'effectiveAt': _effectiveAtController.text.trim(),
      'clearedAt': _clearedAtController.text.trim(),
      'notes': _notesController.text.trim(),
    };
    Navigator.of(
      context,
    ).pop(values..removeWhere((_, value) => value.trim().isEmpty));
  }
}

class _WaferHistoryDialog extends StatefulWidget {
  const _WaferHistoryDialog({required this.detail, this.initialEntry});

  final WaferDetail detail;
  final WaferMetadataHistoryEntry? initialEntry;

  @override
  State<_WaferHistoryDialog> createState() => _WaferHistoryDialogState();
}

class _WaferHistoryDialogState extends State<_WaferHistoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _changedAtController;
  late final TextEditingController _nameController;
  late final TextEditingController _acquiredDateController;
  late final TextEditingController _invoiceController;
  late final TextEditingController _roughnessController;
  late final TextEditingController _typeController;
  late final TextEditingController _sizeInController;
  late final TextEditingController _notesController;
  late final TextEditingController _changeSummaryController;
  Uint8List? _photoBytes;
  String? _photoContentType;
  bool _acquiringPhoto = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    final wafer = widget.detail.wafer;
    _changedAtController = TextEditingController(
      text: entry?.changedAt ?? _nowTimestamp(),
    );
    _nameController = TextEditingController(text: entry?.name ?? wafer.name);
    _acquiredDateController = TextEditingController(
      text: entry?.acquiredDate ?? wafer.acquiredDate,
    );
    _invoiceController = TextEditingController(
      text: entry?.referenceInvoice ?? wafer.referenceInvoice ?? '',
    );
    _roughnessController = TextEditingController(
      text: _nullableNumber(entry?.roughnessNm ?? wafer.roughnessNm),
    );
    _typeController = TextEditingController(
      text: entry?.waferType ?? wafer.waferType,
    );
    _sizeInController = TextEditingController(
      text: _nullableNumber(entry?.waferSizeIn ?? wafer.waferSizeIn),
    );
    _notesController = TextEditingController(
      text: entry?.notes ?? wafer.notes ?? '',
    );
    _changeSummaryController = TextEditingController(
      text: entry?.changeSummary ?? '',
    );
  }

  @override
  void dispose() {
    _changedAtController.dispose();
    _nameController.dispose();
    _acquiredDateController.dispose();
    _invoiceController.dispose();
    _roughnessController.dispose();
    _typeController.dispose();
    _sizeInController.dispose();
    _notesController.dispose();
    _changeSummaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialEntry != null
            ? 'Edit history entry for ${widget.detail.wafer.name}'
            : 'Add history for ${widget.detail.wafer.name}',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogTextField(
                  controller: _changedAtController,
                  label: 'Changed at',
                  hint: 'YYYY-MM-DD HH:MM',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _nameController,
                  label: 'Wafer name',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _acquiredDateController,
                  label: 'Acquired date',
                  hint: 'YYYY-MM-DD',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _invoiceController,
                  label: 'Invoice reference',
                ),
                _DialogTextField(
                  controller: _roughnessController,
                  label: 'Roughness (nm)',
                ),
                _DialogTextField(
                  controller: _typeController,
                  label: 'Wafer type',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _sizeInController,
                  label: 'Wafer size (inches)',
                ),
                _DialogTextField(
                  controller: _notesController,
                  label: 'Notes',
                  maxLines: 3,
                ),
                _DialogTextField(
                  controller: _changeSummaryController,
                  label: 'History note',
                  hint: 'What changed in this update?',
                  maxLines: 3,
                ),
                _DialogFieldShell(
                  label: 'Box/Identity photo',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _acquiringPhoto
                                ? null
                                : () => _acquirePhoto(_captureStatusPhoto),
                            icon: _acquiringPhoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              _acquiringPhoto
                                  ? 'Capturing…'
                                  : (_photoBytes == null
                                        ? 'Snapshot photo'
                                        : 'Retake photo'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _acquiringPhoto
                                ? null
                                : () => _acquirePhoto(_pickPhotoFromFile),
                            icon: const Icon(Icons.folder_open_outlined),
                            label: Text(
                              _photoBytes == null
                                  ? 'From file'
                                  : 'Replace from file',
                            ),
                          ),
                          if (_photoBytes != null)
                            OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _photoBytes = null;
                                _photoContentType = null;
                              }),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove photo'),
                            ),
                        ],
                      ),
                      if (_photoBytes != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _photoBytes!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _acquiringPhoto ? null : _submit,
          icon: Icon(
            widget.initialEntry != null
                ? Icons.save_outlined
                : Icons.history_toggle_off,
          ),
          label: Text(widget.initialEntry != null ? 'Save changes' : 'Add history'),
        ),
      ],
    );
  }

  Future<void> _acquirePhoto(Future<_CapturedPhoto> Function() source) async {
    setState(() => _acquiringPhoto = true);
    try {
      final photo = await source();
      if (!mounted) return;
      setState(() {
        _photoBytes = photo.bytes;
        _photoContentType = photo.contentType;
      });
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (msg != 'No file selected.') {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _acquiringPhoto = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final values = <String, String>{
      'changedAt': _changedAtController.text.trim(),
      'name': _nameController.text.trim(),
      'acquiredDate': _acquiredDateController.text.trim(),
      'referenceInvoice': _invoiceController.text.trim(),
      'roughnessNm': _roughnessController.text.trim(),
      'waferType': _typeController.text.trim(),
      'waferSizeIn': _sizeInController.text.trim(),
      'notes': _notesController.text.trim(),
      'changeSummary': _changeSummaryController.text.trim(),
    };
    if (_photoBytes != null) {
      values['photoBase64'] = base64Encode(_photoBytes!);
      values['photoContentType'] = _photoContentType ?? 'image/jpeg';
    }
    Navigator.of(
      context,
    ).pop(values..removeWhere((_, value) => value.trim().isEmpty));
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.lookups, this.initialEntry});

  final LookupBundle lookups;
  final ActivityEntry? initialEntry;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _exposureQuantityController;
  late final TextEditingController _startedAtController;
  late final TextEditingController _endedAtController;
  late final TextEditingController _observationsController;
  String? _purposeCode;
  String? _locationCode;
  String? _observedStatusCode;
  String _exposureUnit = 'hours';

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    final qty = entry?.exposureQuantity;
    _exposureQuantityController = TextEditingController(
      text: qty == null
          ? ''
          : (qty == qty.truncateToDouble()
              ? qty.toStringAsFixed(0)
              : qty.toString()),
    );
    _startedAtController = TextEditingController(
      text: entry?.startedAt ?? _nowTimestamp(),
    );
    _endedAtController = TextEditingController(
      text: entry?.endedAt ?? '',
    );
    _observationsController = TextEditingController(
      text: entry?.observations ?? '',
    );
    if (entry != null) {
      _purposeCode = entry.purposeCode;
      _locationCode = entry.locationCode;
      _observedStatusCode = entry.statusCode;
      _exposureUnit = entry.exposureUnit ?? 'hours';
    } else {
      _purposeCode = widget.lookups.purposes.isNotEmpty
          ? widget.lookups.purposes.first.code
          : null;
      final activeLocations = widget.lookups.locations
          .where((location) => location.active)
          .toList();
      _locationCode = activeLocations.isNotEmpty
          ? activeLocations.first.code
          : null;
    }
  }

  @override
  void dispose() {
    _exposureQuantityController.dispose();
    _startedAtController.dispose();
    _endedAtController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLocations = widget.lookups.locations
        .where((location) => location.active)
        .toList();
    return AlertDialog(
      title: Text(widget.initialEntry == null ? 'Append Activity' : 'Edit Activity'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogDropdownField<String>(
                  initialValue: _purposeCode,
                  label: 'Purpose',
                  items: widget.lookups.purposes
                      .map(
                        (purpose) => DropdownMenuItem<String>(
                          value: purpose.code,
                          child: Text(purpose.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _purposeCode = value),
                ),
                const SizedBox(height: 12),
                _DialogDropdownField<String>(
                  initialValue: _locationCode,
                  label: 'Location',
                  items: activeLocations
                      .map(
                        (location) => DropdownMenuItem<String>(
                          value: location.code,
                          child: Text(location.displayLabel),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _locationCode = value),
                ),
                const SizedBox(height: 12),
                _DialogDropdownField<String>(
                  initialValue: _observedStatusCode,
                  label: 'Observed status',
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No snapshot'),
                    ),
                    ...widget.lookups.statuses.map(
                      (status) => DropdownMenuItem<String>(
                        value: status.code,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _observedStatusCode = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _DialogTextField(
                        controller: _exposureQuantityController,
                        label: 'Exposure quantity',
                        hint: 'optional',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _DialogDropdownField<String>(
                        initialValue: _exposureUnit,
                        label: 'Unit',
                        items: const [
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text('hours'),
                          ),
                          DropdownMenuItem(value: 'days', child: Text('days')),
                          DropdownMenuItem(
                            value: 'months',
                            child: Text('months'),
                          ),
                          DropdownMenuItem(
                            value: 'years',
                            child: Text('years'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _exposureUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                _DialogTextField(
                  controller: _startedAtController,
                  label: 'Started at',
                  hint: 'YYYY-MM-DD HH:MM',
                ),
                _DialogTextField(
                  controller: _endedAtController,
                  label: 'Ended at',
                  hint: 'YYYY-MM-DD HH:MM',
                ),
                _DialogTextField(
                  controller: _observationsController,
                  label: 'Observations',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final exposureQty = _exposureQuantityController.text.trim();
    if (exposureQty.isNotEmpty && double.tryParse(exposureQty) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exposure quantity must be a number.')),
      );
      return;
    }
    final values = <String, String>{
      'purposeCode': _purposeCode ?? '',
      'locationCode': _locationCode ?? '',
    };
    if (exposureQty.isNotEmpty) {
      values['exposureQuantity'] = exposureQty;
      values['exposureUnit'] = _exposureUnit;
    }
    if ((_observedStatusCode ?? '').isNotEmpty) {
      values['observedStatusCode'] = _observedStatusCode!;
    }
    for (final entry in {
      'startedAt': _startedAtController.text.trim(),
      'endedAt': _endedAtController.text.trim(),
      'observations': _observationsController.text.trim(),
    }.entries) {
      if (entry.value.isNotEmpty) values[entry.key] = entry.value;
    }
    Navigator.of(context).pop(values);
  }
}

class _CreateLocationDialog extends StatefulWidget {
  const _CreateLocationDialog({required this.lookups});

  final LookupBundle lookups;

  @override
  State<_CreateLocationDialog> createState() => _CreateLocationDialogState();
}

class _CreateLocationDialogState extends State<_CreateLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  String? _locationTypeCode;
  String? _parentLocationCode;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
    _locationTypeCode = widget.lookups.locationTypes.isNotEmpty
        ? widget.lookups.locationTypes.first.code
        : null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add location'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogTextField(
                  controller: _codeController,
                  label: 'Code',
                  hint: 'e.g. NE_HALL (will be uppercased)',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'e.g. NE Hall',
                  validator: _requiredField,
                ),
                _DialogDropdownField<String>(
                  initialValue: _locationTypeCode,
                  label: 'Location type',
                  items: widget.lookups.locationTypes
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t.code,
                          child: Text(t.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _locationTypeCode = value),
                ),
                const SizedBox(height: 12),
                _DialogDropdownField<String?>(
                  initialValue: _parentLocationCode,
                  label: 'Parent location (optional)',
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No parent'),
                    ),
                    ...widget.lookups.locations
                        .where((l) => l.active)
                        .map(
                          (l) => DropdownMenuItem<String?>(
                            value: l.code,
                            child: Text('${l.code} — ${l.displayLabel}'),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setState(() => _parentLocationCode = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final values = <String, String>{
      'code': _codeController.text.trim().toUpperCase(),
      'name': _nameController.text.trim(),
      'locationTypeCode': _locationTypeCode ?? '',
    };
    if (_parentLocationCode != null) {
      values['parentLocationCode'] = _parentLocationCode!;
    }
    Navigator.of(context).pop(values);
  }
}

class _DarkfieldRunDialog extends StatefulWidget {
  const _DarkfieldRunDialog({
    required this.detail,
    required this.darkfieldRoot,
    required this.apiClient,
    this.initialEntry,
  });

  final WaferDetail detail;
  final String darkfieldRoot;
  final ApiClient apiClient;
  final DarkfieldRunEntry? initialEntry;

  @override
  State<_DarkfieldRunDialog> createState() => _DarkfieldRunDialogState();
}

class _DarkfieldRunDialogState extends State<_DarkfieldRunDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _measuredAtController;
  late final TextEditingController _dataPathController;
  late final TextEditingController _summaryNotesController;
  final List<_DarkfieldBinDraft> _bins = <_DarkfieldBinDraft>[];
  String _runType = 'background';
  int? _activityId;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _measuredAtController = TextEditingController(
      text: entry?.measuredAt ?? _nowTimestamp(),
    );
    if (entry != null) {
      _dataPathController = TextEditingController(text: entry.dataPath);
      _summaryNotesController = TextEditingController(text: entry.summaryNotes ?? '');
      _runType = entry.runType;
      _activityId = entry.activityId;
      _bins.addAll(
        entry.binSummaries.isEmpty
            ? [_DarkfieldBinDraft()]
            : entry.binSummaries.map(_DarkfieldBinDraft.fromExisting),
      );
    } else {
      final normalizedRoot = widget.darkfieldRoot.endsWith('/')
          ? widget.darkfieldRoot.substring(0, widget.darkfieldRoot.length - 1)
          : widget.darkfieldRoot;
      _dataPathController = TextEditingController(
        text: '$normalizedRoot/${widget.detail.wafer.name}/${_todayDate()}',
      );
      _summaryNotesController = TextEditingController();
      _bins.add(_DarkfieldBinDraft());
    }
  }

  @override
  void dispose() {
    _measuredAtController.dispose();
    _dataPathController.dispose();
    _summaryNotesController.dispose();
    for (final bin in _bins) {
      bin.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialEntry == null
          ? 'Add darkfield run for ${widget.detail.wafer.name}'
          : 'Edit darkfield run for ${widget.detail.wafer.name}'),
      content: SizedBox(
        width: 920,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogDropdownField<String>(
                  initialValue: _runType,
                  label: 'Run type',
                  items: const [
                    DropdownMenuItem(
                      value: 'background',
                      child: Text('background'),
                    ),
                    DropdownMenuItem(
                      value: 'inspection',
                      child: Text('inspection'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _runType = value);
                    }
                  },
                ),
                _DialogDropdownField<int?>(
                  initialValue: _activityId,
                  label: 'Linked activity',
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Not linked to an activity',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...widget.detail.activities.indexed.map(
                      ((int, ActivityEntry) e) => DropdownMenuItem<int?>(
                        value: e.$2.activityId,
                        child: Text(
                          _activityLabel(e.$2, e.$1 + 1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _activityId = value),
                ),
                const SizedBox(height: 12),
                _DialogTextField(
                  controller: _measuredAtController,
                  label: 'Measured at',
                  hint: 'YYYY-MM-DD HH:MM',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _dataPathController,
                  label: 'Data path',
                  hint: '$defaultDarkfieldRoot/<wafer>/<date>',
                  validator: _requiredField,
                ),
                _DialogTextField(
                  controller: _summaryNotesController,
                  label: 'Summary notes',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bin summaries',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isImporting ? null : _importResults,
                            icon: _isImporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.file_download_outlined),
                            label: Text(
                              _isImporting ? 'Importing...' : 'Import results',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isImporting ? null : _addBin,
                            icon: const Icon(Icons.add),
                            label: const Text('Add bin'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  _bins.length,
                  (index) => _buildBinEditor(index, _bins[index]),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isImporting ? null : _submit,
          icon: const Icon(Icons.biotech),
          label: const Text('Save run'),
        ),
      ],
    );
  }

  Widget _buildBinEditor(int index, _DarkfieldBinDraft bin) {
    return Container(
      key: ValueKey(bin.draftId),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Bin ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (_bins.length > 1)
                IconButton(
                  onPressed: () => _removeBin(index),
                  tooltip: 'Remove bin',
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              SizedBox(
                width: 220,
                child: _DialogTextField(
                  controller: bin.labelController,
                  label: 'Label',
                  hint: 'e.g. 0-5 um',
                ),
              ),
              SizedBox(
                width: 180,
                child: _DialogTextField(
                  controller: bin.particleCountController,
                  label: 'Particle count',
                  validator: _requiredField,
                ),
              ),
              SizedBox(
                width: 190,
                child: _DialogTextField(
                  controller: bin.totalAreaController,
                  label: 'Total area (um2)',
                ),
              ),
            ],
          ),
          _DialogTextField(
            controller: bin.notesController,
            label: 'Bin notes',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  void _addBin() {
    setState(() {
      _bins.add(_DarkfieldBinDraft());
    });
  }

  Future<void> _importResults() async {
    final requestedPath = _dataPathController.text.trim();
    if (requestedPath.isEmpty) {
      _showDialogMessage('Enter a data path before importing results.');
      return;
    }

    setState(() => _isImporting = true);
    try {
      final imported = await importDarkfieldSummary(
        requestedPath,
        widget.apiClient,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _replaceBins(imported.bins);
        _dataPathController.text = imported.resolvedDirectoryPath;
        if (imported.inferredRunType != null) {
          _runType = imported.inferredRunType!;
        }
        if (_summaryNotesController.text.trim().isEmpty) {
          _summaryNotesController.text = imported.buildSummaryNotes();
        }
      });
      _showDialogMessage(
        'Imported ${imported.bins.length} bin summaries from ${imported.summaryFilePath}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      _showDialogMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _removeBin(int index) {
    setState(() {
      final removed = _bins.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final values = <String, String>{
      'runType': _runType,
      'measuredAt': _measuredAtController.text.trim(),
      'dataPath': _dataPathController.text.trim(),
      'binCount': _bins.length.toString(),
    };
    if (_activityId != null) {
      values['activityId'] = _activityId.toString();
    }
    _putIfNotBlank(values, 'summaryNotes', _summaryNotesController.text);

    for (var index = 0; index < _bins.length; index++) {
      final bin = _bins[index];
      final prefix = 'bin${index}_';
      values['${prefix}particleCount'] =
          bin.particleCountController.text.trim().isEmpty
          ? '0'
          : bin.particleCountController.text.trim();
      _putIfNotBlank(values, '${prefix}label', bin.labelController.text);
      _putIfNotBlank(
        values,
        '${prefix}totalAreaUm2',
        bin.totalAreaController.text,
      );
      _putIfNotBlank(values, '${prefix}notes', bin.notesController.text);
      _putIfNotNullDouble(values, '${prefix}minSizeUm', bin.minSizeUm);
      _putIfNotNullDouble(values, '${prefix}maxSizeUm', bin.maxSizeUm);
      _putIfNotNullDouble(
        values,
        '${prefix}particleDensityCm2',
        bin.particleDensityCm2,
      );
    }

    Navigator.of(context).pop(values);
  }

  void _replaceBins(List<DarkfieldImportedBin> importedBins) {
    for (final bin in _bins) {
      bin.dispose();
    }
    _bins
      ..clear()
      ..addAll(
        importedBins.isEmpty
            ? [_DarkfieldBinDraft()]
            : importedBins.map(_DarkfieldBinDraft.fromImported),
      );
  }

  void _showDialogMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DarkfieldBinDraft {
  _DarkfieldBinDraft()
    : draftId = _nextDraftId++,
      minSizeUm = null,
      maxSizeUm = null,
      particleDensityCm2 = null,
      labelController = TextEditingController(),
      particleCountController = TextEditingController(text: '0'),
      totalAreaController = TextEditingController(),
      notesController = TextEditingController();

  _DarkfieldBinDraft.fromExisting(DarkfieldBinSummaryEntry existing)
    : draftId = _nextDraftId++,
      minSizeUm = existing.minSizeUm,
      maxSizeUm = existing.maxSizeUm,
      particleDensityCm2 = existing.particleDensityCm2,
      labelController = TextEditingController(text: existing.binLabel ?? ''),
      particleCountController = TextEditingController(
        text: existing.particleCount.toString(),
      ),
      totalAreaController = TextEditingController(
        text: existing.totalAreaUm2 != null
            ? _formatAreaUm2(existing.totalAreaUm2!)
            : '',
      ),
      notesController = TextEditingController(text: existing.notes ?? '');

  _DarkfieldBinDraft.fromImported(DarkfieldImportedBin imported)
    : draftId = _nextDraftId++,
      minSizeUm = imported.minSizeUm,
      maxSizeUm = imported.maxSizeUm,
      particleDensityCm2 = imported.particleDensityCm2,
      labelController = TextEditingController(text: imported.label),
      particleCountController = TextEditingController(
        text: imported.particleCount.toString(),
      ),
      totalAreaController = TextEditingController(
        text: imported.totalAreaUm2 != null
            ? _formatAreaUm2(imported.totalAreaUm2!)
            : '',
      ),
      notesController = TextEditingController(text: imported.notes ?? '');

  static int _nextDraftId = 0;

  final int draftId;
  final double? minSizeUm;
  final double? maxSizeUm;
  final double? particleDensityCm2;
  final TextEditingController labelController;
  final TextEditingController particleCountController;
  final TextEditingController totalAreaController;
  final TextEditingController notesController;

  void dispose() {
    labelController.dispose();
    particleCountController.dispose();
    totalAreaController.dispose();
    notesController.dispose();
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return _DialogFieldShell(
      label: label,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
        decoration: _dialogInputDecoration(hint: hint),
      ),
    );
  }
}

class _DialogDropdownField<T> extends StatelessWidget {
  const _DialogDropdownField({
    required this.label,
    required this.items,
    required this.onChanged,
    this.initialValue,
  });

  final String label;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DialogFieldShell(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: initialValue,
        isDense: false,
        isExpanded: true,
        decoration: _dialogInputDecoration(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _DialogFieldShell extends StatelessWidget {
  const _DialogFieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

InputDecoration _dialogInputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

String? _requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

void _putIfNotBlank(Map<String, String> target, String key, String value) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) {
    target[key] = trimmed;
  }
}

void _putIfNotNullDouble(
  Map<String, String> target,
  String key,
  double? value,
) {
  if (value != null) {
    target[key] = value.toString();
  }
}

String _activityLabel(ActivityEntry activity, int waferIndex) {
  final timestamp =
      activity.endedAt ?? activity.startedAt ?? activity.createdAt;
  if (timestamp == null || timestamp.isEmpty) {
    return '#$waferIndex ${activity.purposeLabel} • ${activity.locationCode}';
  }
  return '#$waferIndex ${activity.purposeLabel} • ${activity.locationCode} • $timestamp';
}

String _todayDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _nowTimestamp() {
  final now = DateTime.now();
  return '${_todayDate()} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

String _nullableNumber(double? value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

String _formatAreaUm2(double value) {
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}

class _CapturedPhoto {
  const _CapturedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

// Raw bytes must stay under this so that base64+URL-encoding fits in the
// server's 2 MB application/x-www-form-urlencoded limit.
const _maxPhotoBytes = 1400000; // ~1.4 MB → ~1.87 MB base64

void _assertPhotoSize(Uint8List bytes) {
  if (bytes.length > _maxPhotoBytes) {
    final kb = (bytes.length / 1024).round();
    throw Exception(
      'Photo is too large ($kb KB). '
      'Please use a lower-resolution or higher-compression image (limit ~1.4 MB).',
    );
  }
}

Future<_CapturedPhoto> _captureStatusPhoto() async {
  if (Platform.isAndroid) {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) {
      throw Exception('No photo taken.');
    }
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Camera capture produced an empty image.');
    }
    _assertPhotoSize(bytes);
    final contentType = picked.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    return _CapturedPhoto(bytes: bytes, contentType: contentType);
  }

  // Linux desktop: use ffmpeg + V4L2
  final tempPath =
      '${Directory.systemTemp.path}/waferdb_snap_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final result = await Process.run('ffmpeg', [
    '-y',
    '-i',
    defaultStatusPhotoCameraDevice,
    '-frames:v',
    '1',
    '-q:v',
    '2',
    tempPath,
  ]);

  final file = File(tempPath);
  if (!file.existsSync()) {
    final relevantLines = result.stderr.toString().split('\n').where((l) {
      final t = l.trim();
      if (t.isEmpty) return false;
      if (t.startsWith('ffmpeg version')) return false;
      if (t.startsWith('built with')) return false;
      if (t.startsWith('configuration:')) return false;
      if (RegExp(r'^lib\w').hasMatch(t)) return false;
      return true;
    }).toList();
    final relevantError = relevantLines.join(' | ');
    throw Exception(
      'Camera capture failed ($defaultStatusPhotoCameraDevice): '
      '${relevantError.isEmpty ? 'exit ${result.exitCode}' : relevantError}',
    );
  }
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Camera capture produced an empty image.');
    }
    _assertPhotoSize(bytes);
    return _CapturedPhoto(bytes: bytes, contentType: 'image/jpeg');
  } finally {
    file.delete().ignore();
  }
}

Future<_CapturedPhoto> _pickPhotoFromFile() async {
  if (Platform.isAndroid) {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) {
      throw Exception('No file selected.');
    }
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty.');
    }
    _assertPhotoSize(bytes);
    final contentType = picked.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    return _CapturedPhoto(bytes: bytes, contentType: contentType);
  }

  // Linux desktop: use zenity file picker
  final result = await Process.run('zenity', [
    '--file-selection',
    '--title=Select box/identity photo',
    '--file-filter=Images (JPEG/PNG) | *.jpg *.jpeg *.png *.JPG *.JPEG *.PNG',
  ]);
  if (result.exitCode != 0) {
    throw Exception('No file selected.');
  }
  final path = result.stdout.toString().trim();
  if (path.isEmpty) {
    throw Exception('No file selected.');
  }
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('File not found: $path');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw Exception('Selected file is empty.');
  }
  _assertPhotoSize(bytes);
  final contentType = path.toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';
  return _CapturedPhoto(bytes: bytes, contentType: contentType);
}
