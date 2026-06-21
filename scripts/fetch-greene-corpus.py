#!/usr/bin/env python3
"""Fetch Ted Greene's openly-distributed teaching materials (#220).

The Greene estate publishes the entire archive at https://tedgreene.com
free of charge. This script downloads selected PDFs (and extracts text
alongside them) to plugin/data/masters-corpus/greene/ for reference.

The MVP entry-point list keeps this commit reasonably-sized (target
< 100MB); a --full sweep is available to crawl the whole site once we
want it.

Usage:
    python scripts/fetch-greene-corpus.py            # MVP curated list
    python scripts/fetch-greene-corpus.py --full     # full site crawl
    python scripts/fetch-greene-corpus.py --extract  # re-extract text from PDFs
    python scripts/fetch-greene-corpus.py --dry-run  # show what would happen

Polite by default: 1-second delay between requests, custom User-Agent,
skips files already present. The 'requests' library is required;
pdfplumber is optional (falls back to system pdftotext, then skips).
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import requests
except ImportError:
    print("ERROR: requests is required. pip install requests", file=sys.stderr)
    sys.exit(1)

try:
    from bs4 import BeautifulSoup
    HAS_BS4 = True
except ImportError:
    HAS_BS4 = False

try:
    import pdfplumber
    HAS_PDFPLUMBER = True
except ImportError:
    HAS_PDFPLUMBER = False

REPO_ROOT = Path(__file__).resolve().parent.parent
DEST = REPO_ROOT / "plugin" / "data" / "masters-corpus" / "greene"

USER_AGENT = "musescore4-chord-library-plugin masters-bookshelf (educational, https://github.com/siege-analytics)"
DELAY_SECONDS = 1.0
SITE_BASE = "https://tedgreene.com"

# Curated entry-point URLs for the MVP scrape. Hand-picked from the site's
# index pages — biased toward the most-referenced manuscript collections
# and lessons. Project owner can extend.
MVP_ENTRY_POINTS = [
    # Subject index pages (each lists ~10-50 PDFs of lessons).
    f"{SITE_BASE}/teaching/default.asp",
    f"{SITE_BASE}/teaching/chords.asp",
    f"{SITE_BASE}/teaching/comping.asp",
    f"{SITE_BASE}/teaching/harmony.asp",
    f"{SITE_BASE}/teaching/v_system.asp",
    f"{SITE_BASE}/teaching/fundamentals.asp",
    f"{SITE_BASE}/teaching/baroque.asp",
    f"{SITE_BASE}/teaching/blues.asp",
    f"{SITE_BASE}/teaching/jazz.asp",
    f"{SITE_BASE}/teaching/singlenote.asp",
]

MAX_DOCS_MVP = 20
MAX_DOCS_FULL = 5000  # safety bound; the site has thousands of PDFs


def parse_args():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--full", action="store_true", help="full site crawl (slow, large)")
    ap.add_argument("--extract", action="store_true",
                    help="extract text from already-downloaded PDFs")
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would happen; don't download")
    ap.add_argument("--limit", type=int, default=None,
                    help="cap on number of PDFs to download")
    return ap.parse_args()


def polite_get(url: str, session: requests.Session) -> requests.Response | None:
    """GET a URL with a polite delay and a clear User-Agent. Returns None on error."""
    time.sleep(DELAY_SECONDS)
    try:
        resp = session.get(url, headers={"User-Agent": USER_AGENT}, timeout=30)
        if resp.status_code != 200:
            print(f"  ! {url}: HTTP {resp.status_code}", file=sys.stderr)
            return None
        return resp
    except requests.RequestException as e:
        print(f"  ! {url}: {e}", file=sys.stderr)
        return None


def discover_pdfs(start_urls: list[str], full: bool, session: requests.Session) -> list[str]:
    """Discover PDFs from each start URL. In MVP mode, interleave so each
    entry page contributes a representative sample (first PDF from page 1,
    page 2, ...; then second from each; etc.). In full mode, return every
    PDF found via BFS across the entire site.
    """
    if full:
        return _discover_pdfs_full(start_urls, session)
    return _discover_pdfs_interleaved(start_urls, session)


def _extract_pdf_links_from_html(text: str, base_url: str) -> list[str]:
    """Return PDF URLs found in `text` (HTML), resolved against base_url."""
    if HAS_BS4:
        soup = BeautifulSoup(text, "html.parser")
        hrefs = [a.get("href") for a in soup.find_all("a", href=True) if a.get("href")]
    else:
        import re
        hrefs = re.findall(r'href="([^"]+)"', text)
    out: list[str] = []
    seen: set[str] = set()
    for href in hrefs:
        if not href:
            continue
        absolute = urljoin(base_url, href).split("#", 1)[0]
        if absolute.lower().endswith(".pdf") and absolute not in seen:
            seen.add(absolute)
            out.append(absolute)
    return out


def _discover_pdfs_interleaved(entry_points: list[str], session: requests.Session) -> list[str]:
    """For each entry page, collect its PDFs in order; then interleave so
    the first PDF from each page comes before the second from any page."""
    per_page: list[list[str]] = []
    for url in entry_points:
        resp = polite_get(url, session)
        if resp is None:
            per_page.append([])
            continue
        per_page.append(_extract_pdf_links_from_html(resp.text, url))

    # Interleave round-robin.
    seen: set[str] = set()
    out: list[str] = []
    max_len = max((len(p) for p in per_page), default=0)
    for col in range(max_len):
        for lst in per_page:
            if col < len(lst):
                url = lst[col]
                if url not in seen:
                    seen.add(url)
                    out.append(url)
    return out


def _discover_pdfs_full(start_urls: list[str], session: requests.Session) -> list[str]:
    """Recursively crawl the site, collecting every PDF reachable from the
    start_urls. Stays on tedgreene.com host. Slow + thorough."""
    seen_pages: set[str] = set()
    seen_pdfs: set[str] = set()
    queue: list[str] = list(start_urls)

    while queue:
        url = queue.pop(0)
        if url in seen_pages:
            continue
        seen_pages.add(url)

        if urlparse(url).netloc and "tedgreene.com" not in urlparse(url).netloc:
            continue

        resp = polite_get(url, session)
        if resp is None:
            continue

        text = resp.text

        if HAS_BS4:
            soup = BeautifulSoup(text, "html.parser")
            links = [a.get("href") for a in soup.find_all("a", href=True)]
        else:
            import re
            links = re.findall(r'href="([^"]+)"', text)

        for href in links:
            if not href:
                continue
            absolute = urljoin(url, href).split("#", 1)[0]
            if absolute.lower().endswith(".pdf"):
                seen_pdfs.add(absolute)
            elif absolute.startswith(SITE_BASE):
                lower = absolute.lower()
                if lower.endswith((".htm", ".html", ".aspx", ".asp")) or lower == SITE_BASE + "/":
                    queue.append(absolute)

    return sorted(seen_pdfs)


def download_pdf(url: str, dest_dir: Path, session: requests.Session) -> Path | None:
    """Download a PDF to dest_dir. Returns the path written, or None on failure
    or skip-because-already-present."""
    name = urlparse(url).path.split("/")[-1]
    if not name:
        return None
    out = dest_dir / name
    if out.exists():
        return None  # already have it
    resp = polite_get(url, session)
    if resp is None:
        return None
    try:
        out.write_bytes(resp.content)
        return out
    except OSError as e:
        print(f"  ! write failed for {out}: {e}", file=sys.stderr)
        return None


def extract_text(pdf_path: Path) -> bool:
    """Write a .txt sidecar next to the PDF. Returns True if extracted."""
    txt_path = pdf_path.with_suffix(".txt")
    if txt_path.exists() and txt_path.stat().st_mtime > pdf_path.stat().st_mtime:
        return False  # already extracted

    if HAS_PDFPLUMBER:
        try:
            with pdfplumber.open(pdf_path) as pdf:
                parts = []
                for page in pdf.pages:
                    parts.append(page.extract_text() or "")
                txt_path.write_text("\n\n".join(parts))
                return True
        except Exception as e:
            print(f"  ! pdfplumber failed on {pdf_path.name}: {e}", file=sys.stderr)

    # Fall back to system pdftotext if available
    if shutil.which("pdftotext"):
        try:
            subprocess.run(
                ["pdftotext", "-layout", str(pdf_path), str(txt_path)],
                check=True, capture_output=True
            )
            return True
        except subprocess.CalledProcessError as e:
            print(f"  ! pdftotext failed on {pdf_path.name}: {e}", file=sys.stderr)

    # No extractor available — skip silently.
    return False


def main():
    args = parse_args()

    DEST.mkdir(parents=True, exist_ok=True)

    if args.extract:
        # Just re-extract text from existing PDFs.
        count = 0
        for pdf in sorted(DEST.glob("*.pdf")):
            if extract_text(pdf):
                count += 1
                print(f"  extracted {pdf.name}")
        print(f"Extracted text from {count} PDF(s).")
        return

    session = requests.Session()
    print(f"Discovering PDFs (full={args.full}) ...")
    pdfs = discover_pdfs(MVP_ENTRY_POINTS, args.full, session)
    print(f"Found {len(pdfs)} PDF link(s).")

    limit = args.limit or (MAX_DOCS_FULL if args.full else MAX_DOCS_MVP)
    pdfs = pdfs[:limit]

    if args.dry_run:
        print("--dry-run; would download:")
        for url in pdfs:
            print(f"  {url}")
        return

    written = 0
    extracted = 0
    skipped = 0
    for i, url in enumerate(pdfs, 1):
        print(f"[{i}/{len(pdfs)}] {url}")
        path = download_pdf(url, DEST, session)
        if path is None:
            skipped += 1
            continue
        written += 1
        if extract_text(path):
            extracted += 1

    # Write a manifest for traceability.
    manifest = {
        "scrape_mode": "full" if args.full else "mvp",
        "discovered": len(pdfs),
        "written": written,
        "skipped": skipped,
        "extracted_text_count": extracted,
        "entry_points": MVP_ENTRY_POINTS,
        "site": SITE_BASE,
    }
    (DEST / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")

    print(f"Done. wrote={written} skipped={skipped} extracted_text={extracted}")
    print(f"Corpus: {DEST}")


if __name__ == "__main__":
    main()
