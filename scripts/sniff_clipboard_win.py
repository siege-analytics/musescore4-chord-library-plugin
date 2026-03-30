#!/usr/bin/env python3
"""Sniff the Windows clipboard to discover MuseScore's format name.

Usage:
    1. Open MuseScore on Windows
    2. Select a fretboard diagram in a score
    3. Press Ctrl+C to copy it
    4. Run: python sniff_clipboard_win.py

The script lists all clipboard formats and their data. Look for one
containing XML with <FretDiagram> or <EngravingItem>.
"""

import ctypes
import sys

if sys.platform != "win32":
    print("This script is for Windows only.")
    sys.exit(1)

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32


def get_format_name(fmt: int) -> str:
    """Get the name of a clipboard format."""
    buf = ctypes.create_unicode_buffer(256)
    length = user32.GetClipboardFormatNameW(fmt, buf, 256)
    if length > 0:
        return buf.value
    # Standard formats
    standard = {
        1: "CF_TEXT", 2: "CF_BITMAP", 7: "CF_OEMTEXT",
        13: "CF_UNICODETEXT", 16: "CF_LOCALE", 17: "CF_DIBV5",
    }
    return standard.get(fmt, f"Unknown({fmt})")


def main():
    if not user32.OpenClipboard(0):
        print("Failed to open clipboard. Is another app holding it?")
        sys.exit(1)

    try:
        fmt = 0
        print("Clipboard formats:")
        print("=" * 60)

        while True:
            fmt = user32.EnumClipboardFormats(fmt)
            if fmt == 0:
                break

            name = get_format_name(fmt)
            handle = user32.GetClipboardData(fmt)
            size = 0
            preview = ""

            if handle:
                size = kernel32.GlobalSize(handle)
                if size > 0 and size < 100000:
                    ptr = kernel32.GlobalLock(handle)
                    if ptr:
                        data = ctypes.string_at(ptr, min(size, 500))
                        kernel32.GlobalUnlock(handle)
                        try:
                            text = data.decode("utf-8", errors="replace")
                            preview = text[:200].replace("\n", "\\n")
                        except Exception:
                            preview = f"[binary, {size} bytes]"

            print(f"\nFormat {fmt}: {name} ({size} bytes)")
            if preview:
                print(f"  Preview: {preview}")

            # Flag if it looks like MuseScore data
            if "FretDiagram" in preview or "EngravingItem" in preview or "musescore" in name.lower():
                print("  *** THIS IS LIKELY THE MUSESCORE FORMAT ***")

    finally:
        user32.CloseClipboard()

    print("\n" + "=" * 60)
    print("Copy the format name that contains FretDiagram/EngravingItem data.")
    print("Report it at: https://github.com/siege-analytics/musescore4-chord-library-plugin/issues")


if __name__ == "__main__":
    main()
