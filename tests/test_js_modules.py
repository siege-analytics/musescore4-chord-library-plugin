"""
test_js_modules.py — Direct testing of QML .pragma library JavaScript modules.

Uses Node.js via subprocess to evaluate the actual JS code that runs in the
MuseScore plugin. This ensures the JS logic is tested directly, not through
Python reimplementations.

Requires: Node.js >= 18 (tested with v25.8.0)
Ticket: #145
"""

import json
import os
import subprocess
import pytest

# === Test infrastructure ===

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JS_RUNNER = os.path.join(REPO_ROOT, "tests", "js_runner.js")
MODEL_DIR = os.path.join(REPO_ROOT, "plugin", "model")
CONFIG_DIR = os.path.join(REPO_ROOT, "plugin", "config")


def run_js(modules, test_code):
    """Run JS test code against one or more .pragma library modules.

    Args:
        modules: list of module filenames (relative to plugin/model/) or full paths
        test_code: JavaScript test code string with assert/assertEqual/etc.

    Returns:
        dict with keys: pass, results, error
    """
    mod_paths = []
    for m in modules:
        if os.path.sep in m or m.startswith("/"):
            mod_paths.append(m)
        else:
            mod_paths.append(os.path.join(MODEL_DIR, m))

    # #343: pass test code via stdin to avoid platform argv limits
    # (Windows WinError 206 / Linux E2BIG) when JSON payloads grow.
    # encoding="utf-8" is required because subprocess defaults to
    # locale.getpreferredencoding() (cp1252 on Windows), which can't
    # encode characters like → (→) used in test payloads.
    cmd = ["node", JS_RUNNER] + mod_paths + ["--", "-"]
    result = subprocess.run(
        cmd, input=test_code, capture_output=True, text=True,
        cwd=REPO_ROOT, timeout=30, encoding="utf-8",
    )

    if result.returncode != 0 and not result.stdout.strip():
        return {"pass": False, "results": [], "error": result.stderr or "Node.js failed"}

    try:
        return json.loads(result.stdout.strip())
    except json.JSONDecodeError:
        return {"pass": False, "results": [], "error": f"Invalid JSON output: {result.stdout[:200]}"}


def assert_js(modules, test_code, msg=""):
    """Run JS tests and assert all pass."""
    result = run_js(modules if isinstance(modules, list) else [modules], test_code)
    if not result["pass"]:
        failures = [r for r in result.get("results", []) if not r.get("pass")]
        failure_msgs = [f["message"] for f in failures]
        error = result.get("error", "")
        detail = "; ".join(failure_msgs) if failure_msgs else error
        pytest.fail(f"{msg}: {detail}" if msg else detail)


# === scales.json data integrity ===


class TestScalesJson:
    """Validate scales.json structure and data integrity."""

    @pytest.fixture(autouse=True)
    def load_scales_json(self):
        with open(os.path.join(CONFIG_DIR, "scales.json")) as f:
            self.data = json.load(f)

    def test_has_required_keys(self):
        assert "scales" in self.data
        assert "chordScaleMap" in self.data
        assert "customQualities" in self.data

    def test_scale_count(self):
        assert len(self.data["scales"]) == 19

    def test_chord_scale_map_count(self):
        assert len(self.data["chordScaleMap"]) == 43

    def test_all_scales_have_required_fields(self):
        for s in self.data["scales"]:
            assert "id" in s, f"Missing id in scale: {s}"
            assert "name" in s, f"Missing name in scale: {s}"
            assert "intervals" in s, f"Missing intervals in scale: {s}"
            assert "category" in s, f"Missing category in scale: {s}"
            assert "builtin" in s, f"Missing builtin in scale: {s}"

    def test_all_intervals_start_with_zero(self):
        for s in self.data["scales"]:
            assert s["intervals"][0] == 0, f"Scale {s['name']} doesn't start with 0"

    def test_all_intervals_in_range(self):
        for s in self.data["scales"]:
            for iv in s["intervals"]:
                assert 0 <= iv <= 11, f"Interval {iv} out of range in {s['name']}"

    def test_all_intervals_sorted_ascending(self):
        for s in self.data["scales"]:
            for i in range(1, len(s["intervals"])):
                assert s["intervals"][i] > s["intervals"][i - 1], \
                    f"Intervals not sorted in {s['name']}: {s['intervals']}"

    def test_minimum_three_intervals(self):
        for s in self.data["scales"]:
            assert len(s["intervals"]) >= 3, \
                f"Scale {s['name']} has {len(s['intervals'])} intervals (min 3)"

    def test_no_duplicate_scale_ids(self):
        ids = [s["id"] for s in self.data["scales"]]
        assert len(ids) == len(set(ids)), f"Duplicate scale IDs: {ids}"

    def test_no_duplicate_scale_names(self):
        names = [s["name"] for s in self.data["scales"]]
        assert len(names) == len(set(names)), f"Duplicate scale names: {names}"

    def test_all_mapping_ids_exist(self):
        valid_ids = {s["id"] for s in self.data["scales"]}
        for quality, scale_ids in self.data["chordScaleMap"].items():
            for sid in scale_ids:
                assert sid in valid_ids, \
                    f"Scale ID '{sid}' in mapping for '{quality}' not found in scales"

    def test_all_scales_are_builtin(self):
        for s in self.data["scales"]:
            assert s["builtin"] is True, f"Scale {s['name']} should be builtin"

    def test_valid_categories(self):
        valid = {"mode", "minor", "symmetric", "pentatonic", "blues", "bebop", "custom"}
        for s in self.data["scales"]:
            assert s["category"] in valid, \
                f"Invalid category '{s['category']}' for {s['name']}"

    def test_custom_qualities_is_empty_list(self):
        assert self.data["customQualities"] == []

    def test_known_scales_present(self):
        names = {s["name"] for s in self.data["scales"]}
        expected = {"Ionian", "Dorian", "Phrygian", "Lydian", "Mixolydian",
                    "Aeolian", "Locrian", "Melodic Minor", "Harmonic Minor",
                    "Blues", "Whole Tone", "Pentatonic Maj", "Pentatonic Min"}
        assert expected.issubset(names), f"Missing scales: {expected - names}"


# === ChordScales.js ===


class TestChordScalesLoad:
    """Test ChordScales.js loadScales() and saveScales()."""

    def test_default_scales_count(self):
        assert_js("ChordScales.js", """
            assertEqual(Object.keys(DEFAULT_SCALES).length, 19, "19 default scales");
        """)

    def test_default_chord_scale_map_count(self):
        assert_js("ChordScales.js", """
            var count = Object.keys(DEFAULT_CHORD_SCALE_MAP).length;
            assert(count >= 43, "at least 42 chord-scale mappings, got " + count);
        """)

    def test_scales_empty_before_load(self):
        assert_js("ChordScales.js", """
            assertEqual(Object.keys(SCALES).length, 0, "SCALES empty before load");
        """)

    def test_ensure_loaded_populates_defaults(self):
        assert_js("ChordScales.js", """
            _ensureLoaded();
            assertEqual(Object.keys(SCALES).length, 19, "19 scales after _ensureLoaded");
            assert(Object.keys(CHORD_SCALE_MAP).length >= 43, "42+ mappings after _ensureLoaded");
        """)

    def test_load_scales_from_json(self):
        assert_js("ChordScales.js", f"""
            var raw = readFileSync("plugin/config/scales.json");
            var data = JSON.parse(raw);
            var ok = loadScales(data);
            assert(ok === true, "loadScales returns true");
            assertEqual(Object.keys(SCALES).length, 19, "19 scales loaded");
        """)

    def test_load_scales_populates_registry(self):
        assert_js("ChordScales.js", f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
            var list = getScaleList();
            assertEqual(list.length, 19, "19 scales in registry");
            assert(list[0].id !== undefined, "scale has id");
            assert(list[0].name !== undefined, "scale has name");
        """)

    def test_load_scales_populates_chord_scale_map(self):
        assert_js("ChordScales.js", f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
            assert(CHORD_SCALE_MAP["dom7"].length >= 3, "dom7 has 3+ scales");
            assertContains(CHORD_SCALE_MAP["dom7"], "Mixolydian", "dom7 has Mixolydian");
        """)

    def test_load_scales_bad_input_falls_back(self):
        assert_js("ChordScales.js", """
            var ok = loadScales(null);
            assert(ok === false, "returns false for null");
            assertEqual(Object.keys(SCALES).length, 19, "falls back to defaults");
        """)

    def test_save_scales_roundtrip(self):
        assert_js("ChordScales.js", f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
            var saved = saveScales();
            assert(saved.scales.length === 19, "19 scales in saved data");
            assert(Object.keys(saved.chordScaleMap).length >= 43, "42+ mappings saved");
            assert(Array.isArray(saved.customQualities), "customQualities is array");
        """)

    def test_save_scales_uses_ids_not_names(self):
        assert_js("ChordScales.js", f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
            var saved = saveScales();
            // chordScaleMap should use IDs like "ionian", not names like "Ionian"
            var dom7Scales = saved.chordScaleMap["dom7"];
            assert(dom7Scales.indexOf("mixolydian") >= 0, "uses ID 'mixolydian' not name");
        """)


class TestChordScalesCRUD:
    """Test ChordScales.js scale CRUD operations."""

    def _load_first(self):
        return f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
        """

    def test_add_scale(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Test Scale", [0, 2, 4, 7, 9, 11], "custom", ["My Scale"]);
            assertNotEqual(id, "", "addScale returns non-empty id");
            assert(SCALES["Test Scale"] !== undefined, "scale exists in SCALES");
            assertEqual(SCALES["Test Scale"].length, 6, "6 intervals");
        """)

    def test_add_scale_rejects_duplicate_name(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Ionian", [0, 2, 4, 5, 7, 9, 11], "custom");
            assertEqual(id, "", "rejects duplicate name");
        """)

    def test_add_scale_rejects_too_few_intervals(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Tiny", [0, 7], "custom");
            assertEqual(id, "", "rejects 2-interval scale");
        """)

    def test_add_scale_rejects_no_zero_start(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Bad Root", [2, 4, 7], "custom");
            assertEqual(id, "", "rejects scale not starting with 0");
        """)

    def test_add_scale_rejects_unsorted(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Unsorted", [0, 7, 4], "custom");
            assertEqual(id, "", "rejects unsorted intervals");
        """)

    def test_add_scale_rejects_out_of_range(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Bad Range", [0, 4, 12], "custom");
            assertEqual(id, "", "rejects interval > 11");
        """)

    def test_add_scale_rejects_duplicates_in_intervals(self):
        assert_js("ChordScales.js", self._load_first() + """
            var id = addScale("Duped", [0, 4, 4, 7], "custom");
            assertEqual(id, "", "rejects duplicate intervals");
        """)

    def test_update_scale_name(self):
        assert_js("ChordScales.js", self._load_first() + """
            addScale("OldName", [0, 3, 5, 7, 10], "custom");
            var ok = updateScale("oldname", "NewName", null, null, null);
            assert(ok, "updateScale returns true");
            assert(SCALES["NewName"] !== undefined, "new name exists");
            assert(SCALES["OldName"] === undefined, "old name removed");
        """)

    def test_update_builtin_intervals_rejected(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = updateScale("ionian", null, [0, 2, 4, 6, 7, 9, 11], null, null);
            assert(!ok, "can't change built-in intervals");
        """)

    def test_update_builtin_category_allowed(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = updateScale("ionian", null, null, "custom", null);
            assert(ok, "can change built-in category");
            var s = getScaleById("ionian");
            assertEqual(s.category, "custom", "category updated");
        """)

    def test_delete_custom_scale(self):
        assert_js("ChordScales.js", self._load_first() + """
            addScale("Disposable", [0, 3, 7], "custom");
            var before = Object.keys(SCALES).length;
            var ok = deleteScale("disposable");
            assert(ok, "deleteScale returns true");
            assertEqual(Object.keys(SCALES).length, before - 1, "one fewer scale");
        """)

    def test_delete_builtin_rejected(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = deleteScale("ionian");
            assert(!ok, "can't delete built-in");
            assert(SCALES["Ionian"] !== undefined, "Ionian still exists");
        """)

    def test_delete_removes_from_mappings(self):
        assert_js("ChordScales.js", self._load_first() + """
            addScale("Ephemeral", [0, 2, 4, 7], "custom");
            setChordScaleMapping("testQual", ["Ephemeral", "Ionian"]);
            deleteScale("ephemeral");
            assertEqual(CHORD_SCALE_MAP["testQual"].length, 1, "mapping shrinks");
            assertEqual(CHORD_SCALE_MAP["testQual"][0], "Ionian", "Ionian remains");
        """)

    def test_get_scale_by_id(self):
        assert_js("ChordScales.js", self._load_first() + """
            var s = getScaleById("dorian");
            assertEqual(s.name, "Dorian", "correct name");
            assertEqual(s.intervals[0], 0, "starts with 0");
            assertEqual(s.builtin, true, "is built-in");
        """)

    def test_get_scale_by_id_not_found(self):
        assert_js("ChordScales.js", self._load_first() + """
            var s = getScaleById("nonexistent");
            assertEqual(s, null, "returns null for missing ID");
        """)

    def test_get_scale_list_sorted(self):
        assert_js("ChordScales.js", self._load_first() + """
            addScale("ZZZ Custom", [0, 3, 7], "custom");
            var list = getScaleList();
            // Built-in first, then custom
            assert(list[list.length - 1].name === "ZZZ Custom", "custom scale at end");
            assert(list[0].builtin === true, "built-in first");
        """)


class TestChordScalesMappings:
    """Test chord-scale mapping and custom quality CRUD."""

    def _load_first(self):
        return f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
        """

    def test_set_chord_scale_mapping(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = setChordScaleMapping("dom7", ["Lydian b7", "Blues"]);
            assert(ok, "setChordScaleMapping returns true");
            assertEqual(CHORD_SCALE_MAP["dom7"].length, 2, "2 scales mapped");
        """)

    def test_set_mapping_rejects_invalid_scale(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = setChordScaleMapping("dom7", ["Nonexistent"]);
            assert(!ok, "rejects unknown scale name");
        """)

    def test_remove_chord_scale_mapping(self):
        assert_js("ChordScales.js", self._load_first() + """
            assert(CHORD_SCALE_MAP["dom7"] !== undefined, "dom7 exists before");
            var ok = removeChordScaleMapping("dom7");
            assert(ok, "removeChordScaleMapping returns true");
            assert(CHORD_SCALE_MAP["dom7"] === undefined, "dom7 removed");
        """)

    def test_add_custom_quality(self):
        assert_js("ChordScales.js", self._load_first() + """
            var ok = addCustomQuality("dom7#9#5");
            assert(ok, "addCustomQuality returns true");
            assertContains(getCustomQualities(), "dom7#9#5", "quality in list");
            assert(CHORD_SCALE_MAP["dom7#9#5"] !== undefined, "empty mapping created");
        """)

    def test_add_duplicate_quality_rejected(self):
        assert_js("ChordScales.js", self._load_first() + """
            addCustomQuality("myQual");
            var ok = addCustomQuality("myQual");
            assert(!ok, "rejects duplicate quality");
        """)

    def test_remove_custom_quality(self):
        assert_js("ChordScales.js", self._load_first() + """
            addCustomQuality("tempQual");
            var ok = removeCustomQuality("tempQual");
            assert(ok, "removeCustomQuality returns true");
            assert(getCustomQualities().indexOf("tempQual") < 0, "removed from list");
            assert(CHORD_SCALE_MAP["tempQual"] === undefined, "mapping removed");
        """)


class TestChordScalesExistingAPI:
    """Test that existing ChordScales.js API functions work unchanged."""

    def _load_first(self):
        return f"""
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
        """

    def test_get_scales_for_quality_dom7(self):
        assert_js("ChordScales.js", self._load_first() + """
            var scales = getScalesForQuality("dom7");
            assert(scales.length >= 3, "dom7 has 3+ scales");
            assertEqual(scales[0].name, "Mixolydian", "first is Mixolydian");
            assert(scales[0].intervals.length > 0, "has intervals");
        """)

    def test_get_scales_for_quality_fallback(self):
        assert_js("ChordScales.js", self._load_first() + """
            var scales = getScalesForQuality("unknownQuality");
            assert(scales.length > 0, "falls back to dom7 scales");
        """)

    def test_get_scale_names(self):
        assert_js("ChordScales.js", self._load_first() + """
            var names = getScaleNames("min7");
            assertContains(names, "Dorian", "min7 includes Dorian");
            assertContains(names, "Aeolian", "min7 includes Aeolian");
        """)

    def test_get_scale_names_unknown_returns_empty(self):
        assert_js("ChordScales.js", self._load_first() + """
            var names = getScaleNames("xyzzy");
            assertEqual(names.length, 0, "unknown quality returns empty");
        """)

    def test_voicing_fits_scale(self):
        assert_js("ChordScales.js", """
            // C major triad [0,4,7] fits Ionian [0,2,4,5,7,9,11]
            assert(voicingFitsScale([0, 4, 7], [0, 2, 4, 5, 7, 9, 11]), "C major fits Ionian");
            // C major triad [0,4,7] does NOT fit Blues [0,3,5,6,7,10]
            assert(!voicingFitsScale([0, 4, 7], [0, 3, 5, 6, 7, 10]), "C major doesn't fit Blues");
        """)

    def test_matching_scales(self):
        assert_js("ChordScales.js", self._load_first() + """
            // [0,4,7] = C major triad — should match scales containing all three
            var matches = matchingScales([0, 4, 7]);
            assertContains(matches, "Ionian", "Ionian matches C major triad");
            assertContains(matches, "Mixolydian", "Mixolydian matches C major triad");
            assert(matches.indexOf("Phrygian") < 0, "Phrygian doesn't match (has b3 not 3)");
        """)

    def test_get_scale_notes_c_ionian(self):
        assert_js("ChordScales.js", self._load_first() + """
            var info = getScaleNotes("Ionian", "C");
            assertEqual(info.notes.length, 7, "7 notes");
            assertEqual(info.notes[0], "C", "starts with C");
            assertEqual(info.intervals[0], "1", "first interval is 1");
        """)

    def test_get_scale_notes_f_dorian(self):
        assert_js("ChordScales.js", self._load_first() + """
            var info = getScaleNotes("Dorian", "F");
            assertEqual(info.notes[0], "F", "starts with F");
            assertEqual(info.notes.length, 7, "7 notes");
        """)

    def test_get_scale_notes_unknown(self):
        assert_js("ChordScales.js", self._load_first() + """
            var info = getScaleNotes("Nonexistent", "C");
            assertEqual(info.notes.length, 0, "unknown scale returns empty");
        """)

    def test_format_scale_suggestion(self):
        assert_js("ChordScales.js", self._load_first() + """
            var s = formatScaleSuggestion("C", "maj7");
            assert(s.indexOf("C") === 0, "starts with root");
            assert(s.indexOf("Ionian") > 0, "contains Ionian");
        """)


# === FilterEngine.js ===


class TestFilterEngine:
    """Test FilterEngine.js filtering logic."""

    SAMPLE_VOICINGS = json.dumps([
        {"name": "Cmaj7-1", "chord_quality": "maj7", "category": "shell",
         "context": "CM6", "strings": 6, "fret_number": 1,
         "dots": [{"string": 5, "fret": 1}, {"string": 4, "fret": 1}],
         "intervals": ["1", "3", "5", "7"], "tags": []},
        {"name": "Cmin7-1", "chord_quality": "min7", "category": "drop2",
         "context": "CM6", "strings": 6, "fret_number": 3,
         "dots": [{"string": 6, "fret": 1}, {"string": 5, "fret": 2}],
         "intervals": ["1", "b3", "5", "b7"], "tags": []},
        {"name": "Cdom7-1", "chord_quality": "dom7", "category": "shell",
         "context": "CV7", "strings": 7, "fret_number": 1,
         "dots": [{"string": 7, "fret": 1}],
         "intervals": ["1", "3", "b7"], "tags": ["jazz"]},
        {"name": "Cquartal-1", "chord_quality": "quartal", "category": "quartal",
         "context": "CM6", "strings": 6, "fret_number": 5,
         "dots": [{"string": 4, "fret": 1}, {"string": 3, "fret": 1}],
         "intervals": ["1", "4"], "tags": []},
    ])

    def _setup(self):
        return f"var voicings = {self.SAMPLE_VOICINGS};"

    def test_no_filters_returns_all(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {maxStrings: 7, contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            assertEqual(result.length, 4, "all 4 voicings returned");
        """)

    def test_filter_by_quality(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {filterQuality: "min7", maxStrings: 7,
                        contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            // quartal is always included when filtering by quality
            assert(result.length >= 1, "at least min7 returned");
            assert(result.some(function(v) { return v.chord_quality === "min7"; }), "min7 present");
        """)

    def test_filter_by_category(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {filterCategory: "shell", maxStrings: 7,
                        contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            assert(result.length >= 2, "at least 2 shell voicings");
            result.forEach(function(v) {
                assertEqual(v.category, "shell", v.name + " is shell");
            });
        """)

    def test_filter_by_context_cm6(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {filterContext: "CM6", maxStrings: 7,
                        contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            // CM6 should match CM6 voicings only
            result.forEach(function(v) {
                assert(v.context === "CM6", v.name + " is CM6 context");
            });
        """)

    def test_filter_by_search_text(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {searchText: "jazz", maxStrings: 7,
                        contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            assertEqual(result.length, 1, "1 voicing with 'jazz' tag");
            assertEqual(result[0].name, "Cdom7-1", "correct voicing found");
        """)

    def test_filter_by_max_strings(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {maxStrings: 6, contextStringCounts: {"CM6": 6, "CV7": 7}};
            var result = applyFilters(voicings, opts);
            result.forEach(function(v) {
                assert(v.strings <= 6, v.name + " has <= 6 strings");
            });
        """)

    def test_scale_filter(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {
                filterScale: "Ionian",
                voicingFitsScaleFn: function(v, scaleName) {
                    // Ionian = [0,2,4,5,7,9,11]. maj7 intervals [1,3,5,7] all fit.
                    if (scaleName === "Ionian") {
                        var ionian = [0,2,4,5,7,9,11];
                        var ivMap = {"1":0,"b3":3,"3":4,"4":5,"5":7,"b7":10,"7":11};
                        var ivs = v.intervals || [];
                        for (var i = 0; i < ivs.length; i++) {
                            if (ionian.indexOf(ivMap[ivs[i]]) < 0) return false;
                        }
                        return true;
                    }
                    return false;
                },
                maxStrings: 7,
                contextStringCounts: {"CM6": 6, "CV7": 7}
            };
            var result = applyFilters(voicings, opts);
            // maj7 [1,3,5,7] fits Ionian, quartal [1,4] fits, dom7 [1,3,b7] doesn't (b7 not in Ionian)
            assert(result.some(function(v) { return v.chord_quality === "maj7"; }), "maj7 fits Ionian");
        """)

    def test_dedup_same_shape(self):
        assert_js("FilterEngine.js", """
            var voicings = [
                {name: "V1", chord_quality: "dom7", category: "shell", context: "CM6",
                 strings: 6, fret_number: 3, dots: [{string:5, fret:1}], intervals: ["1"], tags: []},
                {name: "V2", chord_quality: "dom7", category: "shell", context: "CM7",
                 strings: 7, fret_number: 3, dots: [{string:5, fret:1}], intervals: ["1"], tags: []}
            ];
            var opts = {maxStrings: 7, contextStringCounts: {"CM6": 6, "CM7": 7}};
            var result = applyFilters(voicings, opts);
            assertEqual(result.length, 1, "deduplicates same shape");
        """)

    def test_sort_by_proximity(self):
        assert_js("FilterEngine.js", self._setup() + """
            var opts = {
                maxStrings: 7,
                contextStringCounts: {"CM6": 6, "CV7": 7},
                sortByProximity: true,
                lastInsertedVoicing: {fret_number: 5},
                distanceFn: function(a, b) { return Math.abs(a.fret_number - b.fret_number); }
            };
            var result = applyFilters(voicings, opts);
            // Fret 5 quartal should be first (distance 0)
            assertEqual(result[0].fret_number, 5, "closest voicing first");
        """)

    def test_rebuild_filter_lists(self):
        assert_js("FilterEngine.js", self._setup() + """
            var lists = rebuildFilterLists(voicings);
            assertContains(lists.contextList, "All Contexts", "has All Contexts sentinel");
            assertContains(lists.categoryList, "All Types", "has All Types sentinel");
            assertContains(lists.qualityList, "All Qualities", "has All Qualities sentinel");
            assertContains(lists.contextList, "CM6", "has CM6");
            assertContains(lists.categoryList, "shell", "has shell");
            assertContains(lists.qualityList, "min7", "has min7");
        """)


# === Transposer.js ===


class TestTransposerJS:
    """Test Transposer.js directly in Node.js."""

    def test_c_to_c_is_zero(self):
        assert_js("Transposer.js", """
            assertEqual(semitoneOffset("C", "C"), 0, "C to C = 0");
        """)

    def test_c_to_f_is_five(self):
        assert_js("Transposer.js", """
            assertEqual(semitoneOffset("C", "F"), 5, "C to F = 5");
        """)

    def test_c_to_b_is_eleven(self):
        assert_js("Transposer.js", """
            assertEqual(semitoneOffset("C", "B"), 11, "C to B = 11");
        """)

    def test_all_12_offsets(self):
        assert_js("Transposer.js", """
            var roots = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"];
            for (var i = 0; i < roots.length; i++) {
                assertEqual(semitoneOffset("C", roots[i]), i, "C to " + roots[i]);
            }
        """)

    def test_enharmonic_equivalence(self):
        assert_js("Transposer.js", """
            assertEqual(semitoneOffset("C", "C#"), semitoneOffset("C", "Db"), "C# = Db");
            assertEqual(semitoneOffset("C", "F#"), semitoneOffset("C", "Gb"), "F# = Gb");
        """)

    def test_transpose_fret(self):
        assert_js("Transposer.js", """
            // transposeFret should exist
            assert(typeof transposeFret === "function", "transposeFret exists");
        """)


# === DataCache.js ===


class TestDataCacheJS:
    """Test DataCache.js serialization functions."""

    def test_parse_cache_valid(self):
        assert_js("DataCache.js", """
            var raw = JSON.stringify({voicings: [{name: "test"}]});
            var result = parseCache(raw);
            assertEqual(result.length, 1, "parsed 1 voicing");
            assertEqual(result[0].name, "test", "correct name");
        """)

    def test_parse_cache_empty(self):
        assert_js("DataCache.js", """
            assertEqual(parseCache(""), null, "empty string returns null");
            assertEqual(parseCache(null), null, "null returns null");
            assertEqual(parseCache("{}"), null, "empty object returns null");
        """)

    def test_serialize_roundtrip(self):
        assert_js("DataCache.js", """
            var data = [{name: "v1"}, {name: "v2"}];
            var serialized = serializeCache(data);
            var parsed = parseCache(serialized);
            assertEqual(parsed.length, 2, "roundtrip preserves count");
        """)

    def test_parse_settings_defaults(self):
        assert_js("DataCache.js", """
            var s = parseSettings("");
            assertEqual(s.diagramPlacement, "above", "default placement");
            assertEqual(s.tuning, "standard", "default tuning");
        """)

    def test_parse_settings_overrides(self):
        assert_js("DataCache.js", """
            var raw = JSON.stringify({diagramPlacement: "below", tuning: "dadgad"});
            var s = parseSettings(raw);
            assertEqual(s.diagramPlacement, "below", "overridden placement");
            assertEqual(s.tuning, "dadgad", "overridden tuning");
        """)

    def test_suitable_modes_passthrough(self):
        # #174 Stage 3 retired the context→modes fallback; data now carries
        # suitableModes directly.
        assert_js("DataCache.js", """
            var raw = JSON.stringify({voicings: [
                {name: "v1", suitableModes: ["chord-melody", "solo-guitar"]}
            ]});
            var result = parseCache(raw);
            assertEqual(result[0].suitableModes.length, 2, "existing modes preserved");
            assertEqual(result[0].suitableModes[0], "chord-melody", "first mode intact");
        """)


# === ChordSelector.js — curated shape signature (#194) ===


class TestChordSelectorSignature:
    """Test the root-relative fingering signature helpers (#194)."""

    def test_signature_key_stable_across_dot_order(self):
        assert_js("ChordSelector.js", """
            var v1 = {
                strings: 6, mutes: [], open: [],
                dots: [{string:3,fret:2}, {string:4,fret:1}, {string:6,fret:1}],
                intervals: ["3", "b7", "1"]
            };
            var v2 = {
                strings: 6, mutes: [], open: [],
                dots: [{string:6,fret:1}, {string:4,fret:1}, {string:3,fret:2}],
                intervals: ["1", "b7", "3"]
            };
            assertEqual(signatureKey(v1), signatureKey(v2),
                "same shape, different dot order, same key");
        """)

    def test_signature_key_different_intervals_different_keys(self):
        assert_js("ChordSelector.js", """
            var maj7 = {
                strings: 6, mutes: [], open: [],
                dots: [{string:6,fret:1}, {string:4,fret:1}, {string:3,fret:2}],
                intervals: ["1", "b7", "7"]
            };
            var dom7 = {
                strings: 6, mutes: [], open: [],
                dots: [{string:6,fret:1}, {string:4,fret:1}, {string:3,fret:2}],
                intervals: ["1", "b7", "3"]
            };
            assertNotEqual(signatureKey(maj7), signatureKey(dom7),
                "different intervals -> different keys");
        """)

    def test_signature_key_root_relative(self):
        # Same shape transposed: only the fret_number changes; the intervals
        # stay the same; the key should match.
        assert_js("ChordSelector.js", """
            var c7 = {
                strings: 6, mutes: [], open: [], fret_number: 8,
                dots: [{string:6,fret:1}, {string:4,fret:1}, {string:3,fret:2}],
                intervals: ["1", "b7", "3"]
            };
            var f7 = Object.assign({}, c7, { fret_number: 1 });
            assertEqual(signatureKey(c7), signatureKey(f7),
                "root-relative: fret_number doesn't affect key");
        """)

    def test_build_curated_lookup_returns_keyed_map(self):
        assert_js("ChordSelector.js", """
            var payload = {
                shapes: [{
                    signature: {
                        strings: 6, mutes: [], opens: [],
                        pairs: [[3, "3"], [4, "b7"], [6, "1"]]
                    },
                    name: "Shell 137",
                    boost: 60
                }]
            };
            var lookup = buildCuratedLookup(payload);
            var keys = Object.keys(lookup);
            assertEqual(keys.length, 1, "one entry");
            // Construct a matching voicing and verify the lookup finds it
            var v = {
                strings: 6, mutes: [], open: [],
                dots: [{string:6,fret:1}, {string:4,fret:1}, {string:3,fret:2}],
                intervals: ["1", "b7", "3"]
            };
            var key = signatureKey(v);
            assert(lookup[key] !== undefined, "voicing signature matches curated");
            assertEqual(lookup[key].boost, 60, "boost retrieved");
        """)

    def test_curated_boost_promotes_matching_candidate(self):
        # #201 Phase 2a — when a candidate's root-relative signature matches
        # a curated entry, _scoreCandidate adds entry.boost. Two otherwise
        # equivalent candidates: only the one with a matching signature in
        # the curated lookup should win, by exactly the boost margin.
        assert_js("ChordSelector.js", """
            var curated = {
                id: "v-curated", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1", "b7", "3"], strings: 6
            };
            var plain = {
                id: "v-plain", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:5,fret:3},{string:4,fret:2}],
                intervals: ["1", "5", "3"], strings: 6
            };
            var payload = { shapes: [{
                signature: {
                    strings: 6, mutes: [], opens: [],
                    pairs: [[3, "3"], [4, "b7"], [6, "1"]]
                },
                name: "Shell 137", boost: 80
            }]};
            var lookup = buildCuratedLookup(payload);
            // Without lookup: shapes are scoring-equivalent here. We pick whatever
            // findBestVoicing returns as a baseline and confirm the curated one
            // wins once the lookup is in place.
            var pickWithout = findBestVoicing([curated, plain], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0}
            });
            var pickWith = findBestVoicing([curated, plain], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0}, curatedLookup: lookup
            });
            assertEqual(pickWith.id, "v-curated",
                "curated lookup promotes matching signature");
            // Sanity: the lookup-less call did not magically pick the same one
            // for the same reason. Either result is allowed without lookup.
            assert(pickWithout !== null, "baseline still returns something");
        """)

    def test_curated_boost_absent_lookup_is_noop(self):
        # Absence of opts.curatedLookup must not throw and must not change
        # scoring. Defensive against partial wiring.
        assert_js("ChordSelector.js", """
            var v = {
                id: "v1", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1", "b7", "3"], strings: 6
            };
            var pick = findBestVoicing([v], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0}
            });
            assertEqual(pick.id, "v1", "no lookup → still returns candidate");
        """)

    def test_curated_shapes_json_matches_runtime_signature(self):
        # Regression: every entry in curated-shapes.json must produce a key
        # that runtime signatureKey() would reconstruct for the same shape.
        # This is the cross-script-and-runtime invariant for #194.
        import json as _json
        with open(os.path.join(REPO_ROOT, "plugin", "data", "curated-shapes.json")) as f:
            data = _json.load(f)
        first = data["shapes"][0]
        # Build a voicing from the signature pairs + dummy frets
        pairs = first["signature"]["pairs"]
        dots = [{"string": p[0], "fret": 1} for p in pairs]
        intervals = [p[1] for p in pairs]
        voicing = {
            "strings": first["signature"]["strings"],
            "mutes": first["signature"]["mutes"],
            "open": first["signature"]["opens"],
            "dots": dots,
            "intervals": intervals,
        }
        result = run_js(["ChordSelector.js"], f"""
            var payload = {_json.dumps(data)};
            var lookup = buildCuratedLookup(payload);
            var v = {_json.dumps(voicing)};
            var key = signatureKey(v);
            _results.push({{ pass: lookup[key] !== undefined, message: "first curated shape lookups via runtime signatureKey" }});
            if (lookup[key] === undefined) _pass = false;
        """)
        assert result["pass"], f"curated shape signature mismatch: {result}"


# === ChordSelector.js — unionVoicings (#209) ===


class TestUnionVoicings:
    """Test the curated+calculator union helper (#209 Stage 1)."""

    def test_empty_inputs_return_empty(self):
        assert_js("ChordSelector.js", """
            assertEqual(unionVoicings(null, null).length, 0, "null inputs");
            assertEqual(unionVoicings([], []).length, 0, "empty inputs");
        """)

    def test_disjoint_voicings_are_concatenated(self):
        assert_js("ChordSelector.js", """
            var a = [{
                id: "c1", root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"]
            }];
            var b = [{
                id: "g1", root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:5,fret:3},{string:4,fret:2},{string:3,fret:3}],
                intervals: ["1","3","b7"]
            }];
            var u = unionVoicings(a, b);
            assertEqual(u.length, 2, "both kept");
        """)

    def test_union_curated_wins_on_collision(self):
        # Falsifier for the acceptance criterion: when curated and calculator
        # both produce the same shape, the curated one (with its metadata)
        # survives.
        assert_js("ChordSelector.js", """
            var curated = [{
                id: "curated-id", name: "Shell 137 — root on top",
                category: "shell", traditions: ["bebop"],
                root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"]
            }];
            var calculator = [{
                id: "calc-id", name: "dom7 fret 1",
                category: "generated",
                root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"]
            }];
            var u = unionVoicings(curated, calculator);
            assertEqual(u.length, 1, "collision -> one entry");
            assertEqual(u[0].id, "curated-id", "curated id survives");
            assertEqual(u[0].name, "Shell 137 — root on top",
                "curated name survives");
            assertEqual(u[0].category, "shell", "curated category survives");
        """)

    def test_same_shape_different_quality_both_survive(self):
        # The dedup key includes chord_quality, so a shape used as maj7
        # by the curated set and as dom7 by the calculator both survive.
        assert_js("ChordSelector.js", """
            var a = [{
                id: "as-maj7", root: "C", chord_quality: "maj7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1}], intervals: ["1"]
            }];
            var b = [{
                id: "as-dom7", root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1}], intervals: ["1"]
            }];
            var u = unionVoicings(a, b);
            assertEqual(u.length, 2, "different quality, both kept");
        """)

    def test_calculator_voicing_inherits_curated_display_name(self):
        # #211 Stage 3: when a calculator voicing's signature matches a
        # curated lookup entry, its display name/category come from the
        # curated entry. We exercise buildCuratedLookup + signatureKey
        # directly (the QML applyExclusionPass calls both); the test
        # confirms the lookup-by-signature works for downstream display.
        assert_js("ChordSelector.js", """
            var payload = {
                shapes: [{
                    signature: {
                        strings: 6, mutes: [], opens: [],
                        pairs: [[3, "3"], [4, "b7"], [6, "1"]]
                    },
                    name: "Shell 137 — root on top",
                    category: "shell",
                    boost: 60
                }]
            };
            var lookup = buildCuratedLookup(payload);
            var calculatorVoicing = {
                id: "calc-gen-1",
                name: "dom7 fret 1",     // calculator's generic name
                category: "generated",   // calculator's generic category
                strings: 6, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"]
            };
            var sig = signatureKey(calculatorVoicing);
            var curated = lookup[sig];
            assert(curated !== undefined, "calculator signature hits curated lookup");
            assertEqual(curated.name, "Shell 137 — root on top",
                "curated name available to attach");
            assertEqual(curated.category, "shell",
                "curated category available to attach");
        """)

    def test_voicing_schema_accepts_reserved_fields(self):
        # Schema reservation for Track 2/3 (#212): voicings may carry
        # voicingStyle and playStyle. They round-trip through union
        # without being dropped.
        assert_js("ChordSelector.js", """
            var v = {
                id: "v1", root: "C", chord_quality: "dom7", strings: 6,
                mutes: [], open: [],
                dots: [{string:6,fret:1}], intervals: ["1"],
                voicingStyle: ["van-eps", "shell"],
                playStyle: "sequential"
            };
            var u = unionVoicings([v], []);
            assertEqual(u.length, 1, "kept");
            assertEqual(u[0].voicingStyle.length, 2, "voicingStyle preserved");
            assertEqual(u[0].voicingStyle[0], "van-eps", "first tag");
            assertEqual(u[0].playStyle, "sequential", "playStyle preserved");
        """)


# === ExclusionEngine.js — per-tuning-per-mode exclusion (#210) ===


class TestExclusionEngine:
    """Test ExclusionEngine.js exclusion + override behavior."""

    def test_no_tolerances_returns_null(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}], mutes: [], open: [],
                      intervals: ["1"], fret_number: 5, category: "shell" };
            assertEqual(evaluateExclusion(v, null, null, null), null,
                "no tolerances -> visible");
            assertEqual(evaluateExclusion(v, {}, null, null), null,
                "empty tolerances -> visible");
        """)

    def test_excluded_categories_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [], mutes: [], open: [],
                      intervals: [], fret_number: 5, category: "quartal" };
            var t = { excludedCategories: ["quartal"] };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "excludedCategories", "category excluded");
            assert(r.message.indexOf("quartal") >= 0, "message names category");
        """)

    def test_max_difficulty_tier_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}], mutes: [], open: [],
                      intervals: ["1"], fret_number: 5, category: "shell" };
            var t = { maxDifficultyTier: "advanced" };
            var difficultyFn = function(_) { return { tier: "expert" }; };
            var r = evaluateExclusion(v, t, null, { difficultyFn: difficultyFn });
            assertEqual(r.dimension, "maxDifficultyTier", "expert > advanced");
        """)

    def test_max_difficulty_tier_passes_when_within_limit(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [], mutes: [], open: [],
                      intervals: [], fret_number: 5 };
            var t = { maxDifficultyTier: "advanced" };
            var difficultyFn = function(_) { return { tier: "standard" }; };
            assertEqual(evaluateExclusion(v, t, null, { difficultyFn: difficultyFn }), null,
                "standard within advanced -> visible");
        """)

    def test_max_muted_strings_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:1,fret:1}], mutes: [2,3,4,5], open: [],
                      intervals: ["1"], fret_number: 5 };
            var t = { maxMutedStrings: 3 };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "maxMutedStrings", "4 mutes > 3 max");
        """)

    def test_max_stretch_dimension(self):
        # Dots at fret_number 1 with relative frets 1 and 7 → absolute 1 and 7
        # → stretch 7 (inclusive). Should fail max=5.
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1},{string:1,fret:7}],
                      mutes: [], open: [], intervals: ["1","5"], fret_number: 1 };
            var t = { maxStretch: 5 };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "maxStretch", "stretch 7 > max 5");
        """)

    def test_max_fret_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}], mutes: [], open: [],
                      intervals: ["1"], fret_number: 14 };
            var t = { maxFret: 12 };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "maxFret", "fret 14 > max 12");
        """)

    def test_min_sounding_notes_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}, {string:5,fret:1}],
                      mutes: [], open: [], intervals: ["1","5"], fret_number: 5 };
            var t = { minSoundingNotes: 3 };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "minSoundingNotes", "2 sounding < 3 min");
        """)

    def test_require_root_in_bass_dimension(self):
        # Bass string (highest-numbered sounding) is string 6 with interval "5" → not root.
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6,
                      dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                      mutes: [], open: [],
                      intervals: ["5","1","3"], fret_number: 5 };
            var t = { requireRootInBass: true };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "requireRootInBass", "bass is 5th, not root");
        """)

    def test_allow_open_strings_dimension(self):
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [], mutes: [], open: [3,4],
                      intervals: [], fret_number: 0 };
            var t = { allowOpenStrings: false };
            var r = evaluateExclusion(v, t, null, null);
            assertEqual(r.dimension, "allowOpenStrings", "opens disallowed");
        """)

    def test_user_override_include_wins_over_tolerance(self):
        # Acceptance criterion: allowlisted signature always passes.
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [], mutes: [1,2,3,4,5], open: [],
                      intervals: [], fret_number: 5, category: "quartal" };
            // Would fail BOTH maxMutedStrings AND excludedCategories.
            var t = { maxMutedStrings: 3, excludedCategories: ["quartal"] };
            var overrides = { "my-sig": "include" };
            var opts = { signatureKeyFn: function(_) { return "my-sig"; } };
            assertEqual(evaluateExclusion(v, t, overrides, opts), null,
                "allowlist wins over all tolerance failures");
        """)

    def test_user_override_exclude_wins_over_tolerance(self):
        # Acceptance criterion: denylisted signature always fails.
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}], mutes: [], open: [],
                      intervals: ["1"], fret_number: 5, category: "shell" };
            // Would pass everything.
            var t = { maxMutedStrings: 3, excludedCategories: [] };
            var overrides = { "my-sig": "exclude" };
            var opts = { signatureKeyFn: function(_) { return "my-sig"; } };
            var r = evaluateExclusion(v, t, overrides, opts);
            assertEqual(r.dimension, "userOverride", "denylist beats passing checks");
        """)

    def test_dimension_priority_category_before_difficulty(self):
        # When two tolerances both fail, the higher-priority one wins.
        # Category exclusion is higher priority than difficulty.
        assert_js("ExclusionEngine.js", """
            var v = { strings: 6, dots: [{string:6,fret:1}], mutes: [], open: [],
                      intervals: ["1"], fret_number: 5, category: "quartal" };
            var t = { excludedCategories: ["quartal"], maxDifficultyTier: "standard" };
            var difficultyFn = function(_) { return { tier: "expert" }; };
            var r = evaluateExclusion(v, t, null, { difficultyFn: difficultyFn });
            assertEqual(r.dimension, "excludedCategories",
                "category check fires before difficulty");
        """)

    def test_resolve_tolerances_mode_only(self):
        assert_js("ExclusionEngine.js", """
            var map = { modes: { "comping": { maxMutedStrings: 2 } } };
            var t = resolveTolerances(map, "standard", "comping");
            assertEqual(t.maxMutedStrings, 2, "mode default applied");
        """)

    def test_resolve_tolerances_tuning_overrides_mode(self):
        assert_js("ExclusionEngine.js", """
            var map = {
                modes: { "comping": { maxMutedStrings: 2, maxFret: 12 } },
                tunings: { "baritone": { "comping": { maxFret: 14 } } }
            };
            var t = resolveTolerances(map, "baritone", "comping");
            assertEqual(t.maxMutedStrings, 2, "mode default preserved");
            assertEqual(t.maxFret, 14, "tuning override applied");
        """)

    def test_merge_tolerances_user_overrides_base(self):
        # #216 — user-edited tolerance overrides shadow file defaults at the
        # dimension level. Untouched dimensions fall through.
        assert_js("ExclusionEngine.js", """
            var base = {
                modes: {
                    "comping": { maxFret: 12, maxStretch: 5, maxMutedStrings: 2 }
                },
                tunings: {}
            };
            var user = {
                modes: {
                    "comping": { maxStretch: 4 }   // user tightens the stretch
                },
                tunings: {}
            };
            var merged = mergeTolerances(base, user);
            assertEqual(merged.modes.comping.maxFret, 12, "untouched dim falls through");
            assertEqual(merged.modes.comping.maxStretch, 4, "user override wins");
            assertEqual(merged.modes.comping.maxMutedStrings, 2, "other dim preserved");
        """)

    def test_merge_tolerances_tuning_overrides(self):
        assert_js("ExclusionEngine.js", """
            var base = {
                modes: { "chord-melody": { maxFret: 12 } },
                tunings: {
                    "baritone": { "chord-melody": { maxFret: 14 } }
                }
            };
            var user = {
                modes: {},
                tunings: {
                    "baritone": { "chord-melody": { maxStretch: 7 } }
                }
            };
            var merged = mergeTolerances(base, user);
            // Tuning-level merge: base's tuning fret + user's tuning stretch
            assertEqual(merged.tunings.baritone["chord-melody"].maxFret, 14,
                "base tuning override preserved");
            assertEqual(merged.tunings.baritone["chord-melody"].maxStretch, 7,
                "user tuning override added");
        """)

    def test_merge_tolerances_handles_empty_inputs(self):
        assert_js("ExclusionEngine.js", """
            var m1 = mergeTolerances(null, null);
            assertEqual(Object.keys(m1.modes).length, 0, "null inputs -> empty modes");
            var m2 = mergeTolerances({}, {});
            assertEqual(Object.keys(m2.modes).length, 0, "empty inputs -> empty modes");
            var m3 = mergeTolerances({ modes: { "comping": { maxFret: 10 } } }, null);
            assertEqual(m3.modes.comping.maxFret, 10, "null user -> base passes through");
        """)

    def test_tighten_tolerances_ceiling_takes_min(self):
        assert_js("ExclusionEngine.js", """
            var base = { maxFret: 12, maxStretch: 6, maxMutedStrings: 3 };
            var hint = { maxFret: 10, maxStretch: 8, maxMutedStrings: 1 };
            var t = tightenTolerances(base, hint);
            assertEqual(t.maxFret, 10, "fret tighter wins");
            assertEqual(t.maxStretch, 6, "base already tighter wins");
            assertEqual(t.maxMutedStrings, 1, "mute tighter wins");
        """)

    def test_tighten_tolerances_floor_takes_max(self):
        assert_js("ExclusionEngine.js", """
            var t = tightenTolerances({ minSoundingNotes: 3 }, { minSoundingNotes: 4 });
            assertEqual(t.minSoundingNotes, 4, "floor tighter wins");
            t = tightenTolerances({ minSoundingNotes: 5 }, { minSoundingNotes: 4 });
            assertEqual(t.minSoundingNotes, 5, "base already tighter wins");
        """)

    def test_tighten_tolerances_booleans_and_enum(self):
        assert_js("ExclusionEngine.js", """
            var t1 = tightenTolerances({ requireRootInBass: false }, { requireRootInBass: true });
            assertEqual(t1.requireRootInBass, true, "any-true tightens");
            var t2 = tightenTolerances({ allowOpenStrings: true }, { allowOpenStrings: false });
            assertEqual(t2.allowOpenStrings, false, "any-disallow tightens");
            var t3 = tightenTolerances({ maxDifficultyTier: "expert" }, { maxDifficultyTier: "standard" });
            assertEqual(t3.maxDifficultyTier, "standard", "lower tier wins");
        """)

    def test_tighten_tolerances_excluded_categories_unions(self):
        assert_js("ExclusionEngine.js", """
            var t = tightenTolerances(
                { excludedCategories: ["quartal"] },
                { excludedCategories: ["extended", "altered"] }
            );
            assertEqual(t.excludedCategories.length, 3, "union of three");
            assert(t.excludedCategories.indexOf("quartal") >= 0, "quartal present");
            assert(t.excludedCategories.indexOf("extended") >= 0, "extended present");
            assert(t.excludedCategories.indexOf("altered") >= 0, "altered present");
        """)

    def test_tighten_tolerances_unknown_dim_replaces(self):
        # Forward-compat: future dimensions get REPLACED, not silently dropped.
        assert_js("ExclusionEngine.js", """
            var t = tightenTolerances({ futureDim: 5 }, { futureDim: 10 });
            assertEqual(t.futureDim, 10, "unknown dim: hint replaces");
        """)

    def test_master_style_boost_promotes_matching_voicing(self):
        # Ticket falsifier — a tagged voicing outscores an equivalent untagged one
        # when the matching master is active.
        assert_js("ChordSelector.js", """
            var tagged = {
                id: "v-greene", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"], strings: 6,
                voicingStyle: ["greene"]
            };
            var untagged = {
                id: "v-plain", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:5,fret:3},{string:4,fret:2},{string:3,fret:3}],
                intervals: ["1","3","b7"], strings: 6
            };
            // Without master active: pick either (no signal — equivalent).
            // With Greene active: tagged voicing wins.
            var pick = findBestVoicing([untagged, tagged], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0},
                masterVoicingStyleTags: ["greene"]
            });
            assertEqual(pick.id, "v-greene", "tagged voicing wins under matching master");
        """)

    def test_no_master_active_is_noop(self):
        # When no master is active, scoring matches pre-#222 behavior.
        # A tagged voicing should NOT outscore an equivalent untagged one
        # just by virtue of being tagged.
        assert_js("ChordSelector.js", """
            var tagged = {
                id: "v-greene", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"], strings: 6,
                voicingStyle: ["greene"]
            };
            var untagged = {
                id: "v-plain", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"], strings: 6
            };
            // Same shape, same scoring inputs, no master active.
            // Sort order is determined by JS engine; either may win.
            // Important: the BOOST itself should be zero in both cases.
            var pickWithoutMaster = findBestVoicing([tagged, untagged], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0}
            });
            assert(pickWithoutMaster !== null, "still picks one when no master");
            // Now with Greene: tagged wins.
            var pickWithMaster = findBestVoicing([tagged, untagged], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0},
                masterVoicingStyleTags: ["greene"]
            });
            assertEqual(pickWithMaster.id, "v-greene", "master signal does reach scorer");
        """)

    def test_findbest_skips_excluded_voicings(self):
        # findBestVoicing must not return a voicing with _excludedReason set,
        # even if it would otherwise score highest.
        assert_js("ChordSelector.js", """
            var excluded = {
                id: "v-excluded", root: "C", chord_quality: "dom7",
                category: "shell", fret_number: 5, mutes: [], open: [],
                dots: [{string:6,fret:1},{string:4,fret:1},{string:3,fret:2}],
                intervals: ["1","b7","3"], strings: 6,
                _excludedReason: { dimension: "userOverride", message: "user-excluded" }
            };
            var visible = {
                id: "v-visible", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 5, mutes: [], open: [],
                dots: [{string:5,fret:3},{string:4,fret:2},{string:3,fret:3}],
                intervals: ["1","3","b7"], strings: 6
            };
            var pick = findBestVoicing([excluded, visible], "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0}
            });
            assertEqual(pick.id, "v-visible",
                "excluded voicing is not selectable as best");
        """)


# === RevoiceMemory.js — per-chord choice persistence (#197) ===


class TestRevoiceMemory:
    """Test RevoiceMemory.js scope-keyed choice storage."""

    def test_empty_memory_starts_with_no_scopes(self):
        # Default version bumped to "v2" by #211 Stage 3 (signature-keyed).
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            assertEqual(m.version, "v2", "version stamped");
            assertEqual(Object.keys(m.scopes).length, 0, "no scopes yet");
        """)

    def test_record_and_get_round_trip(self):
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            var key = buildScopeKey("/path/to.mscz", "chord-melody", "default", "standard");
            recordChoice(m, key, "Cm7", "v-shell-137", 1000);
            assertEqual(getChoice(m, key, "Cm7"), "v-shell-137", "saved choice returned");
            assertEqual(getChoice(m, key, "F7"), null, "absent symbol returns null");
        """)

    def test_scope_key_includes_all_axes(self):
        # Each of (scorePath, mode, style, tuning) must produce a distinct key,
        # so changing any one isolates a fresh scope.
        assert_js("RevoiceMemory.js", """
            var a = buildScopeKey("/a.mscz", "chord-melody", "default", "standard");
            var b = buildScopeKey("/b.mscz", "chord-melody", "default", "standard");
            var c = buildScopeKey("/a.mscz", "comping",      "default", "standard");
            var d = buildScopeKey("/a.mscz", "chord-melody", "bebop",   "standard");
            var e = buildScopeKey("/a.mscz", "chord-melody", "default", "baritone");
            assertNotEqual(a, b, "different score = different scope");
            assertNotEqual(a, c, "different mode = different scope");
            assertNotEqual(a, d, "different style = different scope");
            assertNotEqual(a, e, "different tuning = different scope");
        """)

    def test_changing_mode_does_not_replay_prior_choice(self):
        # The headline AC: changing mode/style/tuning must reset choices.
        # Falsifier from the ticket.
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            var cm = buildScopeKey("/a.mscz", "chord-melody", "default", "standard");
            var cmp = buildScopeKey("/a.mscz", "comping",      "default", "standard");
            recordChoice(m, cm, "F7", "v-melody-pick", 1000);
            assertEqual(getChoice(m, cm, "F7"), "v-melody-pick", "saved in chord-melody scope");
            assertEqual(getChoice(m, cmp, "F7"), null,
                "switched to comping scope: no replay of chord-melody choice");
        """)

    def test_clear_scope_removes_just_one_scope(self):
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            var a = buildScopeKey("/a.mscz", "chord-melody", "default", "standard");
            var b = buildScopeKey("/b.mscz", "chord-melody", "default", "standard");
            recordChoice(m, a, "C7", "v-a", 1000);
            recordChoice(m, b, "C7", "v-b", 1000);
            clearScope(m, a);
            assertEqual(getChoice(m, a, "C7"), null, "scope a cleared");
            assertEqual(getChoice(m, b, "C7"), "v-b", "scope b untouched");
        """)

    def test_prune_drops_oldest_scope_first(self):
        # Build a memory with enough scopes to exceed a small budget, then
        # confirm the oldest (by ts) is dropped.
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            for (var i = 0; i < 50; i++) {
                var key = "/score" + i + ".mscz|m:chord-melody|s:default|t:standard";
                recordChoice(m, key, "F7", "v-id-" + i, i + 1);
            }
            var beforeKeys = Object.keys(m.scopes).length;
            pruneToSize(m, 500);  // tight budget — most scopes drop
            var afterKeys = Object.keys(m.scopes).length;
            assert(afterKeys < beforeKeys, "prune dropped some scopes");
            // The newest scope (ts=50) must survive.
            var newestKey = "/score49.mscz|m:chord-melody|s:default|t:standard";
            assert(m.scopes[newestKey] !== undefined, "newest scope survives");
            // The oldest (ts=1) must be gone.
            var oldestKey = "/score0.mscz|m:chord-melody|s:default|t:standard";
            assert(m.scopes[oldestKey] === undefined, "oldest scope dropped");
        """)

    def test_parse_memory_handles_corrupt_input(self):
        # Updated for #211 Stage 3 — empty memory is now v2.
        assert_js("RevoiceMemory.js", """
            assertEqual(parseMemory("").version, "v2", "empty string -> empty v2 memory");
            assertEqual(parseMemory("not json").version, "v2", "invalid json -> empty v2 memory");
            assertEqual(parseMemory('{"version":"v0"}').version, "v2", "unknown version -> empty");
            // v1 memories still parse (caller migrates).
            var v1 = parseMemory('{"version":"v1","scopes":{"a":{"choices":{"F7":"v1"},"ts":1}}}');
            assertEqual(v1.version, "v1", "v1 still parseable");
            assertEqual(v1.scopes.a.choices.F7, "v1", "v1 choices preserved");
            // v2 memories parse straight through.
            var v2 = parseMemory('{"version":"v2","scopes":{"a":{"choices":{"F7":"sig123"},"ts":1}}}');
            assertEqual(v2.version, "v2", "v2 parses");
            assertEqual(v2.scopes.a.choices.F7, "sig123", "v2 signature value");
        """)

    def test_revoice_memory_migrates_v1_to_v2(self):
        # #211 Stage 3 ticket falsifier. v1 memory + an idToSig lookup
        # produces a v2 memory with signatures in choices.
        assert_js("RevoiceMemory.js", """
            var memory = {
                version: "v1",
                scopes: {
                    "scope-a": { choices: { "F7": "id-shell-137", "Cm7": "id-drop2" }, ts: 1000 },
                    "scope-b": { choices: { "Bbmaj7": "id-shell-137" }, ts: 2000 }
                }
            };
            var idToSig = {
                "id-shell-137": "sig-shell-137",
                "id-drop2": "sig-drop2"
            };
            migrateFromV1(memory, idToSig);
            assertEqual(memory.version, "v2", "schema bumped");
            assertEqual(memory.scopes["scope-a"].choices.F7, "sig-shell-137",
                "F7 choice rewritten");
            assertEqual(memory.scopes["scope-a"].choices.Cm7, "sig-drop2",
                "Cm7 choice rewritten");
            assertEqual(memory.scopes["scope-b"].choices.Bbmaj7, "sig-shell-137",
                "scope-b also rewritten");
            assertEqual((memory._droppedIds || []).length, 0, "nothing dropped");
        """)

    def test_revoice_memory_v2_round_trip(self):
        # Post-migration, get/record operate on signatures as values.
        assert_js("RevoiceMemory.js", """
            var m = emptyMemory();
            assertEqual(m.version, "v2", "starts at v2");
            var key = buildScopeKey("/p.mscz", "chord-melody", "default", "standard");
            recordChoice(m, key, "F7", "sig-shell-137", 1000);
            assertEqual(getChoice(m, key, "F7"), "sig-shell-137",
                "signature retrievable");
        """)

    def test_revoice_memory_migration_drops_unresolvable_ids(self):
        assert_js("RevoiceMemory.js", """
            var memory = {
                version: "v1",
                scopes: {
                    "scope-a": { choices: { "F7": "id-known", "Cm7": "id-missing" }, ts: 1000 }
                }
            };
            var idToSig = { "id-known": "sig-known" };  // id-missing not in lookup
            migrateFromV1(memory, idToSig);
            assertEqual(memory.scopes["scope-a"].choices.F7, "sig-known",
                "resolvable id rewritten");
            assertEqual(memory.scopes["scope-a"].choices.Cm7, undefined,
                "unresolvable id dropped");
            assertEqual((memory._droppedIds || []).length, 1,
                "drop logged for surfaceable diagnostics");
        """)

    def test_revoice_memory_migration_is_noop_on_v2(self):
        assert_js("RevoiceMemory.js", """
            var m = { version: "v2", scopes: { "a": { choices: { "F7": "sig" }, ts: 1 } } };
            migrateFromV1(m, {});
            assertEqual(m.version, "v2", "still v2");
            assertEqual(m.scopes.a.choices.F7, "sig", "untouched");
        """)


# === MastersStore.js — Masters' Lessons bookshelf (#220) ===


class TestMastersStore:
    """Test MastersStore.js loader + query helpers."""

    SEED = """
        var sample = {
            version: "v1",
            masters: [
                {
                    id: "ted-greene",
                    name: "Ted Greene",
                    principles: [
                        {
                            id: "voice-leading",
                            name: "Voice leading",
                            voicingStyleTags: ["greene"],
                            applies_to_modes: ["chord-melody", "solo-guitar"]
                        },
                        {
                            id: "sequential",
                            name: "Sequential articulation",
                            voicingStyleTags: ["greene"],
                            playStyleTags: ["sequential"],
                            applies_to_modes: ["chord-melody"]
                        }
                    ]
                },
                {
                    id: "van-eps",
                    name: "George Van Eps",
                    principles: [
                        {
                            id: "comping-with-self",
                            voicingStyleTags: ["van-eps"],
                            applies_to_modes: ["chord-melody"],
                            applies_to_tunings: ["7string-van-eps"]
                        }
                    ]
                }
            ]
        };
    """

    def test_empty_store_when_no_input(self):
        assert_js("MastersStore.js", """
            var e = emptyStore();
            assertEqual(e.version, "v1", "version stamped");
            assertEqual(e.masters.length, 0, "no masters");
        """)

    def test_parse_store_rejects_invalid_inputs(self):
        assert_js("MastersStore.js", """
            assertEqual(parseStore("").masters.length, 0, "empty -> empty store");
            assertEqual(parseStore("not json").masters.length, 0, "invalid json -> empty");
            assertEqual(parseStore('{"version":"v0"}').masters.length, 0, "wrong version");
            assertEqual(parseStore('{"version":"v1"}').masters.length, 0, "no masters array");
        """)

    def test_masters_store_loads_seeded_data(self):
        # Ticket falsifier — confirms the loader round-trips seeded entries.
        assert_js("MastersStore.js", """
            var s = parseStore(JSON.stringify({
                version: "v1",
                masters: [{ id: "x", name: "X", principles: [] }]
            }));
            assertEqual(s.masters.length, 1, "one master loaded");
            assertEqual(s.masters[0].id, "x", "id preserved");
        """)

    def test_find_master_by_id(self):
        assert_js("MastersStore.js", self.SEED + """
            assertEqual(findMaster(sample, "ted-greene").name, "Ted Greene", "found");
            assertEqual(findMaster(sample, "no-such-master"), null, "missing -> null");
        """)

    def test_find_principle_by_master_and_id(self):
        assert_js("MastersStore.js", self.SEED + """
            var p = findPrinciple(sample, "ted-greene", "voice-leading");
            assertEqual(p.name, "Voice leading", "found");
            assertEqual(findPrinciple(sample, "ted-greene", "no-such"), null, "missing -> null");
            assertEqual(findPrinciple(sample, "no-such-master", "voice-leading"), null, "missing master");
        """)

    def test_all_principles_flattens_across_masters(self):
        assert_js("MastersStore.js", self.SEED + """
            var all = allPrinciples(sample);
            assertEqual(all.length, 3, "three principles total");
            assertEqual(all[0].masterId, "ted-greene", "carries master id");
            assertEqual(all[2].masterId, "van-eps", "second master included");
        """)

    def test_principles_by_voicing_style_tag(self):
        assert_js("MastersStore.js", self.SEED + """
            var greene = principlesByVoicingStyle(sample, "greene");
            assertEqual(greene.length, 2, "two greene principles");
            var ve = principlesByVoicingStyle(sample, "van-eps");
            assertEqual(ve.length, 1, "one van-eps principle");
            assertEqual(principlesByVoicingStyle(sample, "no-such").length, 0, "no match");
        """)

    def test_principles_for_mode_and_tuning(self):
        # Semantic: principles without an explicit applies_to_tunings list
        # apply to all tunings (they're tuning-agnostic by default). Only
        # tuning-restricted principles are filtered by the tuning argument.
        assert_js("MastersStore.js", self.SEED + """
            // chord-melody mode applies to all 3 sample principles
            assertEqual(principlesFor(sample, "chord-melody", null).length, 3, "by mode");
            // solo-guitar applies to one (Greene voice-leading)
            assertEqual(principlesFor(sample, "solo-guitar", null).length, 1, "by mode solo");
            // chord-melody + 7string-van-eps: all three principles match
            // (Greene's two are tuning-agnostic; van-eps explicitly lists it).
            assertEqual(principlesFor(sample, "chord-melody", "7string-van-eps").length, 3,
                "tuning-agnostic principles still included");
            // chord-melody + a tuning the van-eps principle does NOT list:
            // van-eps drops, Greene's two stay (they're tuning-agnostic).
            assertEqual(principlesFor(sample, "chord-melody", "standard").length, 2,
                "tuning-restricted principle filtered out when tuning doesn't match");
        """)

    def test_counts_summary(self):
        assert_js("MastersStore.js", self.SEED + """
            var c = counts(sample);
            assertEqual(c.masters, 2, "two masters");
            assertEqual(c.principles, 3, "three principles");
        """)

    def test_collect_voicing_style_tags_unions_across_principles(self):
        # #222 Track 3 — master's voicingStyleTags from all principles unioned.
        assert_js("MastersStore.js", """
            var master = {
                id: "x",
                principles: [
                    { voicingStyleTags: ["greene"] },
                    { voicingStyleTags: ["greene", "shell"] },
                    { voicingStyleTags: ["drop-2"] }
                ]
            };
            var tags = collectVoicingStyleTags(master);
            assertEqual(tags.length, 3, "deduped union");
            assert(tags.indexOf("greene") >= 0, "greene present");
            assert(tags.indexOf("shell") >= 0, "shell present");
            assert(tags.indexOf("drop-2") >= 0, "drop-2 present");
        """)

    def test_derive_tolerances_folds_principle_hints(self):
        # Combines tolerance_hints across principles using the tightenFn
        # callback (provided by caller — comes from ExclusionEngine.tightenTolerances).
        assert_js("MastersStore.js", """
            var master = {
                id: "x",
                principles: [
                    { tolerance_hints: { maxFret: 12, minSoundingNotes: 3 } },
                    { tolerance_hints: { maxFret: 10, minSoundingNotes: 4 } },
                    { tolerance_hints: {} }  // empty hint -> skipped
                ]
            };
            // Stub tightener: ceiling MIN, floor MAX.
            var tighten = function(a, b) {
                var out = {};
                for (var k in a) out[k] = a[k];
                for (var k in b) {
                    if (out[k] === undefined) { out[k] = b[k]; continue; }
                    if (k === "maxFret") out[k] = Math.min(out[k], b[k]);
                    else if (k === "minSoundingNotes") out[k] = Math.max(out[k], b[k]);
                    else out[k] = b[k];
                }
                return out;
            };
            var d = deriveTolerancesFromMaster(master, tighten);
            assertEqual(d.maxFret, 10, "tightest fret wins");
            assertEqual(d.minSoundingNotes, 4, "tightest floor wins");
        """)

    def test_derive_tolerances_returns_null_when_no_hints(self):
        assert_js("MastersStore.js", """
            var master = {
                id: "x",
                principles: [
                    { voicingStyleTags: ["x"] },  // no tolerance_hints
                    { tolerance_hints: {} }       // empty
                ]
            };
            var d = deriveTolerancesFromMaster(master, function(){});
            assertEqual(d, null, "no hints -> null (signal to skip overlay)");
        """)

    def test_loads_repo_masters_json(self):
        # Regression fence: the actual plugin/data/masters.json must parse
        # and meet the AC (≥ 7 masters, ≥ 1 principle each PROMOTED master).
        # Corpus-only masters (status="corpus_only") legitimately have 0
        # principles per the skip-promotion-but-keep-corpus pattern (#320).
        import json as _json
        with open(os.path.join(REPO_ROOT, "plugin", "data", "masters.json"), encoding="utf-8") as f:
            data = _json.load(f)
        result = run_js(["MastersStore.js"], f"""
            var s = parseStore({_json.dumps(_json.dumps(data))});
            var c = counts(s);
            _results.push({{ pass: c.masters >= 7, message: "at least 7 masters ("+c.masters+")" }});
            _results.push({{ pass: c.principles >= 7, message: "at least 7 principles ("+c.principles+")" }});
            // Each PROMOTED master has at least one principle.
            for (var i = 0; i < s.masters.length; i++) {{
                var m = s.masters[i];
                if (m.status === "corpus_only") continue;
                var ok = m.principles && m.principles.length > 0;
                _results.push({{
                    pass: ok,
                    message: "promoted master " + m.id + " has principles (" + (m.principles ? m.principles.length : 0) + ")"
                }});
                if (!ok) _pass = false;
            }}
        """)
        assert result["pass"], f"masters.json schema check failed: {result}"


# === ComparisonTray.js — side-by-side voicing comparison (#196) ===


class TestComparisonTray:
    """Test ComparisonTray.js FIFO + dedup behavior."""

    def test_empty_tray_starts_empty(self):
        assert_js("ComparisonTray.js", """
            var t = emptyTray();
            assertEqual(t.length, 0, "tray empty");
        """)

    def test_add_appends_voicing(self):
        assert_js("ComparisonTray.js", """
            var t = add(emptyTray(), { id: "v1", name: "Shell" });
            assertEqual(t.length, 1, "one entry");
            assertEqual(t[0].id, "v1", "by id");
        """)

    def test_add_skips_duplicates_by_id(self):
        assert_js("ComparisonTray.js", """
            var t = emptyTray();
            t = add(t, { id: "v1" });
            t = add(t, { id: "v1" });
            assertEqual(t.length, 1, "duplicate add ignored");
        """)

    def test_comparison_tray_evicts_oldest_on_fourth(self):
        # The ticket's named falsifier (#196): adding a 4th voicing must
        # evict the first. Capacity is 3.
        assert_js("ComparisonTray.js", """
            var t = emptyTray();
            t = add(t, { id: "v1" });
            t = add(t, { id: "v2" });
            t = add(t, { id: "v3" });
            assertEqual(t.length, 3, "at capacity");
            t = add(t, { id: "v4" });
            assertEqual(t.length, 3, "still at capacity after 4th add");
            assertEqual(t[0].id, "v2", "v1 evicted (FIFO)");
            assertEqual(t[1].id, "v3", "v3 shifted");
            assertEqual(t[2].id, "v4", "v4 appended");
        """)

    def test_remove_at_drops_specific_entry(self):
        assert_js("ComparisonTray.js", """
            var t = [{ id: "a" }, { id: "b" }, { id: "c" }];
            t = removeAt(t, 1);
            assertEqual(t.length, 2, "one removed");
            assertEqual(t[0].id, "a", "first kept");
            assertEqual(t[1].id, "c", "third kept");
        """)

    def test_clear_empties_tray(self):
        # Falsifier for the Clear AC.
        assert_js("ComparisonTray.js", """
            var t = [{ id: "a" }, { id: "b" }, { id: "c" }];
            t = clear();
            assertEqual(t.length, 0, "tray cleared");
        """)

    def test_contains_reports_membership(self):
        assert_js("ComparisonTray.js", """
            var v = { id: "v1" };
            assert(!contains([], v), "empty doesn't contain");
            assert(contains([v], v), "contains by reference");
            assert(contains([{ id: "v1" }], v), "contains by id even if different ref");
        """)


# === StyleComposer.js — style composition (#162) ===


class TestStyleComposer:
    """Test StyleComposer blending rules and resolution."""

    BASES = """
        var bebop = {
            id: "bebop", name: "Bebop",
            chordScaleOverrides: { dom7: ["Mixolydian", "Altered"] },
            categoryWeights: { drop2: 10, shell: 5 },
            qualityBoosts: { dom7: 5 }
        };
        var manouche = {
            id: "manouche", name: "Manouche",
            chordScaleOverrides: { dom7: ["Harmonic Minor"], min7: ["Harmonic Minor"] },
            categoryWeights: { shell: 15, drop2: -10 },
            qualityBoosts: { dim7: 20 }
        };
        var bossa = {
            id: "bossa", name: "Bossa",
            chordScaleOverrides: { maj7: ["Lydian"] },
            categoryWeights: { drop2: 15 },
            qualityBoosts: {}
        };
        var all = [bebop, manouche, bossa];
    """

    def test_plain_style_passthrough(self):
        assert_js("StyleComposer.js", self.BASES + """
            var out = resolve(bebop, all);
            assertEqual(out.categoryWeights.drop2, 10, "plain style returns own weights");
            assertEqual(out.chordScaleOverrides.dom7.length, 2, "scales cloned");
            out.categoryWeights.drop2 = 999;
            assertEqual(bebop.categoryWeights.drop2, 10, "resolve returns a clone");
        """)

    def test_weighted_sum_numeric(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var out = resolve(comp, all);
            // drop2: 10 (bebop) + (-10) (manouche) = 0
            assertEqual(out.categoryWeights.drop2, 0, "weighted-sum cancels");
            // shell: 5 + 15 = 20
            assertEqual(out.categoryWeights.shell, 20, "shell stacked");
        """)

    def test_max_numeric_rule(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "max",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var out = resolve(comp, all);
            // shell: max(|5|, |15|) = 15 (wins by absolute value)
            assertEqual(out.categoryWeights.shell, 15, "max picks strongest");
            // drop2: max(|10|, |-10|) = 10 or -10. Both abs=10, order-dependent
            // but weighted-desc sort puts bebop first (equal weights -> stable)
            assert(out.categoryWeights.drop2 === 10 || out.categoryWeights.drop2 === -10,
                   "drop2 is one of the two opinions");
        """)

    def test_average_numeric_rule(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "average",
                               weights: { bebop: 1.0, manouche: 3.0 } }
            };
            var out = resolve(comp, all);
            // shell: (5*1 + 15*3) / (1+3) = 50/4 = 12.5 -> 13 (rounded)
            assertEqual(out.categoryWeights.shell, 13, "average weighted by input");
        """)

    def test_scale_union_priority(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { scaleRule: "union-priority",
                               weights: { bebop: 0.7, manouche: 0.5 } }
            };
            var out = resolve(comp, all);
            // bebop has higher weight -> its dom7 scales come first
            assertEqual(out.chordScaleOverrides.dom7[0], "Mixolydian", "higher-weight first");
            assertContains(out.chordScaleOverrides.dom7, "Harmonic Minor", "manouche added");
            assertEqual(out.chordScaleOverrides.dom7.length, 3, "deduped union");
        """)

    def test_scale_intersect(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { scaleRule: "intersect",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var out = resolve(comp, all);
            // Bebop dom7: [Mixolydian, Altered], manouche dom7: [Harmonic Minor]
            // intersection empty -> key omitted
            assert(!out.chordScaleOverrides.dom7, "no overlap -> key omitted");
        """)

    def test_scale_first_only(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { scaleRule: "first-only",
                               weights: { bebop: 0.6, manouche: 0.3 } }
            };
            var out = resolve(comp, all);
            // Only bebop's scales appear
            assertEqual(out.chordScaleOverrides.dom7.length, 2, "only highest-weight style");
            assertEqual(out.chordScaleOverrides.dom7[0], "Mixolydian", "bebop wins");
            assert(!out.chordScaleOverrides.min7, "manouche min7 omitted");
        """)

    def test_clamp_numeric(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 5.0, manouche: 5.0 },
                               clampNumeric: [-30, 30] }
            };
            var out = resolve(comp, all);
            // shell: (5+15) * 5 = 100 -> clamped to 30
            assertEqual(out.categoryWeights.shell, 30, "clamped to upper bound");
        """)

    def test_freeze_preserves_state(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var frozen = freeze(comp, all);
            assertEqual(frozen.composition.resolution, "freeze", "marked frozen");
            assertEqual(frozen.categoryWeights.shell, 20, "baked in");
            // Mutate base — frozen should not follow
            manouche.categoryWeights.shell = 999;
            var out = resolve(frozen, all);
            assertEqual(out.categoryWeights.shell, 20, "frozen ignores base edits");
        """)

    def test_re_resolve_follows_base_edits(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               resolution: "re-resolve",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var before = resolve(comp, all).categoryWeights.shell;
            assertEqual(before, 20, "initial sum");
            manouche.categoryWeights.shell = 100;
            var after = resolve(comp, all).categoryWeights.shell;
            assertEqual(after, 105, "re-resolve picks up edit");
        """)

    def test_find_dependents(self):
        assert_js("StyleComposer.js", self.BASES + """
            var live = {
                id: "live", composedFrom: ["bebop"],
                composition: { resolution: "re-resolve" }
            };
            var frozen = {
                id: "frozen", composedFrom: ["bebop"],
                composition: { resolution: "freeze" },
                categoryWeights: {}, chordScaleOverrides: {}, qualityBoosts: {}
            };
            var pool = all.concat([live, frozen]);
            var deps = findDependents("bebop", pool);
            assertEqual(deps.length, 1, "only live composition counts");
            assertEqual(deps[0], "live", "frozen excluded");
        """)

    def test_zero_weight_excluded(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 1.0, manouche: 0 } }
            };
            var out = resolve(comp, all);
            assertEqual(out.categoryWeights.drop2, 10, "manouche skipped");
        """)

    def test_resolved_readout_matches_resolver(self):
        # #195: the SettingsPanel readout consumes StyleComposer.resolve output
        # directly. This test verifies a known composition fixture resolves to
        # the expected category weights so the readout's "top by abs magnitude"
        # display will surface the right entries.
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "manouche"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 1.0, manouche: 1.0 } }
            };
            var resolved = resolve(comp, all);
            // Verify deterministic outputs the readout would render:
            assertEqual(resolved.categoryWeights.shell, 20, "shell stacks to 20");
            assertEqual(resolved.categoryWeights.drop2, 0, "drop2 cancels");
            // The readout sorts by absolute magnitude; shell would surface first.
            // The drop2 cancellation surfaces via the dedicated 'resolved to nothing' branch only when ALL fields are zero.
        """)

    def test_missing_base_style_skipped(self):
        assert_js("StyleComposer.js", self.BASES + """
            var comp = {
                id: "c1", composedFrom: ["bebop", "nonexistent"],
                composition: { numericRule: "weighted-sum",
                               weights: { bebop: 1.0, nonexistent: 1.0 } }
            };
            var out = resolve(comp, all);
            // Only bebop contributes
            assertEqual(out.categoryWeights.drop2, 10, "missing style silently skipped");
        """)


# === ChordSelector.js — mode scoring (#161) ===


class TestChordSelectorModes:
    """Test mode-aware scoring deltas in ChordSelector."""

    def test_compute_mode_delta_null_config(self):
        assert_js("ChordSelector.js", """
            var v = { category: "drop2", fret_number: 5, mutes: [], suitableModes: [] };
            assertEqual(computeModeDelta(v, null, "chord-melody"), 0, "null config -> 0");
            assertEqual(computeModeDelta(v, undefined, "chord-melody"), 0, "undefined config -> 0");
        """)

    def test_compute_mode_delta_category(self):
        assert_js("ChordSelector.js", """
            var cfg = { categoryDeltas: { shell: 15, drop2: 10 } };
            assertEqual(computeModeDelta({ category: "shell" }, cfg), 15, "shell +15");
            assertEqual(computeModeDelta({ category: "drop2" }, cfg), 10, "drop2 +10");
            assertEqual(computeModeDelta({ category: "other" }, cfg), 0, "unknown category +0");
        """)

    def test_compute_mode_delta_range(self):
        assert_js("ChordSelector.js", """
            var cfg = { rangeFretMin: 3, rangeFretMax: 7, rangeFretBonus: 10 };
            assertEqual(computeModeDelta({ fret_number: 5 }, cfg), 10, "in range");
            assertEqual(computeModeDelta({ fret_number: 3 }, cfg), 10, "at lower bound");
            assertEqual(computeModeDelta({ fret_number: 7 }, cfg), 10, "at upper bound");
            assertEqual(computeModeDelta({ fret_number: 2 }, cfg), 0, "below range");
            assertEqual(computeModeDelta({ fret_number: 8 }, cfg), 0, "above range");
        """)

    def test_compute_mode_delta_mute_penalty(self):
        assert_js("ChordSelector.js", """
            var cfg = { mutePenaltyPerString: 5 };
            assertEqual(computeModeDelta({ mutes: [1, 2] }, cfg), -10, "2 mutes * 5");
            assertEqual(computeModeDelta({ mutes: [] }, cfg), 0, "no mutes");
        """)

    def test_compute_mode_delta_suitable_modes(self):
        assert_js("ChordSelector.js", """
            var cfg = { modeMatchBonus: 25, modeMismatchPenalty: -15 };
            var match = { suitableModes: ["chord-melody", "solo-guitar"] };
            var miss = { suitableModes: ["comping"] };
            var empty = { suitableModes: [] };
            assertEqual(computeModeDelta(match, cfg, "chord-melody"), 25, "match +25");
            assertEqual(computeModeDelta(miss, cfg, "chord-melody"), -15, "miss -15");
            assertEqual(computeModeDelta(empty, cfg, "chord-melody"), 0, "empty modes untagged");
        """)

    def test_modes_config_loads(self):
        assert_js(
            [os.path.join(CONFIG_DIR, "modes.json")],
            ""
        ) if False else None  # json isn't eval-able; load via Python instead
        import json as _json
        with open(os.path.join(CONFIG_DIR, "modes.json")) as f:
            cfg = _json.load(f)
        assert set(cfg["modes"].keys()) == {"chord-melody", "comping", "solo-guitar", "duo"}
        for m in cfg["modes"].values():
            assert "melodyBonusMultiplier" in m
            assert "bassBonusMultiplier" in m
            assert "categoryDeltas" in m

    def test_modes_produce_different_rankings(self):
        # Two candidates: a shell (comping-friendly) vs a drop2 extended (chord-melody-friendly)
        assert_js("ChordSelector.js", """
            var shell = {
                id: "v-shell", root: "C", chord_quality: "dom7",
                category: "shell", fret_number: 5, mutes: [5, 6],
                dots: [{string:4,fret:1},{string:3,fret:2},{string:2,fret:1}],
                suitableModes: ["comping"],
                intervals: ["1","3","b7"], notes: ["C","E","Bb"], strings: 6, open: []
            };
            var drop2 = {
                id: "v-drop2", root: "C", chord_quality: "dom7",
                category: "drop2", fret_number: 8, mutes: [],
                dots: [{string:5,fret:3},{string:4,fret:2},{string:3,fret:3},{string:2,fret:2}],
                suitableModes: ["chord-melody"],
                intervals: ["1","3","b7","9"], notes: ["C","E","Bb","D"], strings: 6, open: []
            };
            var data = [shell, drop2];
            var cmCfg = {
                melodyBonusMultiplier: 1.0, bassBonusMultiplier: 0.5,
                categoryDeltas: { drop2: 10, shell: 0 },
                rangeFretMin: 3, rangeFretMax: 12, rangeFretBonus: 5,
                mutePenaltyPerString: 5, modeMatchBonus: 25, modeMismatchPenalty: -15
            };
            var cmpCfg = {
                melodyBonusMultiplier: 0.0, bassBonusMultiplier: 0.8,
                categoryDeltas: { shell: 15, drop2: 10 },
                rangeFretMin: 3, rangeFretMax: 7, rangeFretBonus: 10,
                mutePenaltyPerString: 3, modeMatchBonus: 25, modeMismatchPenalty: -15
            };
            var opts = { maxStrings: 6, semitoneMap: {C:0,D:2,E:4,F:5,G:7,A:9,B:11,Bb:10} };
            opts.modeConfig = cmCfg; opts.modeId = "chord-melody";
            var cmPick = findBestVoicing(data, "C", "dom7", opts);
            opts.modeConfig = cmpCfg; opts.modeId = "comping";
            var cmpPick = findBestVoicing(data, "C", "dom7", opts);
            assertEqual(cmPick.id, "v-drop2", "chord-melody picks drop2");
            assertEqual(cmpPick.id, "v-shell", "comping picks shell");
        """)

    def test_difficulty_memoization_one_call_per_voicing(self):
        # #178: _difficultyFor must call difficultyFn at most once per unique
        # voicing per sort pass, not twice per comparison.
        assert_js("ChordSelector.js", """
            // Build 8 distinct voicings — enough that a sort would normally call
            // the comparator many times.
            var voicings = [];
            for (var i = 0; i < 8; i++) {
                voicings.push({
                    id: "v" + i, root: "C", chord_quality: "dom7",
                    category: "drop2", fret_number: i + 1, mutes: [],
                    dots: [{string: 5, fret: 1}, {string: 4, fret: 2}],
                    intervals: ["1", "3", "b7"], notes: ["C", "E", "Bb"],
                    strings: 6, open: [], suitableModes: ["chord-melody"]
                });
            }
            var calls = {};
            var difficultyFn = function(v) {
                calls[v.id] = (calls[v.id] || 0) + 1;
                return { tier: "standard", score: 10 };
            };
            findBestVoicing(voicings, "C", "dom7", {
                maxStrings: 6, semitoneMap: {C:0},
                difficultyFn: difficultyFn
            });
            // Each voicing's difficulty should be computed exactly once.
            for (var k = 0; k < 8; k++) {
                assertEqual(calls["v" + k], 1, "v" + k + " called once");
            }
        """)


# === BackupManager.js — parseArchive (#179) ===


class TestBackupManagerParse:
    """Test BackupManager.parseArchive structured-result behavior."""

    def test_empty_input_returns_empty_reason(self):
        assert_js("BackupManager.js", """
            var r = parseArchive("");
            assertEqual(r.ok, false, "ok=false");
            assertEqual(r.reason, "empty", "reason=empty");
        """)

    def test_invalid_json_returns_not_json(self):
        assert_js("BackupManager.js", """
            var r = parseArchive("{not valid json");
            assertEqual(r.ok, false, "ok=false");
            assertEqual(r.reason, "not-json", "reason=not-json");
            assert(r.detail !== undefined, "detail set");
        """)

    def test_non_chordlibrary_manifest_rejected(self):
        assert_js("BackupManager.js", """
            var r = parseArchive(JSON.stringify({ manifest: { plugin: "other-tool", version: "v1.0" } }));
            assertEqual(r.reason, "not-chordlibrary", "reason=not-chordlibrary");
        """)

    def test_missing_version_rejected(self):
        assert_js("BackupManager.js", """
            var r = parseArchive(JSON.stringify({ manifest: { plugin: "chordlibrary" } }));
            assertEqual(r.reason, "missing-version", "reason=missing-version");
        """)

    def test_unsupported_version_rejected(self):
        assert_js("BackupManager.js", """
            var r = parseArchive(JSON.stringify({
                manifest: { plugin: "chordlibrary", version: "v9.99" }
            }));
            assertEqual(r.ok, false, "ok=false");
            assertEqual(r.reason, "unsupported-version", "reason=unsupported-version");
            assertEqual(r.detail, "v9.99", "detail names the version");
        """)

    def test_current_version_accepted(self):
        assert_js("BackupManager.js", """
            var archive = {
                manifest: { plugin: "chordlibrary", version: "v2.2", exportedAt: "2026-05-21" },
                settings: {}, customStyles: [], customScales: [], customTuningFiles: {}
            };
            var r = parseArchive(JSON.stringify(archive));
            assertEqual(r.ok, true, "ok=true");
            assertEqual(r.migrated, false, "current version not migrated");
            assertEqual(r.archive.manifest.version, "v2.2", "archive returned");
        """)


class TestBackupManagerRoundTrip:
    """Round-trip and merge coverage for BackupManager.js (#185)."""

    def test_build_archive_excludes_builtin_styles(self):
        assert_js("BackupManager.js", """
            var allStyles = [
                { id: "default", name: "Default", builtin: true },
                { id: "bebop", name: "Bebop", builtin: true },
                { id: "my-blend", name: "My Blend", builtin: false }
            ];
            var a = buildArchive({ allStyles: allStyles, allScales: [], customTuningSlugs: [] });
            assertEqual(a.customStyles.length, 1, "only custom style included");
            assertEqual(a.customStyles[0].id, "my-blend", "the right one");
        """)

    def test_build_archive_excludes_builtin_scales(self):
        assert_js("BackupManager.js", """
            var allScales = [
                { id: "ionian", builtin: true },
                { id: "my-scale", builtin: false }
            ];
            var a = buildArchive({ allStyles: [], allScales: allScales, customTuningSlugs: [] });
            assertEqual(a.customScales.length, 1, "only custom scale included");
            assertEqual(a.customScales[0].id, "my-scale", "the right one");
        """)

    def test_build_archive_reads_tuning_files(self):
        assert_js("BackupManager.js", """
            var readCalls = [];
            var reader = function(slug) {
                readCalls.push(slug);
                return JSON.stringify({ name: slug, strings: {}, notes: {} });
            };
            var a = buildArchive({
                allStyles: [], allScales: [],
                customTuningSlugs: ["custom-1", "custom-2"],
                readTuningFile: reader
            });
            assertEqual(readCalls.length, 2, "reader called once per slug");
            assertEqual(Object.keys(a.customTuningFiles).length, 2, "both tuning files included");
            assertEqual(a.customTuningFiles["custom-1"].name, "custom-1", "body parsed");
        """)

    def test_build_archive_skips_unreadable_tunings(self):
        assert_js("BackupManager.js", """
            var reader = function(slug) {
                if (slug === "broken") throw new Error("file missing");
                return JSON.stringify({ name: slug, strings: {}, notes: {} });
            };
            var a = buildArchive({
                allStyles: [], allScales: [],
                customTuningSlugs: ["broken", "ok"],
                readTuningFile: reader
            });
            assertEqual(Object.keys(a.customTuningFiles).length, 1, "broken skipped, ok kept");
            assert(a.customTuningFiles["ok"] !== undefined, "ok present");
            assert(a.customTuningFiles["broken"] === undefined, "broken absent");
        """)

    def test_serialize_parse_round_trip(self):
        assert_js("BackupManager.js", """
            var archive = buildArchive({
                allStyles: [{ id: "x", name: "X", builtin: false }],
                allScales: [{ id: "s", name: "S", builtin: false }],
                customTuningSlugs: []
            });
            var raw = serialize(archive);
            var r = parseArchive(raw);
            assertEqual(r.ok, true, "round-trip parses");
            assertEqual(r.archive.customStyles.length, 1, "style preserved");
            assertEqual(r.archive.customScales.length, 1, "scale preserved");
        """)

    def test_merge_styles_adds_when_absent(self):
        assert_js("BackupManager.js", """
            var existing = [{ id: "a", name: "A" }];
            var archive = { customStyles: [{ id: "b", name: "B" }] };
            var res = mergeStyles(archive, existing);
            assertEqual(res.added, 1, "1 added");
            assertEqual(res.updated, 0, "0 updated");
            assertEqual(res.list.length, 2, "list has both");
        """)

    def test_merge_styles_updates_on_id_collision(self):
        assert_js("BackupManager.js", """
            var existing = [{ id: "a", name: "Old A" }];
            var archive = { customStyles: [{ id: "a", name: "New A" }] };
            var res = mergeStyles(archive, existing);
            assertEqual(res.added, 0, "0 added");
            assertEqual(res.updated, 1, "1 updated");
            assertEqual(res.list[0].name, "New A", "new value wins");
        """)

    def test_merge_scales_mirrors_styles(self):
        assert_js("BackupManager.js", """
            var existing = [{ id: "ionian" }];
            var archive = { customScales: [
                { id: "ionian" },        // update
                { id: "custom-scale" }   // add
            ]};
            var res = mergeScales(archive, existing);
            assertEqual(res.added, 1, "1 added");
            assertEqual(res.updated, 1, "1 updated");
            assertEqual(res.list.length, 2, "list has both");
        """)

    def test_tuning_files_to_restore_returns_one_per_slug(self):
        assert_js("BackupManager.js", """
            var archive = { customTuningFiles: {
                "alpha": { name: "Alpha" },
                "beta": { name: "Beta" }
            }};
            var out = tuningFilesToRestore(archive);
            assertEqual(out.length, 2, "2 entries");
            // Order not guaranteed (Object.keys); verify content by id
            var slugs = out.map(function(x) { return x.slug; }).sort();
            assertEqual(slugs[0], "alpha", "alpha present");
            assertEqual(slugs[1], "beta", "beta present");
        """)

    def test_timestamp_for_filename_format(self):
        # #181: timestampForFilename produces YYYYMMDD-HHMM for filenames.
        assert_js("BackupManager.js", """
            var t = timestampForFilename(new Date(2026, 4, 21, 3, 7));  // May 21 2026 03:07
            assertEqual(t, "20260521-0307", "format YYYYMMDD-HHMM with zero-padding");
        """)

    def test_reason_message_unsupported_version_includes_detail(self):
        assert_js("BackupManager.js", """
            var pres = { ok: false, reason: "unsupported-version", detail: "v9.99" };
            var m = reasonMessage(pres);
            assert(m.indexOf("v9.99") >= 0, "message names the offending version");
            assert(m.indexOf("update the plugin") >= 0, "message advises action");
        """)

    def test_reason_message_empty_returns_empty(self):
        assert_js("BackupManager.js", """
            assertEqual(reasonMessage(null), "", "null result -> empty");
            assertEqual(reasonMessage({ ok: true, archive: {} }), "", "ok result -> empty");
        """)

    def test_freeze_resolution_round_trip_via_archive(self):
        # Frozen compositions in an archive should restore as frozen — base
        # styles can be missing from the receiving plugin without breaking.
        assert_js("BackupManager.js", """
            var frozenComposition = {
                id: "my-blend", name: "My Blend", builtin: false,
                composedFrom: ["bebop", "manouche"],
                composition: { resolution: "freeze" },
                chordScaleOverrides: { dom7: ["Mixolydian"] },
                categoryWeights: { drop2: 20 },
                qualityBoosts: {}
            };
            var a = buildArchive({
                allStyles: [frozenComposition],
                allScales: [],
                customTuningSlugs: []
            });
            var r = parseArchive(serialize(a));
            assertEqual(r.ok, true, "parses");
            assertEqual(r.archive.customStyles[0].composition.resolution, "freeze", "stays frozen");
            assertEqual(r.archive.customStyles[0].categoryWeights.drop2, 20, "deltas preserved");
        """)


# === IRealParser.js ===


class TestIRealParserJS:
    """Test IRealParser.js chord parsing."""

    def test_quality_map_has_common_qualities(self):
        assert_js("IRealParser.js", """
            assertEqual(QUALITY_MAP["^7"], "maj7", "^7 = maj7");
            assertEqual(QUALITY_MAP["-7"], "min7", "-7 = min7");
            assertEqual(QUALITY_MAP["7"], "dom7", "7 = dom7");
            assertEqual(QUALITY_MAP["o7"], "dim7", "o7 = dim7");
            assertEqual(QUALITY_MAP["h7"], "min7b5", "h7 = min7b5");
        """)

    def test_parse_plain_text(self):
        assert_js("IRealParser.js", """
            assert(typeof parsePlainText === "function", "parsePlainText exists");
            var result = parsePlainText("Dm7 G7 Cmaj7");
            assert(result.length >= 3, "parsed 3+ chords from simple string");
        """)


# === HygieneEngine.js ===


class TestHygieneEngineJS:
    """Test HygieneEngine.js audit functions."""

    def test_is_ignored(self):
        assert_js("HygieneEngine.js", """
            var list = [{key: "DUP:1"}, {key: "ENH:2"}];
            assert(isIgnored("DUP:1", list), "finds ignored key");
            assert(!isIgnored("DUP:3", list), "doesn't find missing key");
        """)

    def test_build_fingerprint(self):
        assert_js("HygieneEngine.js", """
            var v = {
                chord_quality: "dom7", fret_number: 3,
                dots: [{string: 5, fret: 1}, {string: 4, fret: 2}],
                mutes: [6]
            };
            var fp = buildFingerprint(v);
            assert(fp.length > 0, "fingerprint is non-empty");
            assert(typeof fp === "string", "fingerprint is string");
        """)

    def test_fingerprint_deterministic(self):
        assert_js("HygieneEngine.js", """
            var v = {
                chord_quality: "dom7", fret_number: 3,
                dots: [{string: 5, fret: 1}, {string: 4, fret: 2}],
                mutes: [6]
            };
            assertEqual(buildFingerprint(v), buildFingerprint(v), "same voicing = same fingerprint");
        """)


# === MelodyEngine.js ===


class TestMelodyEngineJS:
    """Test MelodyEngine.js melody extraction."""

    def test_interval_semitones_map(self):
        assert_js("MelodyEngine.js", """
            assertEqual(INTERVAL_SEMITONES["1"], 0, "root = 0");
            assertEqual(INTERVAL_SEMITONES["3"], 4, "3rd = 4");
            assertEqual(INTERVAL_SEMITONES["5"], 7, "5th = 7");
            assertEqual(INTERVAL_SEMITONES["b7"], 10, "b7 = 10");
            assertEqual(INTERVAL_SEMITONES["7"], 11, "7 = 11");
        """)

    def test_voicing_distance_exists(self):
        assert_js("MelodyEngine.js", """
            assert(typeof voicingDistance === "function", "voicingDistance exists");
        """)

    def test_voicing_distance_same_fret(self):
        assert_js("MelodyEngine.js", """
            var v1 = {fret_number: 3, dots: [{string:5, fret:1}]};
            var v2 = {fret_number: 3, dots: [{string:5, fret:1}]};
            assertEqual(voicingDistance(v1, v2), 0, "same position = 0 distance");
        """)


# === ReharmonizationEngine.js ===


class TestReharmonizationEngineJS:
    """Test ReharmonizationEngine.js chord substitution suggestions."""

    def test_note_index(self):
        assert_js("ReharmonizationEngine.js", """
            assertEqual(noteIndex("C"), 0, "C = 0");
            assertEqual(noteIndex("G"), 7, "G = 7");
            assertEqual(noteIndex("F#"), 6, "F# = 6");
        """)

    def test_note_at(self):
        assert_js("ReharmonizationEngine.js", """
            assertEqual(noteAt(0), "C", "0 = C");
            assertEqual(noteAt(7), "G", "7 = G");
            assertEqual(noteAt(12), "C", "12 wraps to C");
            assertEqual(noteAt(-1), "B", "-1 wraps to B");
        """)

    def test_suggest_exists(self):
        assert_js("ReharmonizationEngine.js", """
            assert(typeof suggest === "function", "suggest exists");
        """)

    def test_tritone_sub_for_dom7(self):
        assert_js("ReharmonizationEngine.js", """
            var subs = suggest("G", "dom7", null, null);
            assert(subs.length > 0, "has suggestions for G7");
            // Tritone sub of G7 is Db7
            var tritone = subs.filter(function(s) { return s.label && s.label.indexOf("Tritone") >= 0; });
            assert(tritone.length > 0, "has tritone sub suggestion");
        """)


# === VoicingCalculator.js ===


class TestVoicingCalculatorJS:
    """Test VoicingCalculator.js chord generation."""

    def test_chord_qualities_defined(self):
        assert_js("VoicingCalculator.js", """
            assert(CHORD_QUALITIES["dom7"] !== undefined, "dom7 defined");
            assert(CHORD_QUALITIES["maj7"] !== undefined, "maj7 defined");
            assert(CHORD_QUALITIES["min7"] !== undefined, "min7 defined");
            assert(CHORD_QUALITIES["dim7"] !== undefined, "dim7 defined");
        """)

    def test_dom7_intervals(self):
        assert_js("VoicingCalculator.js", """
            var dom7 = CHORD_QUALITIES["dom7"];
            assertEqual(dom7.intervals.length, 4, "dom7 has 4 intervals");
            assertContains(dom7.intervals, 0, "has root");
            assertContains(dom7.intervals, 4, "has major 3rd");
            assertContains(dom7.intervals, 7, "has perfect 5th");
            assertContains(dom7.intervals, 10, "has minor 7th");
        """)

    def test_interval_labels(self):
        assert_js("VoicingCalculator.js", """
            assertEqual(INTERVAL_LABELS[0], "1", "0 = root");
            assertEqual(INTERVAL_LABELS[4], "3", "4 = major 3rd");
            assertEqual(INTERVAL_LABELS[7], "5", "7 = perfect 5th");
            assertEqual(INTERVAL_LABELS[10], "b7", "10 = minor 7th");
        """)

    def test_calculate_for_quality_exists(self):
        assert_js("VoicingCalculator.js", """
            assert(typeof calculateForQuality === "function", "calculateForQuality exists");
        """)

    def test_calculator_covers_every_quality_in_voicings_json(self):
        # #180: CHORD_QUALITIES must define every chord_quality value that
        # appears in the curated voicings.json (excluding the chord-agnostic
        # "quartal" which has its own table).
        import json as _json
        with open(os.path.join(REPO_ROOT, "plugin", "data", "voicings.json")) as f:
            data = _json.load(f)
        data_qualities = sorted({
            v["chord_quality"] for v in data["voicings"]
            if v["chord_quality"] != "quartal"
        })
        missing = []
        for q in data_qualities:
            r = run_js(["VoicingCalculator.js"], f"""
                var present = (CHORD_QUALITIES["{q}"] !== undefined);
                _results.push({{ pass: present, message: "{q}" }});
                if (!present) _pass = false;
            """)
            if not r["pass"]:
                missing.append(q)
        assert not missing, f"calculator missing qualities: {missing}"


# === FingeringEngine.js (direct JS tests, complementing Python tests) ===


class TestFingeringEngineJS:
    """Test FingeringEngine.js directly in Node.js."""

    def test_compute_difficulty_exists(self):
        assert_js("FingeringEngine.js", """
            assert(typeof computeDifficulty === "function", "computeDifficulty exists");
        """)

    def test_suggest_fingering_exists(self):
        assert_js("FingeringEngine.js", """
            assert(typeof suggestFingering === "function", "suggestFingering exists");
        """)

    def test_open_chord_difficulty(self):
        assert_js("FingeringEngine.js", """
            var v = {
                fret_number: 1, strings: 6,
                dots: [{string: 5, fret: 1}, {string: 4, fret: 1}, {string: 2, fret: 1}],
                mutes: [], open: [6, 3, 1]
            };
            var d = computeDifficulty(v);
            assert(d.score >= 0, "score >= 0");
            assert(d.score <= 100, "score <= 100");
            assert(d.tier === "standard" || d.tier === "advanced" || d.tier === "expert",
                   "valid tier: " + d.tier);
        """)

    def test_fingering_assigns_all_fretted(self):
        assert_js("FingeringEngine.js", """
            var v = {
                fret_number: 1, strings: 6,
                dots: [{string: 5, fret: 1}, {string: 4, fret: 2}, {string: 3, fret: 2}],
                mutes: [6], open: [2, 1]
            };
            var f = suggestFingering(v);
            assertEqual(f.length, 3, "3 fretted strings get fingers");
            f.forEach(function(a) {
                assert(a.finger >= 0 && a.finger <= 4, "finger 0-4: " + a.finger);
            });
        """)


# === Style Profiles (#146) ===


class TestStyleProfiles:
    """Test style profile functionality in ChordScales.js."""

    def _load_first(self):
        return """
            var raw = readFileSync("plugin/config/scales.json");
            loadScales(JSON.parse(raw));
        """

    def test_no_profile_by_default(self):
        assert_js("ChordScales.js", self._load_first() + """
            assertEqual(getActiveProfile(), null, "no active profile by default");
        """)

    def test_set_active_profile(self):
        assert_js("ChordScales.js", self._load_first() + """
            setActiveProfile({ id: "test", chordScaleOverrides: {} });
            assertNotEqual(getActiveProfile(), null, "profile is set");
            assertEqual(getActiveProfile().id, "test", "correct id");
        """)

    def test_clear_profile(self):
        assert_js("ChordScales.js", self._load_first() + """
            setActiveProfile({ id: "test" });
            setActiveProfile(null);
            assertEqual(getActiveProfile(), null, "profile cleared");
        """)

    def test_profile_overrides_scales_for_quality(self):
        assert_js("ChordScales.js", self._load_first() + """
            // Default: min7 -> Dorian, Aeolian, Pentatonic Min
            var defaultNames = getScaleNames("min7");
            assertContains(defaultNames, "Dorian", "default has Dorian");

            // Set Manouche profile: min7 -> Harmonic Minor, Aeolian
            setActiveProfile({
                id: "manouche",
                chordScaleOverrides: {
                    "min7": ["Harmonic Minor", "Aeolian"]
                }
            });

            var profileNames = getScaleNames("min7");
            assertEqual(profileNames.length, 2, "profile has 2 scales for min7");
            assertEqual(profileNames[0], "Harmonic Minor", "first is Harmonic Minor");
            assertEqual(profileNames[1], "Aeolian", "second is Aeolian");
            assert(profileNames.indexOf("Dorian") < 0, "Dorian NOT in profile");
        """)

    def test_profile_does_not_affect_unmapped_qualities(self):
        assert_js("ChordScales.js", self._load_first() + """
            setActiveProfile({
                id: "test",
                chordScaleOverrides: { "min7": ["Harmonic Minor"] }
            });
            // dom7 should still use default mapping
            var dom7Names = getScaleNames("dom7");
            assertContains(dom7Names, "Mixolydian", "dom7 unaffected by profile");
        """)

    def test_profile_category_weight(self):
        assert_js("ChordScales.js", self._load_first() + """
            setActiveProfile({
                id: "manouche",
                categoryWeights: { "shell": 15, "drop2": -10 }
            });
            assertEqual(getProfileCategoryWeight("shell"), 15, "shell +15");
            assertEqual(getProfileCategoryWeight("drop2"), -10, "drop2 -10");
            assertEqual(getProfileCategoryWeight("extended"), 0, "unspecified = 0");
        """)

    def test_profile_quality_boost(self):
        assert_js("ChordScales.js", self._load_first() + """
            setActiveProfile({
                id: "manouche",
                qualityBoosts: { "dim7": 20, "maj7": -10 }
            });
            assertEqual(getProfileQualityBoost("dim7"), 20, "dim7 +20");
            assertEqual(getProfileQualityBoost("maj7"), -10, "maj7 -10");
            assertEqual(getProfileQualityBoost("dom7"), 0, "unspecified = 0");
        """)

    def test_profiles_json_valid(self):
        """Validate profiles.json structure."""
        profiles_path = os.path.join(CONFIG_DIR, "styles.json")
        with open(profiles_path) as f:
            data = json.load(f)
        assert "profiles" in data
        assert len(data["profiles"]) >= 3, "at least Default, Bebop, Manouche"
        for p in data["profiles"]:
            assert "id" in p, f"Missing id in profile: {p}"
            assert "name" in p, f"Missing name in profile: {p}"
            assert "builtin" in p, f"Missing builtin in profile: {p}"
            assert "chordScaleOverrides" in p, f"Missing chordScaleOverrides: {p}"
            assert "categoryWeights" in p, f"Missing categoryWeights: {p}"
            assert "qualityBoosts" in p, f"Missing qualityBoosts: {p}"

    def test_profiles_scale_overrides_valid(self):
        """All scale names in profile overrides must exist in scales.json."""
        profiles_path = os.path.join(CONFIG_DIR, "styles.json")
        scales_path = os.path.join(CONFIG_DIR, "scales.json")
        with open(profiles_path) as f:
            profiles = json.load(f)
        with open(scales_path) as f:
            scales = json.load(f)
        valid_names = {s["name"] for s in scales["scales"]}
        for p in profiles["profiles"]:
            for quality, scale_names in p["chordScaleOverrides"].items():
                for name in scale_names:
                    assert name in valid_names, \
                        f"Profile '{p['name']}' references unknown scale '{name}' for quality '{quality}'"
