#!/usr/bin/env python3
"""
import_gtdb.py — Import guitar tunings from the Guitar Tuning Database (gtdb.org).

Fetches tuning data from gtdb.org, converts it to the local JSON format used
in config/tunings/, and saves each tuning as a separate file.

Usage:
    python import_gtdb.py                        # Import all tunings
    python import_gtdb.py --limit 10             # Import at most 10 tunings
    python import_gtdb.py --filter "drop"        # Only tunings matching "drop"
    python import_gtdb.py --dry-run              # Preview without writing files
    python import_gtdb.py --dry-run --verbose    # Preview with full detail
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import time
import unicodedata
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
TUNINGS_DIR = PROJECT_ROOT / "config" / "tunings"

# ---------------------------------------------------------------------------
# MIDI helpers
# ---------------------------------------------------------------------------

# Semitone offsets from C within an octave.
_NOTE_OFFSETS: dict[str, int] = {
    "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
}

# Regex that matches note names like "E4", "Bb3", "F#2", "Db5", etc.
_NOTE_RE = re.compile(
    r"^([A-Ga-g])"          # letter
    r"([#b♯♭]?)"            # optional accidental
    r"(-?\d+)$"             # octave number (may be negative for very low notes)
)


def note_name_to_midi(name: str) -> int:
    """Convert a scientific-pitch note name (e.g. 'E4') to a MIDI number.

    Convention: C4 = 60 (middle C).
    """
    # Normalise Unicode sharp/flat symbols to ASCII.
    name = unicodedata.normalize("NFKC", name.strip())
    name = name.replace("\u266f", "#").replace("\u266d", "b")

    m = _NOTE_RE.match(name)
    if not m:
        raise ValueError(f"Cannot parse note name: {name!r}")

    letter, accidental, octave_str = m.groups()
    letter = letter.upper()
    octave = int(octave_str)

    midi = (octave + 1) * 12 + _NOTE_OFFSETS[letter]
    if accidental in ("#", "\u266f"):
        midi += 1
    elif accidental in ("b", "\u266d"):
        midi -= 1

    return midi


def midi_to_note_name(midi: int) -> str:
    """Convert a MIDI number back to a note name (sharps only, e.g. 64 -> 'E4')."""
    _NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    octave = (midi // 12) - 1
    note = _NAMES[midi % 12]
    return f"{note}{octave}"


# ---------------------------------------------------------------------------
# Local tuning I/O
# ---------------------------------------------------------------------------

def load_existing_tunings() -> dict[str, dict]:
    """Return a dict mapping filename -> tuning data for everything already
    present in config/tunings/."""
    tunings: dict[str, dict] = {}
    if not TUNINGS_DIR.is_dir():
        return tunings
    for p in sorted(TUNINGS_DIR.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            tunings[p.name] = data
        except (json.JSONDecodeError, OSError) as exc:
            logging.warning("Skipping unreadable file %s: %s", p, exc)
    return tunings


def tuning_signature(data: dict) -> tuple[int, ...]:
    """Return a hashable signature for a tuning — a tuple of MIDI numbers from
    string 1 (highest) to string N (lowest).  Used for deduplication."""
    strings = data.get("strings", {})
    return tuple(strings[k] for k in sorted(strings, key=int))


def slugify(name: str) -> str:
    """Turn a tuning name into a safe filename slug."""
    s = name.lower().strip()
    s = unicodedata.normalize("NFKD", s)
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_-]+", "-", s).strip("-")
    return s or "tuning"


def build_tuning_dict(
    name: str,
    description: str,
    notes_high_to_low: list[str],
) -> dict[str, Any]:
    """Build a tuning dict in the local format.

    Parameters
    ----------
    name : str
        Human-readable name (e.g. "Open G").
    description : str
        One-line description.
    notes_high_to_low : list[str]
        Note names ordered from string 1 (highest pitch) to string N (lowest).
    """
    strings: dict[str, int] = {}
    notes: dict[str, str] = {}
    for i, note in enumerate(notes_high_to_low, start=1):
        midi = note_name_to_midi(note)
        strings[str(i)] = midi
        notes[str(i)] = note

    return {
        "name": name,
        "description": description,
        "strings": strings,
        "notes": notes,
    }


# ---------------------------------------------------------------------------
# GTDB fetching and parsing
# ---------------------------------------------------------------------------

# gtdb.org exposes tuning data at several endpoints.  The primary ones:
#   https://gtdb.org/api/tunings          — paginated list (JSON)
#   https://gtdb.org/api/tunings?type=6   — filtered by string count
#
# If the API shape changes, only the functions in this section need updating.

GTDB_BASE = "https://gtdb.org"
GTDB_API_TUNINGS = f"{GTDB_BASE}/api/tunings"

# Fallback: scrape the HTML listing pages.
GTDB_HTML_TUNINGS = f"{GTDB_BASE}/tunings"

# Be polite: wait between requests.
REQUEST_DELAY_SECONDS = 1.0


def _get_session():
    """Lazy-import requests and return a Session with sensible defaults."""
    try:
        import requests  # type: ignore[import-untyped]
    except ImportError:
        logging.error(
            "The 'requests' package is required.  Install it with:\n"
            "    pip install requests"
        )
        sys.exit(1)

    session = requests.Session()
    session.headers.update({
        "User-Agent": "musescore4-chord-library-plugin/import_gtdb (contact: github)",
        "Accept": "application/json, text/html",
    })
    return session


def _rate_limit():
    """Sleep briefly to avoid hammering the server."""
    time.sleep(REQUEST_DELAY_SECONDS)


def fetch_tunings_from_api(
    session,
    limit: int | None = None,
    name_filter: str | None = None,
) -> list[dict]:
    """Try the JSON API first.  Returns a list of raw tuning dicts from GTDB,
    or an empty list if the API is unavailable or returns unexpected data."""
    raw_tunings: list[dict] = []

    # Try paginated API.
    page = 1
    max_pages = 50  # safety cap
    while page <= max_pages:
        url = GTDB_API_TUNINGS
        params: dict[str, Any] = {"page": page}
        logging.info("Fetching %s (page %d)...", url, page)
        try:
            resp = session.get(url, params=params, timeout=30)
            if resp.status_code == 404:
                logging.info("API returned 404 — will fall back to scraping.")
                return []
            resp.raise_for_status()
        except Exception as exc:
            logging.warning("API request failed: %s", exc)
            return []

        data = resp.json()

        # GTDB may return {"tunings": [...], "page": N, "total_pages": M}
        # or just a bare list.  Handle both.
        if isinstance(data, list):
            items = data
            total_pages = 1
        elif isinstance(data, dict):
            items = data.get("tunings", data.get("results", data.get("data", [])))
            total_pages = data.get("total_pages", data.get("pages", 1))
        else:
            logging.warning("Unexpected API response type: %s", type(data))
            break

        if not items:
            break

        raw_tunings.extend(items)

        if limit and len(raw_tunings) >= limit:
            raw_tunings = raw_tunings[:limit]
            break

        if page >= total_pages:
            break

        page += 1
        _rate_limit()

    return raw_tunings


def fetch_tunings_via_scrape(
    session,
    limit: int | None = None,
    name_filter: str | None = None,
) -> list[dict]:
    """Fallback: scrape tuning data from the HTML pages of gtdb.org.

    Many pages embed JSON-LD or inline JS objects with tuning data.  We also
    look for a pattern like:
        <td>Open G</td><td>D G D G B D</td>
    and synthesise tuning dicts from that.
    """
    raw_tunings: list[dict] = []

    # GTDB lists tunings by string count.  Try 6-string and 7-string pages.
    for num_strings in (6, 7, 8, 4, 5, 12):
        url = f"{GTDB_HTML_TUNINGS}/{num_strings}-string"
        logging.info("Scraping %s ...", url)
        try:
            resp = session.get(url, timeout=30)
            if resp.status_code != 200:
                logging.info("  -> HTTP %d, skipping.", resp.status_code)
                continue
        except Exception as exc:
            logging.warning("  -> Request failed: %s", exc)
            continue

        html = resp.text

        # Strategy 1: look for embedded JSON (some sites put it in a <script>
        # tag with type="application/json" or inside a JS variable).
        json_blobs = re.findall(
            r'(?:tunings|data)\s*[:=]\s*(\[.*?\])\s*[;\n]',
            html,
            re.DOTALL,
        )
        for blob in json_blobs:
            try:
                items = json.loads(blob)
                if isinstance(items, list):
                    for item in items:
                        item.setdefault("num_strings", num_strings)
                    raw_tunings.extend(items)
            except json.JSONDecodeError:
                pass

        # Strategy 2: parse HTML table rows.
        # Pattern: name, notes (space-separated), optional category.
        row_pattern = re.compile(
            r'<tr[^>]*>\s*<td[^>]*>([^<]+)</td>\s*<td[^>]*>([A-Ga-g#b♯♭0-9\s]+)</td>',
            re.IGNORECASE,
        )
        for match in row_pattern.finditer(html):
            tname = match.group(1).strip()
            tnotes_raw = match.group(2).strip()
            # Notes might be "D G D G B D" (low-to-high) or with octave numbers.
            note_tokens = tnotes_raw.split()
            if len(note_tokens) < 3:
                continue
            raw_tunings.append({
                "name": tname,
                "notes": note_tokens,
                "num_strings": num_strings,
                "source": "scrape",
            })

        _rate_limit()

        if limit and len(raw_tunings) >= limit:
            break

    if limit:
        raw_tunings = raw_tunings[:limit]

    return raw_tunings


# ---------------------------------------------------------------------------
# Parsing / normalisation of raw GTDB data
# ---------------------------------------------------------------------------

# Default octave assignment for notes without explicit octaves.
# Standard guitar: string 1 (high E) is in octave 4, string 6 (low E) is
# octave 2.  We interpolate roughly based on string position.
_DEFAULT_OCTAVES_BY_STRING_COUNT: dict[int, list[int]] = {
    4:  [4, 3, 3, 2],
    5:  [4, 3, 3, 2, 2],
    6:  [4, 3, 3, 3, 2, 2],
    7:  [4, 3, 3, 3, 2, 2, 1],
    8:  [4, 3, 3, 3, 2, 2, 1, 1],
    12: [4, 4, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2],
}


def _assign_octaves(
    note_letters: list[str],
    num_strings: int,
) -> list[str]:
    """Given bare note letters (e.g. ['E','B','G','D','A','E']), assign octave
    numbers so the resulting MIDI values decrease monotonically from string 1
    to string N (high to low), using the standard guitar register as a guide.

    Returns a list of full note names like ['E4','B3','G3','D3','A2','E2'].
    """
    defaults = _DEFAULT_OCTAVES_BY_STRING_COUNT.get(
        num_strings,
        _DEFAULT_OCTAVES_BY_STRING_COUNT[6],
    )

    # Pad or trim the default octave list to match string count.
    while len(defaults) < len(note_letters):
        defaults.append(defaults[-1])
    defaults = defaults[: len(note_letters)]

    result: list[str] = []
    prev_midi = 999
    for i, (letter, default_oct) in enumerate(zip(note_letters, defaults)):
        # Start with the default octave, then adjust downward if the resulting
        # MIDI would not be lower than the previous string.
        candidate = f"{letter}{default_oct}"
        midi = note_name_to_midi(candidate)

        # Ensure each string is the same pitch or lower than the one before it
        # (string numbering is high to low).
        while midi > prev_midi and default_oct > -1:
            default_oct -= 1
            candidate = f"{letter}{default_oct}"
            midi = note_name_to_midi(candidate)

        # If we overshot and this note ended up much lower than expected,
        # try one octave up.
        if i > 0 and prev_midi - midi > 7 and default_oct < 8:
            higher = f"{letter}{default_oct + 1}"
            higher_midi = note_name_to_midi(higher)
            if higher_midi <= prev_midi:
                candidate = higher
                midi = higher_midi

        result.append(candidate)
        prev_midi = midi

    return result


def parse_gtdb_tuning(raw: dict) -> dict[str, Any] | None:
    """Convert a raw GTDB tuning dict into our local format.

    Returns None if the data is unusable.

    This function is designed to be the single adaptation point: if the GTDB
    response format changes, update only this function.
    """
    name = raw.get("name", raw.get("title", "")).strip()
    if not name:
        return None

    num_strings = raw.get("num_strings", raw.get("strings_count", 6))

    # --- Determine note list (high to low) ---
    notes_raw = raw.get("notes", raw.get("pitches", raw.get("tuning", [])))

    # May be a string like "E A D G B E" or "E2-A2-D3-G3-B3-E4".
    if isinstance(notes_raw, str):
        notes_raw = re.split(r"[\s,\-/]+", notes_raw.strip())

    if not notes_raw or not isinstance(notes_raw, list):
        return None

    # Determine if notes include octave numbers.
    has_octaves = all(_NOTE_RE.match(n.strip()) for n in notes_raw if n.strip())

    # GTDB typically lists notes low-to-high (like "E A D G B E").
    # Our format is high-to-low (string 1 = highest), so we may need to reverse.
    # Heuristic: if the first note (after parsing) has a lower pitch than the
    # last, the list is low-to-high and we reverse it.
    notes_clean = [n.strip() for n in notes_raw if n.strip()]

    if not notes_clean:
        return None

    if has_octaves:
        # Check ordering and reverse if low-to-high.
        first_midi = note_name_to_midi(notes_clean[0])
        last_midi = note_name_to_midi(notes_clean[-1])
        if first_midi < last_midi:
            notes_clean = list(reversed(notes_clean))
        notes_high_to_low = notes_clean
    else:
        # No octave numbers — assign them.
        # Assume the list is low-to-high (GTDB convention), reverse to high-to-low.
        if len(notes_clean) >= 2:
            # Simple heuristic: reverse so we go high-to-low for octave assignment.
            notes_letters = list(reversed(notes_clean))
        else:
            notes_letters = notes_clean

        num_strings = len(notes_letters)
        notes_high_to_low = _assign_octaves(notes_letters, num_strings)

    # Build description.
    low_to_high = list(reversed(notes_high_to_low))
    note_summary = "-".join(n.rstrip("0123456789") for n in low_to_high)
    desc = raw.get("description", "")
    if not desc:
        desc = f"{name} tuning. {note_summary}, low to high."

    try:
        return build_tuning_dict(name, desc, notes_high_to_low)
    except ValueError as exc:
        logging.warning("Skipping %r: %s", name, exc)
        return None


# ---------------------------------------------------------------------------
# Main import logic
# ---------------------------------------------------------------------------

def import_tunings(
    limit: int | None = None,
    name_filter: str | None = None,
    dry_run: bool = False,
    verbose: bool = False,
) -> dict[str, Any]:
    """Orchestrate the full import.  Returns a summary dict."""
    session = _get_session()

    # 1. Fetch raw data (try API first, then scrape).
    raw_tunings = fetch_tunings_from_api(session, limit=limit, name_filter=name_filter)
    source = "API"
    if not raw_tunings:
        logging.info("API yielded no results; falling back to scraping.")
        raw_tunings = fetch_tunings_via_scrape(session, limit=limit, name_filter=name_filter)
        source = "scrape"

    logging.info("Fetched %d raw tuning(s) via %s.", len(raw_tunings), source)

    # 2. Apply name filter.
    if name_filter:
        pattern = re.compile(re.escape(name_filter), re.IGNORECASE)
        raw_tunings = [t for t in raw_tunings if pattern.search(t.get("name", ""))]
        logging.info("After filter %r: %d tuning(s).", name_filter, len(raw_tunings))

    # 3. Apply limit.
    if limit and len(raw_tunings) > limit:
        raw_tunings = raw_tunings[:limit]
        logging.info("Capped to %d tuning(s) by --limit.", limit)

    # 4. Load existing tunings for deduplication.
    existing = load_existing_tunings()
    existing_signatures: set[tuple[int, ...]] = set()
    for data in existing.values():
        try:
            existing_signatures.add(tuning_signature(data))
        except (KeyError, TypeError):
            pass

    # 5. Parse and deduplicate.
    parsed: list[tuple[str, dict]] = []  # (filename, tuning_dict)
    skipped_parse = 0
    skipped_dup = 0

    seen_slugs: dict[str, int] = {}

    for raw in raw_tunings:
        tuning = parse_gtdb_tuning(raw)
        if tuning is None:
            skipped_parse += 1
            continue

        sig = tuning_signature(tuning)
        if sig in existing_signatures:
            skipped_dup += 1
            if verbose:
                logging.info("  Duplicate (exists): %s", tuning["name"])
            continue

        # Avoid writing duplicate signatures within this import batch.
        if sig in {tuning_signature(t) for _, t in parsed}:
            skipped_dup += 1
            if verbose:
                logging.info("  Duplicate (batch):  %s", tuning["name"])
            continue

        slug = slugify(tuning["name"])
        # Ensure unique filenames.
        if slug in seen_slugs:
            seen_slugs[slug] += 1
            slug = f"{slug}-{seen_slugs[slug]}"
        else:
            seen_slugs[slug] = 0

        filename = f"{slug}.json"

        # If the filename already exists on disk, add a numeric suffix.
        counter = 1
        while filename in existing:
            filename = f"{slug}-{counter}.json"
            counter += 1

        parsed.append((filename, tuning))
        existing_signatures.add(sig)  # prevent further in-batch dups

    # 6. Write files (unless dry-run).
    written = 0
    for filename, tuning in parsed:
        filepath = TUNINGS_DIR / filename
        if dry_run:
            notes_str = ", ".join(
                f"{tuning['notes'][str(i)]}" for i in range(1, len(tuning["notes"]) + 1)
            )
            print(f"  [DRY-RUN] Would write: {filename}")
            print(f"            Name: {tuning['name']}")
            print(f"            Notes (high->low): {notes_str}")
            if verbose:
                print(f"            MIDI: {json.dumps(tuning['strings'])}")
            print()
        else:
            TUNINGS_DIR.mkdir(parents=True, exist_ok=True)
            filepath.write_text(
                json.dumps(tuning, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            written += 1
            if verbose:
                logging.info("  Wrote %s", filepath)

    # 7. Summary.
    summary = {
        "source": source,
        "fetched": len(raw_tunings),
        "parsed": len(parsed),
        "skipped_parse_errors": skipped_parse,
        "skipped_duplicates": skipped_dup,
        "written": written,
        "dry_run": dry_run,
    }
    return summary


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import guitar tunings from the Guitar Tuning Database (gtdb.org).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Maximum number of tunings to import.",
    )
    parser.add_argument(
        "--filter",
        dest="name_filter",
        type=str,
        default=None,
        help="Only import tunings whose name matches this substring (case-insensitive).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview what would be imported without writing any files.",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print extra detail during import.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO).",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(levelname)s: %(message)s",
    )

    print(f"Tunings directory: {TUNINGS_DIR}")
    print()

    summary = import_tunings(
        limit=args.limit,
        name_filter=args.name_filter,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )

    # Print summary.
    print("=" * 60)
    print("Import Summary")
    print("=" * 60)
    print(f"  Source:              {summary['source']}")
    print(f"  Fetched from GTDB:  {summary['fetched']}")
    print(f"  Successfully parsed: {summary['parsed']}")
    print(f"  Skipped (parse):    {summary['skipped_parse_errors']}")
    print(f"  Skipped (duplicate): {summary['skipped_duplicates']}")
    if summary["dry_run"]:
        print(f"  Would write:        {summary['parsed']} file(s) [DRY-RUN]")
    else:
        print(f"  Written:            {summary['written']} file(s)")
    print("=" * 60)


if __name__ == "__main__":
    main()
