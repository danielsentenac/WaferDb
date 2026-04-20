import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/darkfield_import.dart';

void main() {
  test('parseDarkfieldSummary extracts bins, density, and run type', () {
    const content = '''
=== Background Threshold Parameters ===
Percentile: 99.5
Minimum intensity: 5

=== Summary ===
0.5–1 μm: avg = 0.32, std = 2.46
1–2.5 μm: avg = 0.06, std = 0.46
2.5–5 μm: avg = 0.01, std = 0.15
5–10 μm: avg = 0.00, std = 0.07
10–50 μm: avg = 0.02, std = 0.15
>50 μm: avg = 0.00, std = 0.07

=== Totals across whole scan ===
0.5–1 μm: total = 73
1–2.5 μm: total = 13
2.5–5 μm: total = 3
5–10 μm: total = 1
10–50 μm: total = 5
>50 μm: total = 1
ALL BINS (grand total): 96

=== Area coverage ===
Pixel size: 0.3200 µm
Frames (seen): 228
Illuminated pixels (sum across frames): 59368
Illuminated area: 6079.28 µm²  (0.006079 mm²)
Total scanned area: 471177127.53 µm²  (471.177128 mm²)
Coverage: 0.0013 %
''';

    final result = parseDarkfieldSummary(
      content,
      summaryFilePath:
          '/data/prod/rd/vac/darkfield/OP_7/2026_02_13/EXPOSED/summary_stats.txt',
    );

    expect(result.bins, hasLength(6));
    expect(
      result.resolvedDirectoryPath,
      '/data/prod/rd/vac/darkfield/OP_7/2026_02_13/EXPOSED',
    );
    expect(result.inferredRunType, 'inspection');
    expect(result.totalScannedAreaUm2, 471177127.53);
    expect(result.frameCount, 228);

    final firstBin = result.bins.first;
    expect(firstBin.label, '0.5-1 um');
    expect(firstBin.minSizeUm, 0.5);
    expect(firstBin.maxSizeUm, 1.0);
    expect(firstBin.particleCount, 73);
    expect(firstBin.particleDensityCm2, closeTo(15.49311198, 0.000001));
    expect(firstBin.notes, 'Imported avg/frame 0.32, std 2.46');

    final lastBin = result.bins.last;
    expect(lastBin.label, '>50 um');
    expect(lastBin.minSizeUm, 50.0);
    expect(lastBin.maxSizeUm, isNull);
    expect(lastBin.particleCount, 1);
  });

  test('parseDarkfieldSummary defaults non-background paths to inspection', () {
    const content = '''
=== Summary ===
0.5–1 μm: avg = 0.06, std = 0.57

=== Totals across whole scan ===
0.5–1 μm: total = 13
ALL BINS (grand total): 13

=== Area coverage ===
Frames (seen): 228
Total scanned area: 471177127.53 µm²  (471.177128 mm²)
''';

    final result = parseDarkfieldSummary(
      content,
      summaryFilePath:
          '/data/prod/rd/vac/darkfield/MO/2026_03_23/summary_stats.txt',
    );

    expect(result.inferredRunType, 'inspection');
  });
}
