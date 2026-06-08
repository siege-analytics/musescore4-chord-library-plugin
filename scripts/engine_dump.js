#!/usr/bin/env node
// engine_dump.js — Headless ranked-voicings emitter (#400).
//
// Loads the plugin's engine JS modules (ChordSelector + MastersStore +
// ExclusionEngine) into a Node vm sandbox and invokes them to emit a
// ranked-voicings JSON for one (chord × tuning × master) request to
// stdout. Designed as the canonical oracle harness for the Ellington
// Python port at siege-analytics/ellington-systems; also useful here as
// a regression / smoke tool whenever _scoreCandidate or
// MastersStore.collectVoicingStyleTags is edited.
//
// Loader semantics shared with tests/js_runner.js via tests/_jsLoader.js.
//
// USAGE
//
//   node scripts/engine_dump.js \
//       --chord Cmaj7 \
//       --tuning EADGBE \
//       --master joe-pass \
//       [--style chord-melody] \
//       [--n-strings 6] \
//       [--position-preference low] \
//       [--no-master] \
//       [--masters-path plugin/data/masters.json] \
//       [--voicings-path plugin/data/voicings.json] \
//       [--output -|FILE]
//
// EXIT CODES
//
//   0 — success; ranked_voicings JSON on stdout (or written to FILE)
//   2 — argument error (unknown flag, missing required, parse failure)
//   3 — corpus / file error (missing JSON file, malformed wrapper shape)
//   4 — invalid master id (not present in masters.json)
//
// OUTPUT (one JSON object per invocation)
//
//   {
//     "request": { "chord_symbol", "tuning", "master_id", "style_filter", "context" },
//     "ranked_voicings": [
//       { "voicing_id", "rank", "score",
//         "score_components": { "base", "master_boost", "tolerance_match" },
//         "payload_kind": null, "applied_principles": [] },
//       ...
//     ],
//     "engine_version":   { "sha": "<short>", "clean": <bool> },
//     "masters_version":  { "sha": "<short>", "clean": <bool> },
//     "voicings_version": { "sha": "<short>", "clean": <bool> }
//   }
//
// "payload_kind" and "applied_principles" are always null / [] because
// the plugin's JS does not implement an engine_payload.kind dispatcher.
// The Ellington Python port populates those fields on its own side.

'use strict';

const fs = require('fs');
const vm = require('vm');
const path = require('path');
const { execSync } = require('child_process');
const { createSandbox, loadModules } = require('../tests/_jsLoader');

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_MASTERS = path.join('plugin', 'data', 'masters.json');
const DEFAULT_VOICINGS = path.join('plugin', 'data', 'voicings.json');
const MODEL_DIR = path.join(REPO_ROOT, 'plugin', 'model');

// --------------------------------------------------------------------- argv

function printUsageAndExit(code) {
    process.stderr.write(
        'Usage: node scripts/engine_dump.js --chord SYMBOL --tuning STR --master ID [opts]\n' +
        '  --chord SYMBOL        (e.g. Cmaj7)\n' +
        '  --tuning STR          (e.g. EADGBE)\n' +
        '  --master ID           master id from masters.json\n' +
        '  --no-master           score without master boost\n' +
        '  --style ID            optional voicingStyleTag filter\n' +
        '  --n-strings N         default 6\n' +
        '  --position-preference low|mid|high   informational; not used in scoring today\n' +
        '  --masters-path PATH   default plugin/data/masters.json\n' +
        '  --voicings-path PATH  default plugin/data/voicings.json\n' +
        '  --output FILE         "-" or omitted writes to stdout\n'
    );
    process.exit(code);
}

function parseArgs(argv) {
    const out = {
        chord: null,
        tuning: null,
        master: null,
        noMaster: false,
        style: null,
        nStrings: 6,
        positionPreference: null,
        mastersPath: DEFAULT_MASTERS,
        voicingsPath: DEFAULT_VOICINGS,
        output: '-',
    };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        const next = argv[i + 1];
        switch (a) {
            case '--chord':
            case '--chord-symbol':
                out.chord = next; i++; break;
            case '--tuning':
                out.tuning = next; i++; break;
            case '--master':
            case '--master-id':
                out.master = next; i++; break;
            case '--no-master':
                out.noMaster = true; break;
            case '--style':
            case '--style-filter':
                out.style = next; i++; break;
            case '--n-strings':
                out.nStrings = parseInt(next, 10); i++; break;
            case '--position-preference':
                out.positionPreference = next; i++; break;
            case '--masters-path':
                out.mastersPath = next; i++; break;
            case '--voicings-path':
                out.voicingsPath = next; i++; break;
            case '--output':
                out.output = next; i++; break;
            case '--help':
            case '-h':
                printUsageAndExit(0); break;
            default:
                process.stderr.write('Unknown flag: ' + a + '\n');
                printUsageAndExit(2);
        }
    }
    if (!out.chord) { process.stderr.write('Missing --chord\n'); printUsageAndExit(2); }
    if (!out.tuning) { process.stderr.write('Missing --tuning\n'); printUsageAndExit(2); }
    if (!out.master && !out.noMaster) { process.stderr.write('Missing --master (or use --no-master)\n'); printUsageAndExit(2); }
    if (out.master && out.noMaster) { process.stderr.write('Cannot combine --master with --no-master\n'); printUsageAndExit(2); }
    if (isNaN(out.nStrings) || out.nStrings < 4 || out.nStrings > 12) {
        process.stderr.write('--n-strings must be 4-12 inclusive\n');
        printUsageAndExit(2);
    }
    return out;
}

// -------------------------------------------------------------------- chord

// Mirror of Ellington's parse_chord_symbol — root is one of A-G plus
// optional b/#, rest is quality. Lives here separately to keep the shim
// dependency-free; if drift emerges the diff harness will catch it.
function parseChordSymbol(symbol) {
    if (!symbol || symbol.length === 0) return { root: '', quality: '' };
    const head = symbol[0];
    if ('ABCDEFG'.indexOf(head) < 0) return { root: '', quality: symbol };
    if (symbol.length >= 2 && (symbol[1] === 'b' || symbol[1] === '#')) {
        return { root: symbol.slice(0, 2), quality: symbol.slice(2) };
    }
    return { root: symbol[0], quality: symbol.slice(1) };
}

// ------------------------------------------------------------------- corpus

function loadJsonOrExit(filePath, what) {
    const abs = path.isAbsolute(filePath) ? filePath : path.join(REPO_ROOT, filePath);
    if (!fs.existsSync(abs)) {
        process.stderr.write(what + ' not found at ' + abs + '\n');
        process.exit(3);
    }
    let doc;
    try {
        doc = JSON.parse(fs.readFileSync(abs, 'utf8'));
    } catch (e) {
        process.stderr.write('Failed to parse ' + what + ': ' + e.message + '\n');
        process.exit(3);
    }
    return doc;
}

function unwrapMasters(doc) {
    if (!doc || typeof doc !== 'object' || !Array.isArray(doc.masters)) {
        process.stderr.write("masters.json must be a wrapper {masters: [...]} object\n");
        process.exit(3);
    }
    return doc.masters;
}

function unwrapVoicings(doc) {
    if (!doc || typeof doc !== 'object' || !Array.isArray(doc.voicings)) {
        process.stderr.write("voicings.json must be a wrapper {voicings: [...]} object\n");
        process.exit(3);
    }
    return doc.voicings;
}

// --------------------------------------------------------------------- git

function gitShortSha(targetPath) {
    try {
        const out = execSync(
            'git log -1 --format=%h -- ' + JSON.stringify(targetPath),
            { cwd: REPO_ROOT, encoding: 'utf8' }
        );
        return out.trim() || 'unknown';
    } catch (e) {
        return 'unknown';
    }
}

function gitClean(targetPath) {
    try {
        const out = execSync(
            'git status --porcelain -- ' + JSON.stringify(targetPath),
            { cwd: REPO_ROOT, encoding: 'utf8' }
        );
        return out.trim().length === 0;
    } catch (e) {
        return false;
    }
}

function versionObject(targetPath) {
    return { sha: gitShortSha(targetPath), clean: gitClean(targetPath) };
}

// ---------------------------------------------------------------- sandbox

function loadEngineSandbox() {
    const sandbox = createSandbox({ collectAssertions: false, exposeFs: false });
    vm.createContext(sandbox);
    loadModules(sandbox, [
        path.join(MODEL_DIR, 'ChordSelector.js'),
        path.join(MODEL_DIR, 'MastersStore.js'),
        path.join(MODEL_DIR, 'ExclusionEngine.js'),
    ]);
    return sandbox;
}

// ------------------------------------------------------------------- main

function main() {
    const args = parseArgs(process.argv.slice(2));

    const mastersDoc = loadJsonOrExit(args.mastersPath, 'masters.json');
    const voicingsDoc = loadJsonOrExit(args.voicingsPath, 'voicings.json');
    const masters = unwrapMasters(mastersDoc);
    const voicings = unwrapVoicings(voicingsDoc);

    let master = null;
    if (args.master) {
        for (let i = 0; i < masters.length; i++) {
            if (masters[i].id === args.master) { master = masters[i]; break; }
        }
        if (master === null) {
            process.stderr.write("master_id='" + args.master + "' not found in masters.json\n");
            process.exit(4);
        }
    }

    const sandbox = loadEngineSandbox();
    // Compute master tag set via the actual JS implementation (so any
    // future change to collectVoicingStyleTags surfaces in shim output
    // without needing a Python rewrite).
    sandbox._master = master;
    vm.runInContext('_masterTags = (typeof collectVoicingStyleTags === "function") ? collectVoicingStyleTags(_master) : [];', sandbox);
    const masterTags = args.noMaster ? [] : (sandbox._masterTags || []);

    const parsed = parseChordSymbol(args.chord);
    if (!parsed.root) {
        process.stderr.write("Could not parse chord symbol '" + args.chord + "' (root must be A-G plus optional b/#)\n");
        process.exit(2);
    }

    // Build opts shared by score + base computation. Callbacks
    // (topNoteFn, bassNoteFn, distanceFn) are intentionally absent —
    // melodyMidi/bassMidi default to -1 in the spike shim, so the
    // callback-gated terms in _scoreCandidate contribute 0.
    const baseOpts = {
        maxStrings: args.nStrings,
        filterCategory: args.style || null,
        melodyMidi: -1,
        bassMidi: -1,
        melodyLocked: false,
        bassLocked: false,
        lastInsertedVoicing: null,
    };
    const optsWithMaster = Object.assign({}, baseOpts, { masterVoicingStyleTags: masterTags });
    const optsBase       = Object.assign({}, baseOpts, { masterVoicingStyleTags: [] });

    // Pipe everything into the sandbox so the JS engine code can act on it.
    sandbox._voicings = voicings;
    sandbox._targetRoot = parsed.root;
    sandbox._quality = parsed.quality;
    sandbox._optsWith = optsWithMaster;
    sandbox._optsBase = optsBase;

    // Drive findAllVoicings and per-row dual-_scoreCandidate.
    vm.runInContext([
        'if (typeof findAllVoicings !== "function") throw new Error("findAllVoicings not loaded");',
        'if (typeof _scoreCandidate !== "function") throw new Error("_scoreCandidate not loaded");',
        '_ranked = findAllVoicings(_voicings, _targetRoot, _quality, _optsWith);',
        '_rows = [];',
        'for (var i = 0; i < _ranked.length; i++) {',
        '  var v = _ranked[i];',
        '  var score = _scoreCandidate(v, _targetRoot, _quality, -1, -1, null, _optsWith);',
        '  var base  = _scoreCandidate(v, _targetRoot, _quality, -1, -1, null, _optsBase);',
        '  _rows.push({',
        '    voicing_id: v.id,',
        '    rank: i + 1,',
        '    score: score,',
        '    score_components: { base: base, master_boost: score - base, tolerance_match: 0 },',
        '    payload_kind: null,',
        '    applied_principles: []',
        '  });',
        '}',
    ].join('\n'), sandbox);

    const rankedVoicings = sandbox._rows || [];

    const out = {
        request: {
            chord_symbol: args.chord,
            tuning: args.tuning,
            master_id: args.noMaster ? null : args.master,
            style_filter: args.style || null,
            context: {
                n_strings: args.nStrings,
                position_preference: args.positionPreference,
            },
        },
        ranked_voicings: rankedVoicings,
        engine_version:   versionObject('plugin/model/'),
        masters_version:  versionObject(args.mastersPath),
        voicings_version: versionObject(args.voicingsPath),
    };

    const payload = JSON.stringify(out, null, 2);
    if (args.output && args.output !== '-') {
        fs.writeFileSync(args.output, payload);
    } else {
        process.stdout.write(payload + '\n');
    }
}

main();
