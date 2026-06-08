#!/usr/bin/env node
// js_runner.js — Test harness for QML .pragma library JavaScript modules.
// Evaluates modules in a Node.js vm context and runs test code passed
// as the last argument (or via stdin when `-` is the last arg).
//
// Usage: node js_runner.js <module_path> [<module_path2> ...] -- <test_code>
//         node js_runner.js <module_path> [...] -- -            # read test code from stdin
//
// Output JSON: { "pass": true/false, "results": [...], "error": "..." }
//
// Loading + sandbox semantics live in tests/_jsLoader.js (#400 refactor)
// so engine_dump.js and any future shim consumer share the same
// behaviour without duplicating the loader.

const fs = require('fs');
const vm = require('vm');
const path = require('path');
const { createSandbox, loadModules } = require('./_jsLoader');

// Parse arguments: module paths before --, test code after --
const args = process.argv.slice(2);
const sepIdx = args.indexOf('--');
if (sepIdx < 0) {
    console.log(JSON.stringify({ pass: false, error: "Usage: node js_runner.js <module> [<module>...] -- <test_code>" }));
    process.exit(1);
}

const modulePaths = args.slice(0, sepIdx);
// #343: read test code from stdin when the arg after `--` is `-` (or absent).
// Passing large test code as a CLI arg hits platform argv limits on Windows
// (WinError 206) and Linux (E2BIG) when JSON payloads grow.
let testCode;
const tail = args.slice(sepIdx + 1);
if (tail.length === 0 || (tail.length === 1 && tail[0] === '-')) {
    testCode = fs.readFileSync(0, 'utf8');
} else {
    testCode = tail.join(' ');
}

const sandbox = createSandbox({ collectAssertions: true, exposeFs: true });
vm.createContext(sandbox);

try {
    loadModules(sandbox, modulePaths);
    vm.runInContext(testCode, sandbox, { filename: 'test' });

    console.log(JSON.stringify({
        pass: sandbox._pass,
        results: sandbox._results,
        error: null
    }));
} catch (e) {
    console.log(JSON.stringify({
        pass: false,
        results: sandbox._results,
        error: e.message + (e.stack ? '\n' + e.stack : '')
    }));
    process.exit(1);
}
