.pragma library

// ExplanationFormatter — produces the "Why this voicing?" text block surfaced
// next to every voicing in the Walkthrough panel and Library card (#586).
//
// Input contract:
//   format(context) where context = {
//     mode:  { id, name, description } | null,
//     style: { id, name, description } | null,
//     rule:  RuleObject | null,                  // v1 always null; reserved for v2 (#586 follow-up)
//   }
//
// Output contract:
//   {
//     has_rule:        bool,                     // true if rule-driven; v1 always false
//     title:           string,                   // short header, e.g. "Comping · Bebop"
//     body_full:       string,                   // 1-3 sentence prose for Walkthrough
//     body_compact:    string,                   // single-line summary for Library card (tap-to-expand)
//     citation:        string | null,            // "Bergonzi, Melodic Rhythms vol.4, p.47" — null in v1
//     polarity_phrase: string | null,            // "Strong preference (+2)" — null in v1
//     falsifier:       string | null,            // when the rule would NOT fire — null in v1
//     token:           { source, id, payload },  // structured token mirroring the locked v1→v2 contract
//   }
//
// Returns null if both mode and style are null AND rule is null (caller renders nothing).
//
// Token contract (locked 2026-06-23 with Ellington; #586 ticket comment):
//   { source: "style" | "mode" | "rule",
//     id:     <slug>,
//     payload: <see ticket — style/mode shape in v1; rule shape reserved for v2> }


function format(context) {
    if (!context) return null
    var mode = context.mode || null
    var style = context.style || null
    var rule = context.rule || null

    // v1: rule path is reserved but not yet wired in (no plugin-runtime engine_rules consumption).
    // Defensive: if a caller passes rule, route to the rule-shape (lets v2 land without re-touching this file).
    if (rule) {
        return _formatRule(rule)
    }

    // Style/Mode v1 path. Need at least one of the two; both gives the richer rendering.
    if (!mode && !style) return null
    return _formatStyleMode(mode, style)
}


function _formatStyleMode(mode, style) {
    // Title — both / mode-only / style-only forms.
    var title
    if (mode && style) {
        title = mode.name + " · " + style.name
    } else if (mode) {
        title = mode.name
    } else {
        title = style.name
    }

    var modeText = (mode && mode.description) ? mode.description : ""
    var styleText = (style && style.description) ? style.description : ""

    var bodyFullParts = []
    if (modeText) bodyFullParts.push(modeText)
    if (styleText) bodyFullParts.push(styleText)
    var bodyFull = bodyFullParts.join(" ")

    // Compact: prefer mode, fall back to style. Library card tap-expand shows the full block.
    var bodyCompact = modeText || styleText

    // Token mirrors the locked v1→v2 contract. v1 carries the style/mode payload;
    // v2 will use `source: "rule"` with the firing-spec field set.
    var token
    if (mode && style) {
        // Prefer style as the "primary" source token when both are active —
        // style is genre-specific and more informative than the role-mode.
        token = {
            source: "style",
            id: style.id,
            payload: { name: style.name, description: style.description || "" }
        }
    } else if (mode) {
        token = {
            source: "mode",
            id: mode.id,
            payload: { name: mode.name, description: mode.description || "" }
        }
    } else {
        token = {
            source: "style",
            id: style.id,
            payload: { name: style.name, description: style.description || "" }
        }
    }

    return {
        has_rule: false,
        title: title,
        body_full: bodyFull,
        body_compact: bodyCompact,
        citation: null,
        polarity_phrase: null,
        falsifier: null,
        token: token,
    }
}


function _formatRule(rule) {
    // v2 path — reserved. v1 callers will never reach here.
    // Renders against the firing-spec v0.2 contract (rule_id, master_id, work_id, name,
    // anchor, source_page, chapter_n, section_title, preference, falsifier, applicability_reasons).
    var title = rule.name || rule.rule_id || "Untitled rule"

    var citation = null
    if (rule.master_id && rule.work_id && rule.source_page) {
        var sec = rule.section_title ? ", \"" + rule.section_title + "\"" : ""
        citation = rule.master_id + " · " + rule.work_id + ", p." + rule.source_page + sec
    }

    var polarityPhrase = _polarityPhrase(rule.preference)

    return {
        has_rule: true,
        title: title,
        body_full: rule.anchor || "",
        body_compact: rule.anchor ? _shorten(rule.anchor, 80) : "",
        citation: citation,
        polarity_phrase: polarityPhrase,
        falsifier: rule.falsifier || null,
        token: {
            source: "rule",
            id: rule.rule_id,
            payload: {
                rule_id: rule.rule_id,
                master_id: rule.master_id,
                work_id: rule.work_id,
                name: rule.name,
                anchor: rule.anchor,
                source_page: rule.source_page,
                chapter_n: rule.chapter_n,
                section_title: rule.section_title,
                preference: rule.preference,
                falsifier: rule.falsifier,
                applicability_reasons: rule.applicability_reasons || [],
            }
        }
    }
}


function _polarityPhrase(preference) {
    // Signed Likert [-2, 2] per firing-spec v0.2. Used in v2 rule rendering.
    if (preference === null || preference === undefined) return null
    var p = parseInt(preference, 10)
    if (isNaN(p)) return null
    if (p >= 2) return "Strong preference (+2)"
    if (p === 1) return "Preference (+1)"
    if (p === 0) return "Neutral"
    if (p === -1) return "Avoid (-1)"
    if (p <= -2) return "Strong avoidance (-2)"
    return null
}


function _shorten(text, maxLen) {
    if (!text) return ""
    if (text.length <= maxLen) return text
    return text.substring(0, maxLen - 1).replace(/\s+\S*$/, "") + "…"
}
