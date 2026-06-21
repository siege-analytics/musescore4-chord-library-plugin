.pragma library

// #578: debug-flag gate for model-layer logging.
//
// Bare console.log() calls in the .pragma library / model layer create
// noisy production output and were flagged by external review 2026-06-21.
// This module routes all model-layer diagnostic output through a single
// flag so a) production stays quiet, and b) developers can enable logs
// without re-editing call sites.
//
// Usage:
//   import "DebugLog.js" as DebugLog
//   DebugLog.log("setDot() API detected — using direct insertion")
//
// To enable model-layer logs at runtime, set DEBUG to true here and
// rebuild. (A QML-side runtime toggle could be added later.)

var DEBUG = false;

function log(msg) {
    if (DEBUG) {
        console.log("[model] " + msg);
    }
}

function warn(msg) {
    // Warnings remain visible even when DEBUG is off — they signal
    // a fallback or recoverable error path the operator should know about.
    console.warn("[model] " + msg);
}
