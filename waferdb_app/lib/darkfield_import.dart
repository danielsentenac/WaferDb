import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

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
  String requestedPath, {
  String host = defaultDarkfieldImportHost,
}) async {
  final trimmedPath = requestedPath.trim();
  if (trimmedPath.isEmpty) {
    throw const FormatException('Data path is required.');
  }

  final remoteCommand = _buildRemoteSummaryFetchCommand(trimmedPath);
  final result = await Process.run(
    'ssh',
    [host, remoteCommand],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    final stderr = (result.stderr as String?)?.trim();
    throw ProcessException(
      'ssh',
      [host, remoteCommand],
      stderr == null || stderr.isEmpty
          ? 'Failed to import darkfield results.'
          : stderr,
      result.exitCode,
    );
  }

  final payload =
      jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
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

  // Enrich bins with exact particle areas from per-frame CSV files.
  final areasByBinIndex = await _fetchParticleAreasByBin(
    parsed.resolvedDirectoryPath,
    host: host,
  );
  if (areasByBinIndex.isEmpty) {
    return parsed;
  }

  final enrichedBins = parsed.bins
      .map((bin) {
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
      })
      .toList(growable: false);

  return DarkfieldImportedSummary(
    summaryFilePath: parsed.summaryFilePath,
    resolvedDirectoryPath: parsed.resolvedDirectoryPath,
    bins: enrichedBins,
    totalScannedAreaUm2: parsed.totalScannedAreaUm2,
    frameCount: parsed.frameCount,
    inferredRunType: parsed.inferredRunType,
  );
}

Future<Map<int, double>> _fetchParticleAreasByBin(
  String directoryPath, {
  required String host,
}) async {
  try {
    final command = _buildRemoteParticleAreaFetchCommand(directoryPath);
    final result = await Process.run(
      'ssh',
      [host, command],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) return {};
    final raw = jsonDecode((result.stdout as String).trim());
    if (raw is! Map) return {};
    final areas = <int, double>{};
    raw.forEach((key, value) {
      final index = int.tryParse(key.toString());
      final area = value is num
          ? value.toDouble()
          : double.tryParse(value.toString());
      if (index != null && area != null) {
        areas[index] = area;
      }
    });
    return areas;
  } catch (_) {
    return {};
  }
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

String _buildRemoteParticleAreaFetchCommand(String directoryPath) {
  final encodedPath = base64Encode(utf8.encode(directoryPath));
  final script = [
    'import base64, csv, json, math, pathlib',
    'directory = pathlib.Path(base64.b64decode("$encodedPath").decode("utf-8"))',
    'areas = {}',
    'for f in sorted(directory.glob("*_particles.csv")):',
    '    try:',
    '        with open(f, newline="") as fp:',
    '            reader = csv.DictReader(fp)',
    '            for row in reader:',
    '                try:',
    '                    b = int(row["bin"])',
    '                    d = float(row["diameter_um"])',
    '                    areas[b] = areas.get(b, 0.0) + math.pi * (d / 2) ** 2',
    '                except (KeyError, ValueError):',
    '                    pass',
    '    except Exception:',
    '        pass',
    'import sys',
    'sys.stdout.write(json.dumps({str(k): v for k, v in areas.items()}))',
  ].join('\n');
  return "python3 -c '${script.replaceAll("'", r"'\''")}'";
}

String _buildRemoteSummaryFetchCommand(String requestedPath) {
  final encodedPath = base64Encode(utf8.encode(requestedPath));
  final script = [
    'import base64, json, pathlib, sys',
    'requested = pathlib.Path(base64.b64decode("$encodedPath").decode("utf-8"))',
    'names = ["summary_stats.txt", "summary_stat.txt"]',
    'matches = []',
    'if requested.is_file():',
    '    matches = [requested] if requested.name in names else []',
    'elif requested.is_dir():',
    '    direct = [requested / name for name in names if (requested / name).is_file()]',
    '    if len(direct) == 1:',
    '        matches = direct',
    '    elif len(direct) > 1:',
    '        matches = direct',
    '    else:',
    '        recursive = []',
    '        for name in names:',
    '            recursive.extend(sorted(requested.rglob(name)))',
    '        matches = recursive',
    'if len(matches) == 1:',
    '    path = matches[0]',
    '    payload = {"path": str(path), "content": base64.b64encode(path.read_bytes()).decode("ascii")}',
    '    sys.stdout.write(json.dumps(payload))',
    'elif not matches:',
    '    sys.stderr.write("No summary_stats.txt found under %s\\n" % requested)',
    '    sys.exit(2)',
    'else:',
    '    preview = "\\n".join(str(path) for path in matches[:10])',
    '    sys.stderr.write("Multiple summary_stats.txt files found under %s. Use a more specific path.\\n%s\\n" % (requested, preview))',
    '    sys.exit(3)',
  ].join('\n');
  return "python3 -c '${script.replaceAll("'", r"'\''")}'";
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
