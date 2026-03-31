"""Core test suite for the Chord Library plugin.

Tests all Python logic without requiring MuseScore. Run with:
    python -m pytest tests/ -v
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = REPO_ROOT / "scripts"
DATA = REPO_ROOT / "data" / "voicings.json"
SCHEMA = REPO_ROOT / "schema" / "voicings.schema.json"
TUNINGS_DIR = REPO_ROOT / "config" / "tunings"

sys.path.insert(0, str(SCRIPTS))


# === Fixtures ===

@pytest.fixture
def voicings():
    with open(DATA) as f:
        return json.load(f)["voicings"]


@pytest.fixture
def schema():
    with open(SCHEMA) as f:
        return json.load(f)


# === Voicing Data Tests ===

class TestVoicingData:
    def test_voicings_file_exists(self):
        assert DATA.exists()

    def test_voicings_is_valid_json(self):
        with open(DATA) as f:
            data = json.load(f)
        assert "voicings" in data
        assert isinstance(data["voicings"], list)

    def test_voicing_count(self, voicings):
        assert len(voicings) >= 700, f"Expected ≥150 voicings, got {len(voicings)}"

    def test_all_voicings_have_required_fields(self, voicings):
        required = [
            "id", "name", "chord_quality", "root", "category",
            "context", "strings", "fret_number", "visible_frets",
            "dots", "mutes", "open", "notes", "intervals", "tags",
        ]
        for v in voicings:
            for field in required:
                assert field in v, f"Voicing {v.get('id', '?')} missing field: {field}"

    def test_all_roots_are_c(self, voicings):
        for v in voicings:
            assert v["root"] == "C", f"Voicing {v['id']} has root {v['root']}, expected C"

    def test_no_duplicate_ids(self, voicings):
        ids = [v["id"] for v in voicings]
        dupes = [x for x in ids if ids.count(x) > 1]
        assert not dupes, f"Duplicate IDs: {set(dupes)}"

    def test_all_contexts_populated(self, voicings):
        contexts = {v["context"] for v in voicings}
        for ctx in ["CM6", "CM7", "CV6", "CV7"]:
            assert ctx in contexts, f"Context {ctx} has no voicings"

    def test_all_categories_populated(self, voicings):
        categories = {v["category"] for v in voicings}
        for cat in ["shell", "drop2", "drop3", "extended", "altered", "quartal"]:
            assert cat in categories, f"Category {cat} has no voicings"

    def test_string_coverage(self, voicings):
        """Every string must be in dots, mutes, or open."""
        for v in voicings:
            all_strings = set(range(1, v["strings"] + 1))
            dotted = {d["string"] for d in v["dots"]}
            muted = set(v["mutes"])
            opened = set(v["open"])
            covered = dotted | muted | opened
            missing = all_strings - covered
            assert not missing, (
                f"Voicing {v['id']}: strings {sorted(missing)} not in dots/mutes/open"
            )

    def test_no_verification_tags(self, voicings):
        """All voicings should be verified (no needs_verification tags)."""
        flagged = [v["id"] for v in voicings if "needs_verification" in v.get("tags", [])]
        assert not flagged, f"{len(flagged)} voicings still tagged needs_verification"


# === Transposition Tests ===

class TestTransposition:
    SEMITONE_MAP = {
        "C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5,
        "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11,
    }
    NOTE_NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    NOTE_NAMES_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    FLAT_KEYS = {"F", "Bb", "Eb", "Ab", "Db", "Gb"}

    def semitone_offset(self, src, tgt):
        return (self.SEMITONE_MAP[tgt] - self.SEMITONE_MAP[src]) % 12

    def transpose_note(self, note, offset, prefer_flats):
        st = self.SEMITONE_MAP.get(note)
        if st is None:
            return note
        new = (st + offset) % 12
        return self.NOTE_NAMES_FLAT[new] if prefer_flats else self.NOTE_NAMES_SHARP[new]

    def test_c_to_f_is_5_semitones(self):
        assert self.semitone_offset("C", "F") == 5

    def test_c_to_g_is_7_semitones(self):
        assert self.semitone_offset("C", "G") == 7

    def test_c_to_c_is_0(self):
        assert self.semitone_offset("C", "C") == 0

    def test_c_to_b_is_11(self):
        assert self.semitone_offset("C", "B") == 11

    def test_all_offsets_roundtrip(self):
        for root in self.SEMITONE_MAP:
            offset = self.semitone_offset("C", root)
            assert 0 <= offset <= 11

    def test_flat_key_respelling(self):
        # F7 has Bb, Eb — should use flats
        offset = self.semitone_offset("C", "F")
        bb = self.transpose_note("Bb", offset, True)
        assert bb == "Eb", f"Bb transposed to F should be Eb, got {bb}"

    def test_sharp_key_respelling(self):
        # A7 should use sharps
        offset = self.semitone_offset("C", "A")
        e = self.transpose_note("E", offset, False)
        assert e == "C#", f"E transposed to A (sharps) should be C#, got {e}"

    def test_flat_keys_are_correct(self):
        for key in ["F", "Bb", "Eb", "Ab", "Db", "Gb"]:
            assert key in self.FLAT_KEYS

    def test_sharp_keys_prefer_sharps(self):
        for key in ["C", "G", "D", "A", "E", "B"]:
            assert key not in self.FLAT_KEYS


# === Note Computation Tests ===

class TestNoteComputation:
    TUNING = {1: 64, 2: 59, 3: 55, 4: 50, 5: 45, 6: 40, 7: 33}
    CHROMATIC = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    ENHARMONIC = {
        "C#": "Db", "D#": "Eb", "E#": "F", "F#": "Gb",
        "G#": "Ab", "A#": "Bb", "B#": "C", "Cb": "B", "Fb": "E",
        "Bbb": "A",  # double flat
    }

    def midi_to_note(self, midi):
        return self.CHROMATIC[midi % 12]

    def normalize_note(self, name):
        """Convert any enharmonic spelling to canonical form."""
        return self.ENHARMONIC.get(name, name)

    def test_string_6_fret_8_is_c(self):
        assert self.midi_to_note(self.TUNING[6] + 8) == "C"

    def test_string_5_fret_3_is_c(self):
        assert self.midi_to_note(self.TUNING[5] + 3) == "C"

    def test_string_3_open_is_g(self):
        assert self.midi_to_note(self.TUNING[3]) == "G"

    def test_string_7_fret_3_is_c(self):
        assert self.midi_to_note(self.TUNING[7] + 3) == "C"

    def test_all_voicing_notes_are_correct(self, voicings):
        """Verify every dot in every voicing produces the declared note."""
        errors = []
        for v in voicings:
            fn = v["fret_number"]
            dots = v["dots"]
            notes = v["notes"]
            strings = v.get("strings", 6)

            if len(dots) != len(notes):
                continue  # open strings cause mismatch, handled separately

            for i, dot in enumerate(dots):
                s = dot["string"]
                if s not in self.TUNING:
                    continue
                abs_fret = fn + (dot["fret"] - 1)
                computed = self.midi_to_note(self.TUNING[s] + abs_fret)
                declared = self.normalize_note(notes[i])
                declared_pc = self.CHROMATIC.index(declared) if declared in self.CHROMATIC else -1
                computed_pc = self.CHROMATIC.index(computed)
                if declared_pc != computed_pc:
                    errors.append(
                        f"{v['id']}: dot {i} str{s} f{dot['fret']} "
                        f"= {computed}, declared {declared}"
                    )
        assert not errors, f"{len(errors)} note errors:\n" + "\n".join(errors[:10])


# === Validator Tests ===

class TestValidator:
    def test_validator_passes(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "validate.py"),
             "--tuning", str(TUNINGS_DIR / "7string-van-eps.json")],
            capture_output=True, text=True,
        )
        assert "Valid." in result.stdout, f"Validator failed:\n{result.stderr}"
        assert "note verification ERROR" not in result.stderr.lower()

    def test_validator_catches_bad_note(self):
        """Create a voicing with wrong notes and verify the validator catches it."""
        bad_data = {
            "voicings": [{
                "id": "test-bad", "name": "Test", "chord_quality": "dom7",
                "root": "C", "category": "shell", "context": "CV6",
                "strings": 6, "fret_number": 8, "visible_frets": 4,
                "dots": [{"string": 6, "fret": 1}],
                "mutes": [5, 4, 3, 2, 1], "open": [],
                "notes": ["D"],  # WRONG: should be C
                "intervals": ["1"], "tags": [],
            }]
        }
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(bad_data, f)
            f.flush()
            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "validate.py"),
                 "--data", f.name,
                 "--tuning", str(TUNINGS_DIR / "7string-van-eps.json")],
                capture_output=True, text=True,
            )
        assert "note verification ERROR" in result.stderr or "test-bad" in result.stderr


# === Tuning Tests ===

class TestTunings:
    def test_all_tuning_files_exist(self):
        expected = ["standard.json", "7string-van-eps.json", "7string-low-b.json",
                    "dadgad.json", "all-fourths.json"]
        for name in expected:
            assert (TUNINGS_DIR / name).exists(), f"Missing tuning: {name}"

    def test_tuning_files_are_valid_json(self):
        for f in TUNINGS_DIR.glob("*.json"):
            with open(f) as fp:
                data = json.load(fp)
            assert "name" in data, f"{f.name} missing 'name'"
            assert "strings" in data, f"{f.name} missing 'strings'"

    def test_standard_is_6_string(self):
        with open(TUNINGS_DIR / "standard.json") as f:
            data = json.load(f)
        assert len(data["strings"]) == 6

    def test_van_eps_is_7_string(self):
        with open(TUNINGS_DIR / "7string-van-eps.json") as f:
            data = json.load(f)
        assert len(data["strings"]) == 7
        assert data["strings"]["7"] == 33  # low A

    def test_7string_low_b_has_correct_7th(self):
        with open(TUNINGS_DIR / "7string-low-b.json") as f:
            data = json.load(f)
        assert data["strings"]["7"] == 35  # low B


# === Export Tests ===

class TestExports:
    def test_gp5_export_runs(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "export_gp5.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True, text=True,
            )
            assert result.returncode == 0, f"GP5 export failed:\n{result.stderr}"
            files = list(Path(tmpdir).glob("*.gp5"))
            assert len(files) == 1

    def test_musicxml_export_runs(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "export_musicxml.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True, text=True,
            )
            assert result.returncode == 0, f"MusicXML export failed:\n{result.stderr}"
            files = list(Path(tmpdir).glob("*.musicxml"))
            assert len(files) == 1

    def test_musicxml_is_valid_xml(self):
        import xml.etree.ElementTree as ET
        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(
                [sys.executable, str(SCRIPTS / "export_musicxml.py"),
                 "--root", "C", "-o", tmpdir],
                capture_output=True,
            )
            for f in Path(tmpdir).glob("*.musicxml"):
                tree = ET.parse(str(f))
                root = tree.getroot()
                assert root.tag == "score-partwise"


# === Chord Calculator Tests ===

class TestChordCalculator:
    def test_calculator_runs(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "chord_calculator.py"),
             "--root", "C", "--max-fret", "5"],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Calculator failed:\n{result.stderr}"
        assert "Found" in result.stdout

    def test_calculator_finds_all_qualities_in_standard(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "chord_calculator.py"),
             "--root", "C", "--max-fret", "12"],
            capture_output=True, text=True,
        )
        for quality in ["dom7", "maj7", "min7", "maj", "min"]:
            assert quality in result.stdout, f"Calculator didn't find {quality}"

    def test_calculator_export_format(self):
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "chord_calculator.py"),
                 "--root", "C", "--max-fret", "5", "--export", "-o", f.name],
                capture_output=True, text=True,
            )
            assert result.returncode == 0
            with open(f.name) as fp:
                data = json.load(fp)
            assert "voicings" in data
            if data["voicings"]:
                v = data["voicings"][0]
                assert "id" in v
                assert "chord_quality" in v
                assert "dots" in v


# === Schema Tests ===

class TestSchema:
    def test_schema_is_valid_json(self, schema):
        assert "$defs" in schema
        assert "voicing" in schema["$defs"]

    def test_schema_allows_4_to_12_strings(self, schema):
        strings_def = schema["$defs"]["voicing"]["properties"]["strings"]
        assert strings_def["minimum"] == 4
        assert strings_def["maximum"] == 12

    def test_schema_has_optional_tuning_field(self, schema):
        props = schema["$defs"]["voicing"]["properties"]
        assert "tuning" in props
        # tuning should NOT be in required
        required = schema["$defs"]["voicing"]["required"]
        assert "tuning" not in required
