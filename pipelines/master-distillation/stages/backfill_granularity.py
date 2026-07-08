"""Backfill granularity_level onto all s5 usage_notes in pipeline runs."""
import json
import glob
import os
import sys
from datetime import datetime, timezone

REPO = os.getcwd()
INDEX_PATH = os.path.join(REPO, "pipelines/master-distillation/stages/granularity-normalization-index.json")
RUNS_DIR = os.path.join(REPO, "pipelines/master-distillation/runs")

BUCKET_NAMES = {
    "a": "harmonic-family",
    "b": "voicing-floor",
    "c": "omission-priority",
    "d": "color-tone-policy",
    "e": "substitution-rules",
    "f": "rhythmic-placement",
    "g": "voice-leading",
    "h": "idiom-application",
    "i": "other",
}

def main():
    with open(INDEX_PATH) as f:
        index = json.load(f)
    by_role = index["by_role"]

    runs = sorted(glob.glob(os.path.join(RUNS_DIR, "*/")))
    total_tagged = 0
    total_unmatched = 0
    unmatched_roles = []
    files_modified = 0

    for run in runs:
        resp_path = os.path.join(run, "llm-calls", "s5-usage-notes.response.json")
        if not os.path.exists(resp_path):
            continue

        with open(resp_path) as f:
            envelope = json.load(f)

        parsed = json.loads(envelope["text"])
        notes = parsed.get("usage_notes", [])
        if not notes:
            continue

        changed = False
        for note in notes:
            role = note.get("function_role", "")
            if role in by_role:
                bucket = by_role[role]
                note["granularity_level"] = bucket
                note["granularity_name"] = BUCKET_NAMES[bucket]
                total_tagged += 1
                changed = True
            else:
                total_unmatched += 1
                unmatched_roles.append((os.path.basename(run.rstrip("/")), role))

        if changed:
            envelope["text"] = json.dumps(parsed, indent=2)
            with open(resp_path, "w") as f:
                json.dump(envelope, f, indent=2)
            files_modified += 1

    print(f"Files modified: {files_modified}")
    print(f"Notes tagged: {total_tagged}")
    print(f"Unmatched roles: {total_unmatched}")
    if unmatched_roles:
        print("\nUnmatched:")
        for run_slug, role in unmatched_roles:
            print(f"  {run_slug}: {role}")

if __name__ == "__main__":
    main()
