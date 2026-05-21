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

    cmd = ["node", JS_RUNNER] + mod_paths + ["--", test_code]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO_ROOT, timeout=30)

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
