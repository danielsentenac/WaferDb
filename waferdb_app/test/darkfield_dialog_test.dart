import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waferdb_app/dialogs.dart';
import 'package:waferdb_app/darkfield_import.dart';
import 'package:waferdb_app/models.dart';

void main() {
  testWidgets('darkfield dialog add bin button appends a new bin editor', (
    tester,
  ) async {
    final detail = WaferDetail(
      wafer: const WaferSummary(
        waferId: 1,
        name: 'WAFER-001',
        acquiredDate: '2026-04-16',
        waferType: 'silicon',
      ),
      metadataHistory: const [],
      statusHistory: const [],
      activities: const [],
      darkfieldRuns: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showDarkfieldRunDialog(
                  context,
                  detail,
                  darkfieldRoot: '/data/prod/rd/vac/darkfield',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Bin 1'), findsOneWidget);
    expect(find.text('Bin 2'), findsNothing);

    final addBinButton = find.widgetWithText(OutlinedButton, 'Add bin');
    await tester.ensureVisible(addBinButton);
    await tester.tap(addBinButton);
    await tester.pumpAndSettle();

    expect(find.text('Bin 2'), findsOneWidget);
  });

  testWidgets('darkfield dialog preserves imported PAC metadata on save', (
    tester,
  ) async {
    final detail = WaferDetail(
      wafer: const WaferSummary(
        waferId: 1,
        name: 'WAFER-001',
        acquiredDate: '2026-04-16',
        waferType: 'silicon',
      ),
      metadataHistory: const [],
      statusHistory: const [],
      activities: const [],
      darkfieldRuns: const [],
    );

    Map<String, String>? savedValues;

    Future<DarkfieldImportedSummary> fakeImport(
      String requestedPath, {
      String host = '',
    }) async {
      return const DarkfieldImportedSummary(
        summaryFilePath:
            '/data/prod/rd/vac/darkfield/WAFER-001/2026-04-16/summary_stats.txt',
        resolvedDirectoryPath:
            '/data/prod/rd/vac/darkfield/WAFER-001/2026-04-16',
        totalScannedAreaUm2: 471177127.53,
        frameCount: 228,
        inferredRunType: 'background',
        bins: [
          DarkfieldImportedBin(
            label: '0.5-1 um',
            particleCount: 13,
            minSizeUm: 0.5,
            maxSizeUm: 1.0,
            particleDensityCm2: 2.759,
            totalAreaUm2: 141.2,
            notes: 'Imported avg/frame 0.06, std 0.57',
          ),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                savedValues = await showDarkfieldRunDialog(
                  context,
                  detail,
                  darkfieldRoot: '/data/prod/rd/vac/darkfield',
                  importSummary: fakeImport,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final importButton = find.widgetWithText(OutlinedButton, 'Import results');
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save run');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedValues, isNotNull);
    expect(savedValues!['bin0_totalAreaUm2'], '141.2');
    expect(savedValues!['bin0_minSizeUm'], '0.5');
    expect(savedValues!['bin0_maxSizeUm'], '1.0');
    expect(savedValues!['bin0_particleDensityCm2'], '2.759');
  });
}
