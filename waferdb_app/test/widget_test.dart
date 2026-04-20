import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/models.dart';

void main() {
  test('dashboard payload parsing keeps key counts', () {
    final dashboard = DashboardData.fromJson({
      'summary': {'wafers': 3, 'activities': 8, 'darkfieldRuns': 2},
      'statusBreakdown': [
        {
          'statusCode': 'new_out_of_box',
          'statusLabel': 'New out-of-the-box',
          'waferCount': 2,
        },
      ],
      'recentActivities': [
        {
          'activityId': 17,
          'waferName': 'WAFER-001',
          'purposeLabel': 'Operation',
          'locationName': 'NI Tower',
          'exposureQuantity': 24,
          'exposureUnit': 'hours',
        },
      ],
    });

    expect(dashboard.waferCount, 3);
    expect(dashboard.activityCount, 8);
    expect(dashboard.darkfieldRunCount, 2);
    expect(dashboard.statusBreakdown.single.statusCode, 'new_out_of_box');
    expect(dashboard.recentActivities.single.waferName, 'WAFER-001');
  });

  test('location labels remove duplicated codes and normalize Sas', () {
    const cleanRoom = LocationOption(
      code: '1500N',
      name: '1500N Clean Room',
      locationTypeLabel: 'Clean room',
      active: true,
    );
    const sas = LocationOption(
      code: 'CB_SAS',
      name: 'CB SAS',
      locationTypeLabel: 'Clean room sub-area',
      active: true,
    );
    const recent = RecentActivity(
      activityId: 1,
      waferName: 'WAFER-001',
      purposeLabel: 'Operation',
      locationName: 'CB DET SAS',
      exposureQuantity: 12,
      exposureUnit: 'hours',
    );

    expect(cleanRoom.displayLabel, '1500N Clean Room');
    expect(sas.displayLabel, 'CB Sas');
    expect(recent.displayLocationName, 'CB DET Sas');
  });

  test('wafer detail parsing keeps nested darkfield bins', () {
    final detail = WaferDetail.fromJson({
      'wafer': {
        'waferId': 4,
        'name': 'WAFER-004',
        'acquiredDate': '2026-04-15',
        'waferType': 'silicon',
      },
      'metadataHistory': [
        {
          'waferMetadataHistoryId': 8,
          'changedAt': '2026-04-16 09:30:00',
          'name': 'WAFER-004',
          'acquiredDate': '2026-04-15',
          'waferType': 'silicon',
          'changeSummary': 'Completed initial metadata.',
        },
      ],
      'statusHistory': const [],
      'activities': const [],
      'darkfieldRuns': [
        {
          'darkfieldRunId': 12,
          'runType': 'inspection',
          'measuredAt': '2026-04-16 10:15:00',
          'dataPath': 'data/darkfield/WAFER-004/2026-04-16',
          'binSummaries': [
            {
              'binSummaryId': 3,
              'binOrder': 1,
              'binLabel': '0-5 um',
              'particleCount': 18,
              'totalAreaUm2': 120.5,
            },
          ],
        },
      ],
    });

    expect(detail.metadataHistory.single.waferMetadataHistoryId, 8);
    expect(
      detail.metadataHistory.single.changeSummary,
      'Completed initial metadata.',
    );
    expect(detail.darkfieldRuns.single.darkfieldRunId, 12);
    expect(detail.darkfieldRuns.single.binSummaries.single.binOrder, 1);
    expect(detail.darkfieldRuns.single.binSummaries.single.particleCount, 18);
  });
}
