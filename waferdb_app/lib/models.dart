class StatusOption {
  const StatusOption({
    required this.code,
    required this.label,
    this.description,
  });

  final String code;
  final String label;
  final String? description;

  factory StatusOption.fromJson(Map<String, dynamic> json) {
    return StatusOption(
      code: json['code'] as String,
      label: json['label'] as String,
      description: _asString(json['description']),
    );
  }
}

class PurposeOption {
  const PurposeOption({required this.code, required this.label});

  final String code;
  final String label;

  factory PurposeOption.fromJson(Map<String, dynamic> json) {
    return PurposeOption(
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }
}

class LocationOption {
  const LocationOption({
    required this.code,
    required this.name,
    required this.locationTypeLabel,
    required this.active,
    this.parentLocationId,
  });

  final String code;
  final String name;
  final String locationTypeLabel;
  final bool active;
  final int? parentLocationId;

  String get displayLabel =>
      '$code  ${name.isEmpty ? locationTypeLabel : name}';

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      code: json['code'] as String,
      name: json['name'] as String,
      locationTypeLabel: json['locationTypeLabel'] as String,
      active: json['active'] as bool? ?? false,
      parentLocationId: _asInt(json['parentLocationId']),
    );
  }
}

class LookupBundle {
  const LookupBundle({
    required this.statuses,
    required this.purposes,
    required this.locations,
  });

  final List<StatusOption> statuses;
  final List<PurposeOption> purposes;
  final List<LocationOption> locations;

  factory LookupBundle.fromJson(Map<String, dynamic> json) {
    return LookupBundle(
      statuses: _asMapList(
        json['statuses'],
      ).map(StatusOption.fromJson).toList(growable: false),
      purposes: _asMapList(
        json['purposes'],
      ).map(PurposeOption.fromJson).toList(growable: false),
      locations: _asMapList(
        json['locations'],
      ).map(LocationOption.fromJson).toList(growable: false),
    );
  }
}

class WaferSummary {
  const WaferSummary({
    required this.waferId,
    required this.name,
    required this.acquiredDate,
    required this.waferType,
    this.referenceInvoice,
    this.roughnessNm,
    this.waferSizeIn,
    this.waferSizeLabel,
    this.notes,
    this.createdAt,
    this.statusCode,
    this.statusLabel,
    this.statusEffectiveAt,
  });

  final int waferId;
  final String name;
  final String acquiredDate;
  final String waferType;
  final String? referenceInvoice;
  final double? roughnessNm;
  final double? waferSizeIn;
  final String? waferSizeLabel;
  final String? notes;
  final String? createdAt;
  final String? statusCode;
  final String? statusLabel;
  final String? statusEffectiveAt;

  factory WaferSummary.fromJson(Map<String, dynamic> json) {
    return WaferSummary(
      waferId: _asInt(json['waferId']) ?? 0,
      name: json['name'] as String,
      acquiredDate: json['acquiredDate'] as String,
      waferType: json['waferType'] as String,
      referenceInvoice: _asString(json['referenceInvoice']),
      roughnessNm: _asDouble(json['roughnessNm']),
      waferSizeIn: _asDouble(json['waferSizeIn']),
      waferSizeLabel: _asString(json['waferSizeLabel']),
      notes: _asString(json['notes']),
      createdAt: _asString(json['createdAt']),
      statusCode: _asString(json['statusCode']),
      statusLabel: _asString(json['statusLabel']),
      statusEffectiveAt: _asString(json['statusEffectiveAt']),
    );
  }
}

class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.waferStatusHistoryId,
    required this.statusCode,
    required this.statusLabel,
    required this.effectiveAt,
    this.clearedAt,
    this.notes,
  });

  final int waferStatusHistoryId;
  final String statusCode;
  final String statusLabel;
  final String effectiveAt;
  final String? clearedAt;
  final String? notes;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      waferStatusHistoryId: _asInt(json['waferStatusHistoryId']) ?? 0,
      statusCode: json['statusCode'] as String,
      statusLabel: json['statusLabel'] as String,
      effectiveAt: json['effectiveAt'] as String,
      clearedAt: _asString(json['clearedAt']),
      notes: _asString(json['notes']),
    );
  }
}

class ActivityEntry {
  const ActivityEntry({
    required this.activityId,
    required this.purposeCode,
    required this.purposeLabel,
    required this.locationCode,
    required this.locationName,
    required this.exposureQuantity,
    required this.exposureUnit,
    this.statusCode,
    this.statusLabel,
    this.startedAt,
    this.endedAt,
    this.observations,
    this.createdAt,
  });

  final int activityId;
  final String purposeCode;
  final String purposeLabel;
  final String locationCode;
  final String locationName;
  final double exposureQuantity;
  final String exposureUnit;
  final String? statusCode;
  final String? statusLabel;
  final String? startedAt;
  final String? endedAt;
  final String? observations;
  final String? createdAt;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      activityId: _asInt(json['activityId']) ?? 0,
      purposeCode: json['purposeCode'] as String,
      purposeLabel: json['purposeLabel'] as String,
      locationCode: json['locationCode'] as String,
      locationName: json['locationName'] as String,
      exposureQuantity: _asDouble(json['exposureQuantity']) ?? 0,
      exposureUnit: json['exposureUnit'] as String,
      statusCode: _asString(json['statusCode']),
      statusLabel: _asString(json['statusLabel']),
      startedAt: _asString(json['startedAt']),
      endedAt: _asString(json['endedAt']),
      observations: _asString(json['observations']),
      createdAt: _asString(json['createdAt']),
    );
  }
}

class DarkfieldBinSummaryEntry {
  const DarkfieldBinSummaryEntry({
    required this.binSummaryId,
    required this.binOrder,
    required this.particleCount,
    this.binLabel,
    this.minSizeUm,
    this.maxSizeUm,
    this.totalAreaUm2,
    this.particleDensityCm2,
    this.notes,
  });

  final int binSummaryId;
  final int binOrder;
  final int particleCount;
  final String? binLabel;
  final double? minSizeUm;
  final double? maxSizeUm;
  final double? totalAreaUm2;
  final double? particleDensityCm2;
  final String? notes;

  factory DarkfieldBinSummaryEntry.fromJson(Map<String, dynamic> json) {
    return DarkfieldBinSummaryEntry(
      binSummaryId: _asInt(json['binSummaryId']) ?? 0,
      binOrder: _asInt(json['binOrder']) ?? 0,
      particleCount: _asInt(json['particleCount']) ?? 0,
      binLabel: _asString(json['binLabel']),
      minSizeUm: _asDouble(json['minSizeUm']),
      maxSizeUm: _asDouble(json['maxSizeUm']),
      totalAreaUm2: _asDouble(json['totalAreaUm2']),
      particleDensityCm2: _asDouble(json['particleDensityCm2']),
      notes: _asString(json['notes']),
    );
  }
}

class DarkfieldRunEntry {
  const DarkfieldRunEntry({
    required this.darkfieldRunId,
    required this.runType,
    required this.measuredAt,
    required this.dataPath,
    required this.binSummaries,
    this.activityId,
    this.summaryNotes,
    this.createdAt,
  });

  final int darkfieldRunId;
  final String runType;
  final String measuredAt;
  final String dataPath;
  final List<DarkfieldBinSummaryEntry> binSummaries;
  final int? activityId;
  final String? summaryNotes;
  final String? createdAt;

  factory DarkfieldRunEntry.fromJson(Map<String, dynamic> json) {
    return DarkfieldRunEntry(
      darkfieldRunId: _asInt(json['darkfieldRunId']) ?? 0,
      runType: json['runType'] as String,
      measuredAt: json['measuredAt'] as String,
      dataPath: json['dataPath'] as String,
      binSummaries: _asMapList(
        json['binSummaries'],
      ).map(DarkfieldBinSummaryEntry.fromJson).toList(growable: false),
      activityId: _asInt(json['activityId']),
      summaryNotes: _asString(json['summaryNotes']),
      createdAt: _asString(json['createdAt']),
    );
  }
}

class WaferDetail {
  const WaferDetail({
    required this.wafer,
    required this.statusHistory,
    required this.activities,
    required this.darkfieldRuns,
  });

  final WaferSummary wafer;
  final List<StatusHistoryEntry> statusHistory;
  final List<ActivityEntry> activities;
  final List<DarkfieldRunEntry> darkfieldRuns;

  factory WaferDetail.fromJson(Map<String, dynamic> json) {
    return WaferDetail(
      wafer: WaferSummary.fromJson(json['wafer'] as Map<String, dynamic>),
      statusHistory: _asMapList(
        json['statusHistory'],
      ).map(StatusHistoryEntry.fromJson).toList(growable: false),
      activities: _asMapList(
        json['activities'],
      ).map(ActivityEntry.fromJson).toList(growable: false),
      darkfieldRuns: _asMapList(
        json['darkfieldRuns'],
      ).map(DarkfieldRunEntry.fromJson).toList(growable: false),
    );
  }
}

class StatusBreakdown {
  const StatusBreakdown({
    required this.statusCode,
    required this.statusLabel,
    required this.waferCount,
  });

  final String statusCode;
  final String statusLabel;
  final int waferCount;

  factory StatusBreakdown.fromJson(Map<String, dynamic> json) {
    return StatusBreakdown(
      statusCode: json['statusCode'] as String,
      statusLabel: json['statusLabel'] as String,
      waferCount: _asInt(json['waferCount']) ?? 0,
    );
  }
}

class RecentActivity {
  const RecentActivity({
    required this.activityId,
    required this.waferName,
    required this.purposeLabel,
    required this.locationName,
    required this.exposureQuantity,
    required this.exposureUnit,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final int activityId;
  final String waferName;
  final String purposeLabel;
  final String locationName;
  final double exposureQuantity;
  final String exposureUnit;
  final String? startedAt;
  final String? endedAt;
  final String? createdAt;

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      activityId: _asInt(json['activityId']) ?? 0,
      waferName: json['waferName'] as String,
      purposeLabel: json['purposeLabel'] as String,
      locationName: json['locationName'] as String,
      exposureQuantity: _asDouble(json['exposureQuantity']) ?? 0,
      exposureUnit: json['exposureUnit'] as String,
      startedAt: _asString(json['startedAt']),
      endedAt: _asString(json['endedAt']),
      createdAt: _asString(json['createdAt']),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.waferCount,
    required this.activityCount,
    required this.darkfieldRunCount,
    required this.statusBreakdown,
    required this.recentActivities,
  });

  final int waferCount;
  final int activityCount;
  final int darkfieldRunCount;
  final List<StatusBreakdown> statusBreakdown;
  final List<RecentActivity> recentActivities;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return DashboardData(
      waferCount: _asInt(summary['wafers']) ?? 0,
      activityCount: _asInt(summary['activities']) ?? 0,
      darkfieldRunCount: _asInt(summary['darkfieldRuns']) ?? 0,
      statusBreakdown: _asMapList(
        json['statusBreakdown'],
      ).map(StatusBreakdown.fromJson).toList(growable: false),
      recentActivities: _asMapList(
        json['recentActivities'],
      ).map(RecentActivity.fromJson).toList(growable: false),
    );
  }
}

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map(
        (item) =>
            item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
      )
      .toList(growable: false);
}
