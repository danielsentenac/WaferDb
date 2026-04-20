import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/darkfield_metrics.dart';
import 'package:waferdb_app/models.dart';

void main() {
  test(
    'computeDarkfieldScannedAreaUm2 falls back to imported summary notes',
    () {
      const bins = [
        DarkfieldBinSummaryEntry(
          binSummaryId: 1,
          binOrder: 1,
          binLabel: '0.5-1 um',
          particleCount: 13,
          totalAreaUm2: 141.2,
        ),
      ];

      final scannedAreaUm2 = computeDarkfieldScannedAreaUm2(
        bins,
        summaryNotes:
            'Imported from olserver135:/tmp/summary_stats.txt\n'
            'Total scanned area: 4.71 cm2\n'
            'Frames: 228',
      );

      expect(scannedAreaUm2, 471000000);
    },
  );

  test('computeDarkfieldCumulativePacPercent uses stored total areas', () {
    const bins = [
      DarkfieldBinSummaryEntry(
        binSummaryId: 1,
        binOrder: 1,
        binLabel: '0.5-1 um',
        particleCount: 13,
        totalAreaUm2: 141.2,
      ),
      DarkfieldBinSummaryEntry(
        binSummaryId: 2,
        binOrder: 2,
        binLabel: '1-2.5 um',
        particleCount: 3,
        totalAreaUm2: 80.4,
      ),
    ];

    final cumulativePacPercent = computeDarkfieldCumulativePacPercent(
      bins,
      summaryNotes: 'Total scanned area: 4.71 cm2',
    );

    expect(
      cumulativePacPercent,
      closeTo((141.2 + 80.4) / 471000000 * 100, 1e-12),
    );
  });
}
