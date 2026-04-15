import 'package:flutter/material.dart';

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
  LookupBundle lookups,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _StatusDialog(lookups: lookups),
  );
}

Future<Map<String, String>?> showActivityDialog(
  BuildContext context,
  LookupBundle lookups,
) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _ActivityDialog(lookups: lookups),
  );
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
  late final TextEditingController _sizeLabelController;
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
    _sizeInController = TextEditingController(text: '4');
    _sizeLabelController = TextEditingController(text: '4-inch');
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
    _sizeLabelController.dispose();
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
                _DialogTextField(
                  controller: _sizeLabelController,
                  label: 'Wafer size label',
                ),
                DropdownButtonFormField<String>(
                  initialValue: _initialStatusCode,
                  decoration: const InputDecoration(
                    labelText: 'Initial status',
                  ),
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
        'waferSizeLabel': _sizeLabelController.text.trim(),
        'initialStatusCode': _initialStatusCode ?? '',
        'notes': _notesController.text.trim(),
      }..removeWhere((_, value) => value.trim().isEmpty),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.lookups});

  final LookupBundle lookups;

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
    _effectiveAtController = TextEditingController(text: _nowTimestamp());
    _clearedAtController = TextEditingController();
    _notesController = TextEditingController();
    _statusCode = widget.lookups.statuses.isNotEmpty
        ? widget.lookups.statuses.first.code
        : null;
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
      title: const Text('Append Status'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _statusCode,
                decoration: const InputDecoration(labelText: 'Status'),
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
              _DialogTextField(
                controller: _effectiveAtController,
                label: 'Effective at',
                hint: 'YYYY-MM-DD HH:MM:SS',
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
    Navigator.of(context).pop(
      {
        'statusCode': _statusCode ?? '',
        'effectiveAt': _effectiveAtController.text.trim(),
        'clearedAt': _clearedAtController.text.trim(),
        'notes': _notesController.text.trim(),
      }..removeWhere((_, value) => value.trim().isEmpty),
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.lookups});

  final LookupBundle lookups;

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
    _exposureQuantityController = TextEditingController(text: '1');
    _startedAtController = TextEditingController(text: _nowTimestamp());
    _endedAtController = TextEditingController(text: _nowTimestamp());
    _observationsController = TextEditingController();
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
      title: const Text('Append Activity'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _purposeCode,
                  decoration: const InputDecoration(labelText: 'Purpose'),
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
                DropdownButtonFormField<String>(
                  initialValue: _locationCode,
                  decoration: const InputDecoration(labelText: 'Location'),
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
                DropdownButtonFormField<String>(
                  initialValue: _observedStatusCode,
                  decoration: const InputDecoration(
                    labelText: 'Observed status',
                  ),
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
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _DialogTextField(
                        controller: _exposureQuantityController,
                        label: 'Exposure quantity',
                        validator: _requiredField,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _exposureUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
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
                  hint: 'YYYY-MM-DD HH:MM:SS',
                ),
                _DialogTextField(
                  controller: _endedAtController,
                  label: 'Ended at',
                  hint: 'YYYY-MM-DD HH:MM:SS',
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
    Navigator.of(context).pop(
      {
        'purposeCode': _purposeCode ?? '',
        'locationCode': _locationCode ?? '',
        'observedStatusCode': _observedStatusCode ?? '',
        'exposureQuantity': _exposureQuantityController.text.trim(),
        'exposureUnit': _exposureUnit,
        'startedAt': _startedAtController.text.trim(),
        'endedAt': _endedAtController.text.trim(),
        'observations': _observationsController.text.trim(),
      }..removeWhere((_, value) => value.trim().isEmpty),
    );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

String? _requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
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
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}
