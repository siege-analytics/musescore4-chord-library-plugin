// _jsLoader.js — Shared loader for QML .pragma library JavaScript modules.
//
// Provides:
//   createSandbox(options)  — build a vm sandbox with common globals + an
//                              optional assertion collector
//   loadModules(sandbox, modulePaths) — load + strip QML directives + eval
//                              each module into the sandbox
//
// Used by:
//   tests/js_runner.js          — test harness (uses the assertion collector)
//   scripts/engine_dump.js      — engine-dump shim (#400; doesn't use the
//                                  assertion collector, only the loader)
//
// Refactored out of js_runner.js per ticket #400 so the loading semantics
// stay in one place and any future consumers (more shim scripts, headless
// diagram renderers, etc.) get the same behaviour for free.

const fs = require('fs');
const vm = require('vm');
const path = require('path');

/**
 * Build a vm sandbox seeded with the common ECMAScript globals every
 * QML .pragma library module needs. Suppresses `console.log` from
 * loaded modules so it doesn't interleave with the harness's own
 * JSON-on-stdout output.
 *
 * @param {Object} [options]
 * @param {boolean} [options.collectAssertions=false] — when true, the
 *   sandbox exposes `assert`, `assertEqual`, `assertNotEqual`,
 *   `assertContains`, `assertThrows`, and `_results` / `_pass`. Tests
 *   use this; the shim does not.
 * @param {boolean} [options.exposeFs=false] — when true, the sandbox
 *   exposes `readFileSync(path)` for tests that load fixture data.
 * @returns {Object} an unfrozen object suitable for vm.createContext.
 */
function createSandbox(options) {
    options = options || {};
    const sandbox = {
        console: {
            log: function() {},   // suppress module console.log
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
        undefined: undefined
    };

    if (options.collectAssertions) {
        sandbox._results = [];
        sandbox._pass = true;
        sandbox.assert = function(condition, message) {
            if (!condition) {
                sandbox._pass = false;
                sandbox._results.push({ pass: false, message: message || "Assertion failed" });
            } else {
                sandbox._results.push({ pass: true, message: message || "OK" });
            }
        };
        sandbox.assertEqual = function(actual, expected, message) {
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
        };
        sandbox.assertNotEqual = function(actual, notExpected, message) {
            if (JSON.stringify(actual) === JSON.stringify(notExpected)) {
                sandbox._pass = false;
                sandbox._results.push({
                    pass: false,
                    message: (message || "assertNotEqual") + ": values should differ but both are " + JSON.stringify(actual)
                });
            } else {
                sandbox._results.push({ pass: true, message: message || "OK" });
            }
        };
        sandbox.assertContains = function(arr, item, message) {
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
        };
        sandbox.assertThrows = function(fn, message) {
            try {
                fn();
                sandbox._pass = false;
                sandbox._results.push({ pass: false, message: (message || "assertThrows") + ": expected exception but none thrown" });
            } catch(e) {
                sandbox._results.push({ pass: true, message: message || "OK" });
            }
        };
    }

    if (options.exposeFs) {
        sandbox.readFileSync = function(p) {
            return fs.readFileSync(path.resolve(p), 'utf8');
        };
    }

    return sandbox;
}

/**
 * Load each .js module into an already-contextified sandbox.
 *
 * Strips the QML `.pragma library` directive (Qt's marker for a
 * library module) before evaluation so `vm.runInContext` doesn't
 * reject the syntax. The original line is preserved as a comment for
 * readability when debugging stack traces.
 *
 * @param {Object} sandbox — must already have been passed through
 *   vm.createContext() by the caller.
 * @param {string[]} modulePaths — absolute or working-directory-
 *   relative paths to .js modules to evaluate.
 */
function loadModules(sandbox, modulePaths) {
    for (const modPath of modulePaths) {
        const absPath = path.resolve(modPath);
        let code = fs.readFileSync(absPath, 'utf8');
        // Strip QML-specific directive (one per file, at top of file).
        code = code.replace(/^\.pragma\s+library\s*$/m, '// .pragma library (stripped)');
        vm.runInContext(code, sandbox, { filename: path.basename(absPath) });
    }
}

module.exports = {
    createSandbox: createSandbox,
    loadModules: loadModules
};
