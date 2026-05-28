#!/usr/bin/env node
// js_runner.js — Test harness for QML .pragma library JavaScript modules.
// Strips QML-specific directives and evaluates modules in a Node.js context,
// then runs test code passed as the last argument.
//
// Usage: node js_runner.js <module_path> [<module_path2> ...] -- <test_code>
//
// The test code runs in a context where all module vars/functions are global.
// Output JSON: { "pass": true/false, "results": [...], "error": "..." }

const fs = require('fs');
const vm = require('vm');
const path = require('path');

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

// Create a sandbox context with common globals
const sandbox = {
    console: {
        log: function() {},  // suppress module console.log
        error: function() {},
        warn: function() {}
    },
    JSON: JSON,
    Math: Math,
    parseInt: parseInt,
    parseFloat: parseFloat,
    isNaN: isNaN,
    isFinite: isFinite,
    String: String,
    Number: Number,
    Array: Array,
    Object: Object,
    Date: Date,
    RegExp: RegExp,
    Error: Error,
    TypeError: TypeError,
    RangeError: RangeError,
    undefined: undefined,
    // Test results collector
    _results: [],
    _pass: true,
    assert: function(condition, message) {
        if (!condition) {
            sandbox._pass = false;
            sandbox._results.push({ pass: false, message: message || "Assertion failed" });
        } else {
            sandbox._results.push({ pass: true, message: message || "OK" });
        }
    },
    assertEqual: function(actual, expected, message) {
        const actualStr = JSON.stringify(actual);
        const expectedStr = JSON.stringify(expected);
        if (actualStr !== expectedStr) {
            sandbox._pass = false;
            sandbox._results.push({
                pass: false,
                message: (message || "assertEqual") + ": expected " + expectedStr + ", got " + actualStr
            });
        } else {
            sandbox._results.push({ pass: true, message: message || "OK" });
        }
    },
    assertNotEqual: function(actual, notExpected, message) {
        if (JSON.stringify(actual) === JSON.stringify(notExpected)) {
            sandbox._pass = false;
            sandbox._results.push({
                pass: false,
                message: (message || "assertNotEqual") + ": values should differ but both are " + JSON.stringify(actual)
            });
        } else {
            sandbox._results.push({ pass: true, message: message || "OK" });
        }
    },
    assertContains: function(arr, item, message) {
        const found = Array.isArray(arr) && arr.indexOf(item) >= 0;
        if (!found) {
            sandbox._pass = false;
            sandbox._results.push({
                pass: false,
                message: (message || "assertContains") + ": " + JSON.stringify(item) + " not in " + JSON.stringify(arr)
            });
        } else {
            sandbox._results.push({ pass: true, message: message || "OK" });
        }
    },
    assertThrows: function(fn, message) {
        try {
            fn();
            sandbox._pass = false;
            sandbox._results.push({ pass: false, message: (message || "assertThrows") + ": expected exception but none thrown" });
        } catch(e) {
            sandbox._results.push({ pass: true, message: message || "OK" });
        }
    },
    // File reading for test data
    readFileSync: function(p) {
        return fs.readFileSync(path.resolve(p), 'utf8');
    }
};

vm.createContext(sandbox);

try {
    // Load each module into the sandbox
    for (const modPath of modulePaths) {
        const absPath = path.resolve(modPath);
        let code = fs.readFileSync(absPath, 'utf8');
        // Strip QML-specific directives
        code = code.replace(/^\.pragma\s+library\s*$/m, '// .pragma library (stripped)');
        // Replace console.error/log with sandbox versions (already done via context)
        vm.runInContext(code, sandbox, { filename: path.basename(absPath) });
    }

    // Run the test code
    vm.runInContext(testCode, sandbox, { filename: 'test' });

    // Output results
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
