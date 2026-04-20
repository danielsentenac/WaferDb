import 'models.dart';

/// Derives the scanned area in µm² for a darkfield run.
///
/// Prefers the exact value back-derived from stored particle density and falls
/// back to the imported summary note line: `Total scanned area: <value> cm2`.
double? computeDarkfieldScannedAreaUm2(
  List<DarkfieldBinSummaryEntry> bins, {
  String? summaryNotes,
}) {
  for (final bin in bins) {
    if (bin.particleDensityCm2 != null &&
        bin.particleDensityCm2! > 0 &&
        bin.particleCount > 0) {
      return bin.particleCount / bin.particleDensityCm2! * 1e8;
    }
  }

  if (summaryNotes == null || summaryNotes.trim().isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^Total scanned area:\s*([0-9]+(?:\.[0-9]+)?)\s*cm2\b',
    multiLine: true,
  ).firstMatch(summaryNotes);
  final areaCm2 = match == null ? null : double.tryParse(match.group(1)!);
  if (areaCm2 == null || areaCm2 <= 0) {
    return null;
  }
  return areaCm2 * 1e8;
}

/// Per-bin PAC % for a single bin. Returns 0.0 when particle count is zero
/// (as long as the scanned area is known).
double? computeDarkfieldBinPacPercent(
  DarkfieldBinSummaryEntry bin,
  double? scannedAreaUm2,
) {
  if (scannedAreaUm2 == null || scannedAreaUm2 <= 0) return null;
  if (bin.particleCount == 0) return 0.0;

  final particleAreaUm2 = _resolveParticleAreaUm2(bin);
  if (particleAreaUm2 == null) {
    return null;
  }
  return particleAreaUm2 / scannedAreaUm2 * 100.0;
}

/// Computes cumulative PAC % starting from [fromIndex].
///
/// Prefers exact totalAreaUm2 data when available. Falls back to estimating
/// per-bin particle area as count × π × (avgDiameter/2)² using the stored
/// size range mid-point.
double? computeDarkfieldCumulativePacPercent(
  List<DarkfieldBinSummaryEntry> bins, {
  String? summaryNotes,
  int fromIndex = 0,
}) {
  if (bins.isEmpty) return null;

  final scannedAreaUm2 = computeDarkfieldScannedAreaUm2(
    bins,
    summaryNotes: summaryNotes,
  );

  double totalParticleAreaUm2 = 0;
  bool hasAnyArea = false;

  for (int i = fromIndex; i < bins.length; i++) {
    final particleAreaUm2 = _resolveParticleAreaUm2(bins[i]);
    if (particleAreaUm2 != null) {
      totalParticleAreaUm2 += particleAreaUm2;
      hasAnyArea = true;
      continue;
    }

    if (bins[i].minSizeUm != null || bins[i].maxSizeUm != null) {
      hasAnyArea = true;
    }
  }

  if (!hasAnyArea || scannedAreaUm2 == null || scannedAreaUm2 <= 0) {
    return null;
  }
  return totalParticleAreaUm2 / scannedAreaUm2 * 100.0;
}

double? _resolveParticleAreaUm2(DarkfieldBinSummaryEntry bin) {
  if (bin.totalAreaUm2 != null) {
    return bin.totalAreaUm2!;
  }
  if (bin.minSizeUm == null && bin.maxSizeUm == null) {
    return null;
  }
  if (bin.particleCount == 0) {
    return 0.0;
  }

  final min = bin.minSizeUm ?? bin.maxSizeUm!;
  final max = bin.maxSizeUm ?? bin.minSizeUm! * 2;
  final radiusUm = (min + max) / 4;
  return bin.particleCount * 3.14159265 * radiusUm * radiusUm;
}
