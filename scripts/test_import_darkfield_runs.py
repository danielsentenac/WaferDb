import pathlib
import sys
import unittest


sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from import_darkfield_runs import (  # noqa: E402
    ImportedBin,
    ImportedSummary,
    build_darkfield_run_form,
    build_summary_notes,
    derive_api_base,
    enrich_bins_with_particle_areas,
    infer_run_type_from_path,
    parse_darkfield_summary,
)


class ImportDarkfieldRunsTests(unittest.TestCase):
    def test_parse_darkfield_summary_extracts_bins_and_density(self) -> None:
        content = """
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
"""

        summary = parse_darkfield_summary(
            content,
            summary_file_path="/data/prod/rd/vac/darkfield/OP_7/2026_02_13/EXPOSED/summary_stats.txt",
        )

        self.assertEqual(summary.inferred_run_type, "inspection")
        self.assertEqual(summary.frame_count, 228)
        self.assertAlmostEqual(summary.total_scanned_area_um2, 471177127.53)
        self.assertEqual(len(summary.bins), 6)
        self.assertEqual(summary.bins[0].label, "0.5-1 um")
        self.assertAlmostEqual(summary.bins[0].min_size_um, 0.5)
        self.assertAlmostEqual(summary.bins[0].max_size_um, 1.0)
        self.assertEqual(summary.bins[0].particle_count, 73)
        self.assertAlmostEqual(summary.bins[0].particle_density_cm2, 15.49311198, places=6)
        self.assertEqual(summary.bins[0].notes, "Imported avg/frame 0.32, std 2.46")
        self.assertEqual(summary.bins[-1].label, ">50 um")
        self.assertAlmostEqual(summary.bins[-1].min_size_um, 50.0)
        self.assertIsNone(summary.bins[-1].max_size_um)

    def test_enrich_bins_with_particle_areas_uses_csv_index_mapping(self) -> None:
        summary = ImportedSummary(
            summary_file_path="/tmp/summary_stats.txt",
            resolved_directory_path="/tmp",
            bins=(
                ImportedBin(label="0.5-1 um", particle_count=10, min_size_um=0.5),
                ImportedBin(label="1-2.5 um", particle_count=5, min_size_um=1.0),
            ),
        )

        enriched = enrich_bins_with_particle_areas(summary, {0: 12.3, 1: 45.6})

        self.assertAlmostEqual(enriched.bins[0].total_area_um2 or 0.0, 12.3)
        self.assertAlmostEqual(enriched.bins[1].total_area_um2 or 0.0, 45.6)

    def test_build_darkfield_run_form_keeps_hidden_bin_metadata(self) -> None:
        summary = ImportedSummary(
            summary_file_path="/data/prod/rd/vac/darkfield/WAFER-001/2026_04_16/summary_stats.txt",
            resolved_directory_path="/data/prod/rd/vac/darkfield/WAFER-001/2026_04_16",
            total_scanned_area_um2=471177127.53,
            frame_count=228,
            bins=(
                ImportedBin(
                    label="0.5-1 um",
                    particle_count=13,
                    min_size_um=0.5,
                    max_size_um=1.0,
                    particle_density_cm2=2.759,
                    total_area_um2=141.2,
                    notes="Imported avg/frame 0.06, std 0.57",
                ),
            ),
        )

        form = build_darkfield_run_form(
            summary,
            host="olserver38",
            measured_at="2026-04-16 12:34:56",
            run_type="background",
        )

        self.assertEqual(form["bin0_particleCount"], "13")
        self.assertEqual(form["bin0_minSizeUm"], "0.5")
        self.assertEqual(form["bin0_maxSizeUm"], "1.0")
        self.assertEqual(form["bin0_particleDensityCm2"], "2.759")
        self.assertEqual(form["bin0_totalAreaUm2"], "141.2")
        self.assertIn("Total scanned area: 4.71 cm2", form["summaryNotes"])

    def test_derive_api_base_normalizes_api_suffix(self) -> None:
        site_env = pathlib.Path(self.id().replace(".", "_"))
        try:
            site_env.write_text(
                "\n".join(
                    [
                        "WAFERDB_SCHEME=http",
                        "WAFERDB_HOST=olserver134.virgo.infn.it",
                        "WAFERDB_PORT=8081",
                        "WAFERDB_CONTEXT_PATH=/WaferDb",
                    ]
                ),
                encoding="utf-8",
            )
            api_base = derive_api_base(
                explicit_api_base=None,
                site_env_path=site_env,
                env={},
            )
        finally:
            if site_env.exists():
                site_env.unlink()

        self.assertEqual(api_base, "http://olserver134.virgo.infn.it:8081/WaferDb/api")

    def test_infer_run_type_looks_at_path_segments(self) -> None:
        self.assertEqual(
            infer_run_type_from_path("/root/OP_7/2026_02_12/BACKGROUND2/summary_stats.txt"),
            "background",
        )
        self.assertEqual(
            infer_run_type_from_path("/root/OP_7/2026_02_13/EXPOSED/summary_stats.txt"),
            "inspection",
        )
        self.assertEqual(
            infer_run_type_from_path("/root/MO/2026_03_23/summary_stats.txt"),
            "inspection",
        )

    def test_build_summary_notes_formats_area_in_cm2(self) -> None:
        notes = build_summary_notes(
            "olserver38",
            "/data/prod/rd/vac/darkfield/MO/2026_03_23/summary_stats.txt",
            total_scanned_area_um2=471177127.53,
            frame_count=228,
        )

        self.assertIn("Imported from olserver38:/data/prod/rd/vac/darkfield/MO/2026_03_23/summary_stats.txt", notes)
        self.assertIn("Total scanned area: 4.71 cm2", notes)
        self.assertIn("Frames: 228", notes)


if __name__ == "__main__":
    unittest.main()
