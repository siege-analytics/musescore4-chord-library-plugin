#!/usr/bin/env node
// walkthrough_bench.js — Measure voicing-selection performance under a
// representative walkthrough scenario (#199).
//
// Loads ChordSelector + dependencies in a Node sandbox, runs findBestVoicing
// over a 32-chord progression on Standard 6-String + Chord Melody + Default,
// reports per-call timings and hot-path totals.
//
// Usage:
//   node tests/perf/walkthrough_bench.js
//   node tests/perf/walkthrough_bench.js --iterations 100
//   node tests/perf/walkthrough_bench.js --json   # machine-readable output

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const REPO = path.resolve(__dirname, '..', '..');

let iterations = 30;
let jsonOutput = false;
for (let i = 2; i < process.argv.length; i++) {
    if (process.argv[i] === '--iterations') iterations = parseInt(process.argv[++i]);
    else if (process.argv[i] === '--json') jsonOutput = true;
}

const sandbox = {
    console: { log: () => {}, error: () => {}, warn: () => {} },
    JSON, Math, parseInt, parseFloat, isNaN, isFinite,
    String, Number, Array, Object, Date, RegExp, Error,
    undefined: undefined,
    process: { hrtime: process.hrtime },
    BigInt
};
vm.createContext(sandbox);

function loadModule(relPath) {
    let code = fs.readFileSync(path.join(REPO, relPath), 'utf8');
    code = code.replace(/^\.pragma\s+library\s*$/m, '// .pragma library (stripped)');
    vm.runInContext(code, sandbox, { filename: path.basename(relPath) });
}

loadModule('plugin/model/Transposer.js');
loadModule('plugin/model/MelodyEngine.js');
loadModule('plugin/model/ChordScales.js');
loadModule('plugin/model/FingeringEngine.js');
loadModule('plugin/model/ChordSelector.js');

const voicings = JSON.parse(fs.readFileSync(path.join(REPO, 'plugin/data/voicings.json'))).voicings;

// Au Privave-shaped 32-bar progression (F major; ii-V dense)
const PROGRESSION = [
    'F7', 'F7', 'Cm7', 'F7', 'Bb7', 'Bb7', 'F7', 'F7',
    'Gm7', 'C7', 'F7', 'D7', 'Gm7', 'C7', 'F7', 'F7',
    'F7', 'F7', 'Cm7', 'F7', 'Bb7', 'Bb7', 'F7', 'F7',
    'Gm7', 'C7', 'F7', 'D7', 'Gm7', 'C7', 'F7', 'F7'
];

const semitoneMap = { C: 0, Db: 1, D: 2, Eb: 3, E: 4, F: 5, Gb: 6, G: 7, Ab: 8, A: 9, Bb: 10, B: 11 };

sandbox._voicings = voicings;
sandbox._progression = PROGRESSION;
sandbox._semitoneMap = semitoneMap;

vm.runInContext(`
var _calls;
var _lastResult;
function _runOnce() {
    _calls = { topNote: 0, bassNote: 0, distance: 0, difficulty: 0 };
    var topNoteFn = function(v, r, m) { _calls.topNote++; return voicingTopNoteSemitone(v, r, m); };
    var bassNoteFn = function(v, r, m) { _calls.bassNote++; return voicingBassNoteSemitone(v, r, m); };
    var distanceFn = function(a, b) { _calls.distance++; return voicingDistance(a, b); };
    var difficultyFn = function(v) { _calls.difficulty++; return computeDifficulty(v); };
    var opts = {
        maxStrings: 6,
        filterContext: '',
        filterCategory: '',
        topNoteFn: topNoteFn,
        bassNoteFn: bassNoteFn,
        distanceFn: distanceFn,
        difficultyFn: difficultyFn,
        semitoneMap: _semitoneMap,
        modeConfig: {
            melodyBonusMultiplier: 1.0, bassBonusMultiplier: 0.5,
            categoryDeltas: { drop2: 10, extended: 5 },
            rangeFretMin: 3, rangeFretMax: 12, rangeFretBonus: 5,
            mutePenaltyPerString: 5, modeMatchBonus: 25, modeMismatchPenalty: -15
        },
        modeId: 'chord-melody'
    };
    var start = process.hrtime.bigint();
    var lastVoicing = null;
    for (var i = 0; i < _progression.length; i++) {
        var parsed = parseChordSymbol(_progression[i]);
        if (!parsed) continue;
        opts.lastInsertedVoicing = lastVoicing;
        var v = findBestVoicing(_voicings, parsed.root, parsed.quality, opts);
        if (v) lastVoicing = v;
    }
    var end = process.hrtime.bigint();
    _lastResult = { elapsedMs: Number(end - start) / 1e6, calls: _calls };
}
`, sandbox);

function runOnce() {
    vm.runInContext('_runOnce()', sandbox);
    return sandbox._lastResult;
}

// Scenario B: simulate a larger candidate pool (non-standard-tuning analog).
// Duplicate the voicings 10x to approximate the 8200-voicing scale.
sandbox._voicingsLarge = voicings.concat(voicings).concat(voicings).concat(voicings).concat(voicings)
                                .concat(voicings).concat(voicings).concat(voicings).concat(voicings).concat(voicings);
vm.runInContext(`
function _runOnceLarge() {
    var saved = _voicings;
    _voicings = _voicingsLarge;
    _runOnce();
    _voicings = saved;
}
`, sandbox);

function runOnceLarge() {
    vm.runInContext('_runOnceLarge()', sandbox);
    return sandbox._lastResult;
}

// Warm-up
runOnce();
runOnceLarge();

const runs = [];
for (let i = 0; i < iterations; i++) runs.push(runOnce());

const runsLarge = [];
const largeIters = Math.max(5, Math.floor(iterations / 6));  // slower; fewer runs
for (let i = 0; i < largeIters; i++) runsLarge.push(runOnceLarge());

const times = runs.map(r => r.elapsedMs).sort((a, b) => a - b);
const median = times[Math.floor(times.length / 2)];
const p95 = times[Math.floor(times.length * 0.95)];
const mean = times.reduce((s, t) => s + t, 0) / times.length;

const callsAvg = ['topNote', 'bassNote', 'distance', 'difficulty'].reduce((acc, k) => {
    acc[k] = Math.round(runs.reduce((s, r) => s + r.calls[k], 0) / runs.length);
    return acc;
}, {});

const result = {
    scenario: {
        progression: 'Au Privave-shaped 32-bar (F major / Bb / Cm / Gm)',
        chords: PROGRESSION.length,
        tuning: 'Standard 6-String',
        mode: 'chord-melody',
        style: 'default',
        voicingsLoaded: voicings.length
    },
    iterations,
    elapsedMs: { median, p95, mean: Math.round(mean * 100) / 100 },
    callsPerRun: callsAvg,
    perChordMs: Math.round((median / PROGRESSION.length) * 100) / 100
};

const timesLarge = runsLarge.map(r => r.elapsedMs).sort((a, b) => a - b);
const medianLarge = timesLarge[Math.floor(timesLarge.length / 2)];
const meanLarge = timesLarge.reduce((s, t) => s + t, 0) / timesLarge.length;

result.scenarioLarge = {
    description: 'Same progression, 10x voicing pool (simulates non-standard-tuning candidate count)',
    voicingsLoaded: sandbox._voicingsLarge.length,
    iterations: largeIters,
    elapsedMs: { median: medianLarge, mean: Math.round(meanLarge * 100) / 100 },
    perChordMs: Math.round((medianLarge / PROGRESSION.length) * 100) / 100
};

if (jsonOutput) {
    console.log(JSON.stringify(result, null, 2));
} else {
    console.log(`=== Walkthrough bench (${PROGRESSION.length} chords × ${iterations} iters) ===`);
    console.log(`Scenario A: ${result.scenario.tuning} + ${result.scenario.mode} + ${result.scenario.style}`);
    console.log(`           ${voicings.length} voicings loaded`);
    console.log('');
    console.log(`Median:    ${median.toFixed(2)} ms / 32 chords`);
    console.log(`Mean:      ${mean.toFixed(2)} ms`);
    console.log(`P95:       ${p95.toFixed(2)} ms`);
    console.log(`Per chord: ${result.perChordMs} ms (median / 32)`);
    console.log('');
    console.log('Callbacks invoked (average per run):');
    console.log(`  topNoteFn:    ${callsAvg.topNote}`);
    console.log(`  bassNoteFn:   ${callsAvg.bassNote}`);
    console.log(`  distanceFn:   ${callsAvg.distance}`);
    console.log(`  difficultyFn: ${callsAvg.difficulty}  ← memoized via _difficultyFor (#178)`);
    console.log('');
    console.log(`=== Scenario B (${largeIters} iters): 10x voicing pool (~8200 voicings) ===`);
    console.log(`Median:    ${medianLarge.toFixed(2)} ms / 32 chords`);
    console.log(`Per chord: ${result.scenarioLarge.perChordMs} ms`);
    console.log(`Ratio:     ${(medianLarge / median).toFixed(1)}x slower than scenario A`);
}
