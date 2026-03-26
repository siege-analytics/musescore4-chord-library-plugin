import QtQuick 2.15

QtObject {
    id: libraryModel

    property var voicings: []
    property var filteredVoicings: []
    property bool loading: false
    property string error: ""

    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"

    // Filter state
    property string filterContext: ""
    property string filterCategory: ""
    property string filterQuality: ""
    property int filterStrings: 0  // 0 = all, 6 or 7
    property string searchText: ""

    // Derived lists for filter dropdowns
    readonly property var contexts: extractUnique("context")
    readonly property var categories: extractUnique("category")
    readonly property var qualities: extractUnique("chord_quality")

    function fetchVoicings() {
        loading = true
        error = ""
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        voicings = data.voicings || []
                        applyFilters()
                        console.log("Loaded " + voicings.length + " voicings")
                    } catch (e) {
                        error = "Failed to parse voicings JSON: " + e
                        console.error(error)
                    }
                } else {
                    error = "Failed to fetch voicings: HTTP " + xhr.status
                    console.error(error)
                }
            }
        }
        xhr.open("GET", jsonUrl)
        xhr.send()
    }

    function applyFilters() {
        var result = []
        for (var i = 0; i < voicings.length; i++) {
            var v = voicings[i]
            if (filterContext && v.context !== filterContext) continue
            if (filterCategory && v.category !== filterCategory) continue
            if (filterQuality && v.chord_quality !== filterQuality) continue
            if (filterStrings > 0 && v.strings !== filterStrings) continue
            if (searchText) {
                var q = searchText.toLowerCase()
                var match = v.name.toLowerCase().indexOf(q) >= 0
                    || v.chord_quality.toLowerCase().indexOf(q) >= 0
                    || (v.tags && v.tags.join(" ").toLowerCase().indexOf(q) >= 0)
                if (!match) continue
            }
            result.push(v)
        }
        filteredVoicings = result
    }

    function extractUnique(field) {
        var seen = {}
        var result = []
        for (var i = 0; i < voicings.length; i++) {
            var val = voicings[i][field]
            if (val && !seen[val]) {
                seen[val] = true
                result.push(val)
            }
        }
        result.sort()
        return result
    }

    function clearFilters() {
        filterContext = ""
        filterCategory = ""
        filterQuality = ""
        filterStrings = 0
        searchText = ""
        applyFilters()
    }
}
