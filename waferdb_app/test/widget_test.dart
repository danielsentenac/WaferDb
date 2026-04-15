import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/models.dart';

void main() {
  test('dashboard payload parsing keeps key counts', () {
    final dashboard = DashboardData.fromJson({
      'summary': {
        'wafers': 3,
        'activities': 8,
        'darkfieldRuns': 2,
      },
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
}
