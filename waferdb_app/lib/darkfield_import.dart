import 'dart:convert';

import 'api_client.dart';

class DarkfieldImportedBin {
  const DarkfieldImportedBin({
    required this.label,
    required this.particleCount,
    this.minSizeUm,
    this.maxSizeUm,
    this.particleDensityCm2,
    this.totalAreaUm2,
    this.notes,
  });

  final String label;
  final int particleCount;
  final double? minSizeUm;
  final double? maxSizeUm;
  final double? particleDensityCm2;
  final double? totalAreaUm2;
  final String? notes;
}

class DarkfieldImportedSummary {
  const DarkfieldImportedSummary({
    required this.summaryFilePath,
    required this.resolvedDirectoryPath,
    required this.bins,
    this.totalScannedAreaUm2,
    this.frameCount,
    this.inferredRunType,
  });

  final String summaryFilePath;
  final String resolvedDirectoryPath;
  final List<DarkfieldImportedBin> bins;
  final double? totalScannedAreaUm2;
  final int? frameCount;
  final String? inferredRunType;

  String buildSummaryNotes() {
    final lines = <String>[];
    if (totalScannedAreaUm2 != null) {
      final cm2 = totalScannedAreaUm2! / 1e8;
      lines.add('Total scanned area: ${cm2.toStringAsFixed(2)} cm2');
    }
    if (frameCount != null) {
      lines.add('Frames: $frameCount');
    }
    return lines.join('\n');
  }
}

Future<DarkfieldImportedSummary> importDarkfieldSummary(
  String requestedPath,
  ApiClient apiClient,
) async {
  final trimmedPath = requestedPath.trim();
  if (trimmedPath.isEmpty) {
    throw const FormatException('Data path is required.');
  }

  final payload = await apiClient.importDarkfieldSummary(trimmedPath);

  final summaryFilePath = payload['path'] as String? ?? '';
  final encodedContent = payload['content'] as String? ?? '';
  if (summaryFilePath.isEmpty || encodedContent.isEmpty) {
    throw const FormatException(
      'Darkfield import did not return a usable summary file.',
    );
  }

  final content = utf8.decode(base64Decode(encodedContent));
  final parsed = parseDarkfieldSummary(
    content,
    summaryFilePath: summaryFilePath,
  );

  final rawAreas = payload['particleAreas'] as Map<String, dynamic>?;
  if (rawAreas == null || rawAreas.isEmpty) {
    return parsed;
  }

  final areasByBinIndex = rawAreas.map(
    (key, value) => MapEntry(int.tryParse(key) ?? -1, (value as num).toDouble()),
  );

  final enrichedBins = parsed.bins.map((bin) {
    final csvBinIndex = _matchCsvBinIndex(bin);
    if (csvBinIndex == null) return bin;
    final totalArea = areasByBinIndex[csvBinIndex];
    if (totalArea == null) return bin;
    return DarkfieldImportedBin(
      label: bin.label,
      particleCount: bin.particleCount,
      minSizeUm: bin.minSizeUm,
      maxSizeUm: bin.maxSizeUm,
      particleDensityCm2: bin.particleDensityCm2,
      totalAreaUm2: totalArea,
      notes: bin.notes,
    );
  }).toList(growable: false);

  return DarkfieldImportedSummary(
    summaryFilePath: parsed.summaryFilePath,
    resolvedDirectoryPath: parsed.resolvedDirectoryPath,
    bins: enrichedBins,
    totalScannedAreaUm2: parsed.totalScannedAreaUm2,
    frameCount: parsed.frameCount,
    inferredRunType: parsed.inferredRunType,
  );
}


int? _matchCsvBinIndex(DarkfieldImportedBin bin) {
  if (bin.minSizeUm == null) return null;
  const binMinSizes = {0: 0.5, 1: 1.0, 2: 2.5, 3: 5.0, 4: 10.0, 5: 50.0};
  for (final entry in binMinSizes.entries) {
    if ((entry.value - bin.minSizeUm!).abs() < 0.01) {
      return entry.key;
    }
  }
  return null;
}

DarkfieldImportedSummary parseDarkfieldSummary(
  String content, {
  required String summaryFilePath,
}) {
  final totalsSectionMatch = RegExp(
    r'=== Totals across whole scan ===\s*(.*?)\s*(?:=== Area coverage ===|\z)',
    dotAll: true,
  ).firstMatch(content);
  if (totalsSectionMatch == null) {
    throw const FormatException('Missing totals section in summary_stats.txt.');
  }

  final summaryStats = _parseSummaryStats(content);
  final totalAreaMatch = RegExp(
    r'^Total scanned area:\s*([0-9]+(?:\.[0-9]+)?)\s*[µμ]m²',
    multiLine: true,
  ).firstMatch(content);
  final frameCountMatch = RegExp(
    r'^Frames \(seen\):\s*(\d+)',
    multiLine: true,
  ).firstMatch(content);

  final totalScannedAreaUm2 = totalAreaMatch == null
      ? null
      : double.tryParse(totalAreaMatch.group(1)!);
  final frameCount = frameCountMatch == null
      ? null
      : int.tryParse(frameCountMatch.group(1)!);
  final bins = <DarkfieldImportedBin>[];
  final totalsLines = totalsSectionMatch.group(1)!.split('\n');

  for (final rawLine in totalsLines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('ALL BINS')) {
      continue;
    }

    final match = RegExp(r'^(.+?):\s*total\s*=\s*(\d+)\s*$').firstMatch(line);
    if (match == null) {
      continue;
    }

    final labelText = match.group(1)!.trim();
    final particleCount = int.parse(match.group(2)!);
    final sizeLabel = _parseImportedBinLabel(labelText);
    final summaryNote = summaryStats[_normalizeBinKey(labelText)];
    final density = totalScannedAreaUm2 == null || totalScannedAreaUm2 <= 0
        ? null
        : particleCount * 100000000.0 / totalScannedAreaUm2;

    bins.add(
      DarkfieldImportedBin(
        label: sizeLabel.label,
        minSizeUm: sizeLabel.minSizeUm,
        maxSizeUm: sizeLabel.maxSizeUm,
        particleCount: particleCount,
        particleDensityCm2: density,
        notes: summaryNote,
      ),
    );
  }

  if (bins.isEmpty) {
    throw const FormatException(
      'No bin totals were found in summary_stats.txt.',
    );
  }

  return DarkfieldImportedSummary(
    summaryFilePath: summaryFilePath,
    resolvedDirectoryPath: _parentDirectory(summaryFilePath),
    bins: bins,
    totalScannedAreaUm2: totalScannedAreaUm2,
    frameCount: frameCount,
    inferredRunType: _inferRunTypeFromPath(summaryFilePath),
  );
}

Map<String, String> _parseSummaryStats(String content) {
  final sectionMatch = RegExp(
    r'=== Summary ===\s*(.*?)\s*(?:=== Totals across whole scan ===|\z)',
    dotAll: true,
  ).firstMatch(content);
  if (sectionMatch == null) {
    return const {};
  }

  final stats = <String, String>{};
  for (final rawLine in sectionMatch.group(1)!.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final match = RegExp(
      r'^(.+?):\s*avg\s*=\s*([0-9]+(?:\.[0-9]+)?),\s*std\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*$',
    ).firstMatch(line);
    if (match == null) {
      continue;
    }
    stats[_normalizeBinKey(match.group(1)!)] =
        'Imported avg/frame ${match.group(2)!}, std ${match.group(3)!}';
  }
  return stats;
}

_ImportedBinLabel _parseImportedBinLabel(String labelText) {
  final cleaned = labelText
      .replaceAll('–', '-')
      .replaceAll('µ', 'u')
      .replaceAll('μ', 'u')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final greaterMatch = RegExp(
    r'^>\s*([0-9]+(?:\.[0-9]+)?)\s*u?m$',
  ).firstMatch(cleaned);
  if (greaterMatch != null) {
    final minSize = double.parse(greaterMatch.group(1)!);
    return _ImportedBinLabel(
      label: '>${_formatNumber(minSize)} um',
      minSizeUm: minSize,
      maxSizeUm: null,
    );
  }

  final rangeMatch = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)\s*-\s*([0-9]+(?:\.[0-9]+)?)\s*u?m$',
  ).firstMatch(cleaned);
  if (rangeMatch != null) {
    final minSize = double.parse(rangeMatch.group(1)!);
    final maxSize = double.parse(rangeMatch.group(2)!);
    return _ImportedBinLabel(
      label: '${_formatNumber(minSize)}-${_formatNumber(maxSize)} um',
      minSizeUm: minSize,
      maxSizeUm: maxSize,
    );
  }

  return _ImportedBinLabel(label: cleaned, minSizeUm: null, maxSizeUm: null);
}

String _normalizeBinKey(String label) {
  return label
      .replaceAll('–', '-')
      .replaceAll('µ', 'u')
      .replaceAll('μ', 'u')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();
}

String _parentDirectory(String path) {
  final separator = path.lastIndexOf('/');
  if (separator <= 0) {
    return path;
  }
  return path.substring(0, separator);
}

String? _inferRunTypeFromPath(String path) {
  final upper = path.toUpperCase();
  if (upper.contains('/BACKGROUND')) {
    return 'background';
  }
  return 'inspection';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}


class _ImportedBinLabel {
  const _ImportedBinLabel({
    required this.label,
    required this.minSizeUm,
    required this.maxSizeUm,
  });

  final String label;
  final double? minSizeUm;
  final double? maxSizeUm;
}
