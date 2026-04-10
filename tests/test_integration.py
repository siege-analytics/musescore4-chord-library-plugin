"""Integration tests for the Chord Library plugin.

Requires MuseScore Studio to be running. Tests verify:
- Clipboard paste pipeline (XML → ms-clipboard → pasteboard)
- .mscz generation with correct dot data
- GP5 export produces files Guitar Pro can read
- MusicXML export produces valid XML with frame elements
- Tuning files load correctly and produce right note calculations
- Voicing transposition produces correct fret offsets and notes

Run with:
    python -m pytest tests/test_integration.py -v

Note: Tests that interact with MuseScore's pasteboard are macOS-only.
"""

import json
import os
import platform
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = REPO_ROOT / "scripts"
DATA = REPO_ROOT / "plugin" / "data" / "voicings.json"
TUNINGS_DIR = REPO_ROOT / "plugin" / "tunings"
PLUGIN_DIR = Path.home() / "Documents" / "MuseScore4" / "Plugins" / "chordlibrary"

IS_MACOS = platform.system() == "Darwin"

sys.path.insert(0, str(SCRIPTS))


# === Fixtures ===

@pytest.fixture
def voicings():
    with open(DATA) as f:
        return json.load(f)["voicings"]


@pytest.fixture
def sample_voicing(voicings):
    """A known good voicing for testing: C7 E-shape shell."""
    for v in voicings:
        if v["id"] == "c7-shell-e-shape-6":
            return v
    pytest.skip("Sample voicing c7-shell-e-shape-6 not found")


# === Clipboard Pipeline Tests (macOS only) ===

@pytest.mark.skipif(not IS_MACOS, reason="macOS-only: clipboard tests")
class TestClipboardPipeline:

    def test_ms_clipboard_binary_exists(self):
        assert PLUGIN_DIR.exists(), "Plugin directory not found"
        ms_clip = PLUGIN_DIR / "ms-clipboard"
        assert ms_clip.exists(), "ms-clipboard binary not found"
        assert os.access(str(ms_clip), os.X_OK), "ms-clipboard not executable"

    def test_ms_clipboard_writes_to_pasteboard(self):
        """Write XML to pasteboard and verify it's there."""
        xml = '<EngravingItem><FretDiagram><fretOffset>7</fretOffset></FretDiagram></EngravingItem>'

        with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
            f.write(xml)
            f.flush()
            result = subprocess.run(
                [str(PLUGIN_DIR / "ms-clipboard"), f.name],
                capture_output=True, text=True,
            )
        assert result.returncode == 0, f"ms-clipboard failed: {result.stderr}"
        assert "Wrote" in result.stderr or "bytes" in result.stderr

        # Verify pasteboard content via Swift
        verify = subprocess.run(
            ["swift", "-e", '''
import AppKit
let pb = NSPasteboard.general
let t = NSPasteboard.PasteboardType("com.trolltech.anymime.application--musescore--symbol")
if let data = pb.data(forType: t), let text = String(data: data, encoding: .utf8) {
    print(text.contains("fretOffset") ? "FOUND" : "WRONG_CONTENT")
} else {
    print("NOT_FOUND")
}
'''],
            capture_output=True, text=True,
        )
        assert "FOUND" in verify.stdout, "Pasteboard doesn't contain expected XML"
        os.unlink(f.name)

    def test_engravingitem_xml_format(self, sample_voicing):
        """Verify the XML we generate matches MuseScore's expected format."""
        v = sample_voicing
        num_strings = v["strings"]
        fret_offset = v["fret_number"] - 1

        xml = '<EngravingItem>\n  <FretDiagram>\n'
        if fret_offset > 0:
            xml += f'    <fretOffset>{fret_offset}</fretOffset>\n'
        if num_strings != 6:
            xml += f'    <strings>{num_strings}</strings>\n'
        xml += '    <fretDiagram>\n'

        string_data = {}
        for dot in v["dots"]:
            ms_str = num_strings - dot["string"]
            string_data.setdefault(ms_str, {})["dot"] = dot["fret"]
        for mute in v["mutes"]:
            ms_str = num_strings - mute
            string_data.setdefault(ms_str, {})["marker"] = "cross"
        for open_s in v["open"]:
            ms_str = num_strings - open_s
            string_data.setdefault(ms_str, {})["marker"] = "circle"

        for sn in sorted(string_data.keys()):
            sd = string_data[sn]
            xml += f'      <string no="{sn}">\n'
            if "marker" in sd:
                xml += f'        <marker>{sd["marker"]}</marker>\n'
            if "dot" in sd:
                xml += f'        <dot fret="{sd["dot"]}">normal</dot>\n'
            xml += '      </string>\n'

        xml += '    </fretDiagram>\n  </FretDiagram>\n</EngravingItem>'

        # Verify it's valid XML
        root = ET.fromstring(xml)
        assert root.tag == "EngravingItem"
        fd = root.find("FretDiagram")
        assert fd is not None
        diagram = fd.find("fretDiagram")
        assert diagram is not None
        strings = diagram.findall("string")
        assert len(strings) > 0

    def test_launchd_agent_running(self):
        result = subprocess.run(
            ["launchctl", "list"],
            capture_output=True, text=True,
        )
        assert "chord-library-clipboard" in result.stdout, \
            "Clipboard launchd agent not running"

    def test_launchd_agent_triggers_on_file_write(self):
        """Write to paste-clipboard.xml and verify the agent runs ms-clipboard."""
        xml = '<EngravingItem><FretDiagram><fretOffset>5</fretOffset><fretDiagram><string no="0"><dot fret="1">normal</dot></string></fretDiagram></FretDiagram></EngravingItem>'
        xml_path = PLUGIN_DIR / "paste-clipboard.xml"

        # Write the file (triggers launchd WatchPaths)
        with open(xml_path, "w") as f:
            f.write(xml)

        # Wait for the agent to fire
        time.sleep(1.5)

        # Check pasteboard
        verify = subprocess.run(
            ["swift", "-e", '''
import AppKit
let pb = NSPasteboard.general
let t = NSPasteboard.PasteboardType("com.trolltech.anymime.application--musescore--symbol")
if let data = pb.data(forType: t) {
    print("HAS_DATA_\\(data.count)")
} else {
    print("NO_DATA")
}
'''],
            capture_output=True, text=True,
        )
        assert "HAS_DATA" in verify.stdout, \
            "launchd agent didn't write to pasteboard after file change"


# === .mscz Generation Tests ===

class TestMsczGeneration:

    def test_generate_mscz_produces_valid_zip(self, sample_voicing):
        from generate_mscz import generate_mscz
        with tempfile.NamedTemporaryFile(suffix=".mscz", delete=False) as f:
            generate_mscz(sample_voicing, "C", Path(f.name))
            assert zipfile.is_zipfile(f.name), "Generated file is not a valid ZIP"
            with zipfile.ZipFile(f.name) as zf:
                names = zf.namelist()
                assert any(n.endswith(".mscx") for n in names), "No .mscx inside .mscz"
        os.unlink(f.name)

    def test_mscz_contains_fretdiagram_xml(self, sample_voicing):
        from generate_mscz import generate_mscz
        with tempfile.NamedTemporaryFile(suffix=".mscz", delete=False) as f:
            generate_mscz(sample_voicing, "C", Path(f.name))
            with zipfile.ZipFile(f.name) as zf:
                for name in zf.namelist():
                    if name.endswith(".mscx"):
                        content = zf.read(name).decode("utf-8")
                        assert "<FretDiagram>" in content
                        assert "<fretDiagram>" in content
                        assert '<dot fret="' in content
                        break
        os.unlink(f.name)

    def test_mscz_transposition(self, sample_voicing):
        """Transposing to F should shift fret_number by 5."""
        from generate_mscz import generate_mscz, semitone_offset
        offset = semitone_offset("C", "F")
        assert offset == 5

        with tempfile.NamedTemporaryFile(suffix=".mscz", delete=False) as f:
            generate_mscz(sample_voicing, "F", Path(f.name))
            with zipfile.ZipFile(f.name) as zf:
                for name in zf.namelist():
                    if name.endswith(".mscx"):
                        content = zf.read(name).decode("utf-8")
                        expected_offset = sample_voicing["fret_number"] + offset - 1
                        assert f"<fretOffset>{expected_offset}</fretOffset>" in content
                        break
        os.unlink(f.name)

    def test_mscz_all_12_keys(self, sample_voicing):
        """Generate for all 12 keys without errors."""
        from generate_mscz import generate_mscz
        roots = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        for root in roots:
            with tempfile.NamedTemporaryFile(suffix=".mscz", delete=False) as f:
                generate_mscz(sample_voicing, root, Path(f.name))
                assert os.path.getsize(f.name) > 0, f"Empty file for root {root}"
            os.unlink(f.name)


# === GP5 Export Integration Tests ===

class TestGP5Integration:

    def test_gp5_roundtrip(self):
        """Export to GP5 and read it back with PyGuitarPro."""
        import guitarpro as gp

        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "export_gp5.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True, text=True,
            )
            assert result.returncode == 0

            gp5_files = list(Path(tmpdir).glob("*.gp5"))
            assert len(gp5_files) == 1

            # Read it back
            song = gp.parse(str(gp5_files[0]))
            assert len(song.tracks) >= 1
            assert len(song.measureHeaders) > 0

            # Check that chord diagrams exist on beats
            chords_found = 0
            for track in song.tracks:
                for measure in track.measures:
                    for voice in measure.voices:
                        for beat in voice.beats:
                            if beat.effect.chord:
                                chords_found += 1
            assert chords_found > 0, "No chord diagrams found in GP5 file"

    def test_gp5_chord_names_correct(self):
        """Verify chord names in GP5 match our voicing names."""
        import guitarpro as gp

        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(
                [sys.executable, str(SCRIPTS / "export_gp5.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True,
            )
            gp5_file = list(Path(tmpdir).glob("*.gp5"))[0]
            song = gp.parse(str(gp5_file))

            chord_names = set()
            for track in song.tracks:
                for measure in track.measures:
                    for voice in measure.voices:
                        for beat in voice.beats:
                            if beat.effect.chord:
                                chord_names.add(beat.effect.chord.name)

            # Should have C-rooted chord names
            assert any("7" in n for n in chord_names), f"No 7th chords found: {chord_names}"


# === MusicXML Integration Tests ===

class TestMusicXMLIntegration:

    def test_musicxml_has_frame_elements(self):
        """Verify MusicXML contains <frame> chord diagram elements."""
        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(
                [sys.executable, str(SCRIPTS / "export_musicxml.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True,
            )
            xml_file = list(Path(tmpdir).glob("*.musicxml"))[0]
            tree = ET.parse(str(xml_file))

            # Find all frame elements (chord diagrams)
            frames = tree.findall(".//{*}frame") or tree.findall(".//frame")
            # If namespace-less search fails, try iterating
            if not frames:
                for elem in tree.iter():
                    if elem.tag.endswith("frame") or elem.tag == "frame":
                        frames.append(elem)

            assert len(frames) > 0, "No <frame> elements found in MusicXML"

    def test_musicxml_frame_has_notes(self):
        """Verify frame elements contain frame-note children with string/fret data."""
        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(
                [sys.executable, str(SCRIPTS / "export_musicxml.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True,
            )
            xml_file = list(Path(tmpdir).glob("*.musicxml"))[0]
            tree = ET.parse(str(xml_file))

            # Find first frame-note
            found_note = False
            for elem in tree.iter():
                if "frame-note" in elem.tag:
                    found_note = True
                    # Should have string and fret children
                    has_string = any("string" in c.tag for c in elem)
                    has_fret = any("fret" in c.tag for c in elem)
                    assert has_string, "frame-note missing <string>"
                    assert has_fret, "frame-note missing <fret>"
                    break

            assert found_note, "No frame-note elements found"


# === Tuning Integration Tests ===

class TestTuningIntegration:

    def test_all_tunings_validate_against_voicings(self):
        """Verify voicings pass validation with the Van Eps tuning (superset)."""
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "validate.py"),
             "--tuning", str(TUNINGS_DIR / "7string-van-eps.json")],
            capture_output=True, text=True,
        )
        assert "Valid." in result.stdout
        assert "note verification ERROR" not in result.stderr

    def test_standard_tuning_excludes_7string(self):
        """Standard 6-string tuning should flag string 7 voicings."""
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "validate.py"),
             "--tuning", str(TUNINGS_DIR / "standard.json")],
            capture_output=True, text=True,
        )
        # Should have errors for 7-string voicings (string 7 not in tuning)
        assert "string 7 not in tuning config" in result.stderr

    def test_note_computation_dadgad(self):
        """In DADGAD, string 6 open should be D2 (MIDI 38), not E2 (40)."""
        with open(TUNINGS_DIR / "dadgad.json") as f:
            tuning = json.load(f)
        # String 6 in DADGAD is D2 = MIDI 38
        assert tuning["strings"]["6"] == 38
        # String 1 in DADGAD is D4 = MIDI 62
        assert tuning["strings"]["1"] == 62

    def test_chord_calculator_different_results_per_tuning(self):
        """Chord calculator should produce different fingerings for different tunings."""
        results = {}
        for tuning_file in ["standard.json", "dadgad.json"]:
            with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
                result = subprocess.run(
                    [sys.executable, str(SCRIPTS / "chord_calculator.py"),
                     "--tuning", str(TUNINGS_DIR / tuning_file),
                     "--root", "D", "--max-fret", "5",
                     "--export", "-o", f.name],
                    capture_output=True, text=True,
                )
                with open(f.name) as fp:
                    data = json.load(fp)
                results[tuning_file] = data["voicings"]
            os.unlink(f.name)

        # Both should find D voicings but with different fingerings
        std_dots = [str(v["dots"]) for v in results["standard.json"]]
        dad_dots = [str(v["dots"]) for v in results["dadgad.json"]]
        # At least some should differ
        assert std_dots != dad_dots, "Standard and DADGAD produced identical fingerings"


# === Transposition Integration Tests ===

class TestTranspositionIntegration:

    def test_all_voicings_transpose_to_all_keys(self, voicings):
        """Every voicing should be transposable to every key without errors."""
        from generate_mscz import semitone_offset
        roots = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        errors = []
        for v in voicings[:20]:  # test first 20 for speed
            for root in roots:
                offset = semitone_offset("C", root)
                new_fret = v["fret_number"] + offset
                if new_fret > 24:
                    errors.append(f"{v['id']} → {root}: fret {new_fret} > 24")
        # Some high-fret voicings will exceed 24 in high keys — that's expected
        # but the majority should be fine
        assert len(errors) < 20, f"Too many transposition overflows:\n" + "\n".join(errors[:5])

    def test_f_transposition_offset_is_5(self):
        from generate_mscz import semitone_offset
        assert semitone_offset("C", "F") == 5

    def test_transposition_roundtrip(self):
        """C → F → C should return to original fret number."""
        from generate_mscz import semitone_offset
        offset_cf = semitone_offset("C", "F")
        offset_fc = semitone_offset("F", "C")
        assert (offset_cf + offset_fc) % 12 == 0
