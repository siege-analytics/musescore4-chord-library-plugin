# Contributing

## Adding Voicings

1. Add your voicing to `data/voicings.json` following the schema
2. Use the Laukens chord dictionary or other reputable source for fingerings
3. Verify against Oolimo (https://www.oolimo.com/)
4. Run `python scripts/validate.py -v` to check
5. Submit a PR with the source reference for each voicing

## Voicing Conventions

- All voicings stored with root C
- Every string must be accounted for in `dots`, `mutes`, or `open`
- Shell chords: root, 3rd, 7th only (no 5th)
- Use the standard ID format: `{root}{quality}-{category}-{intervals}-{root-string}-{string-count}`

## Code Style

- Python: follow PEP 8
- QML: follow Qt conventions, 4-space indent
