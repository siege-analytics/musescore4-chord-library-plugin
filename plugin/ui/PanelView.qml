import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: panelView
    spacing: 8

    property var libraryModel
    signal insertRequested(var voicing)

    // Header
    Label {
        text: "Chord Library"
        font.pixelSize: 16
        font.bold: true
        Layout.fillWidth: true
    }

    // Search
    SearchBar {
        Layout.fillWidth: true
        onSearchChanged: function(text) {
            libraryModel.searchText = text
            libraryModel.applyFilters()
        }
        onClearRequested: {
            libraryModel.clearFilters()
            filterBar.reset()
        }
    }

    // Filters
    FilterBar {
        id: filterBar
        Layout.fillWidth: true
        onContextChanged: function(ctx) {
            libraryModel.filterContext = ctx
            libraryModel.applyFilters()
        }
        onCategoryChanged: function(cat) {
            libraryModel.filterCategory = cat
            libraryModel.applyFilters()
        }
        onQualityChanged: function(qual) {
            libraryModel.filterQuality = qual
            libraryModel.applyFilters()
        }
    }

    // Status
    Label {
        text: {
            if (libraryModel.loading) return "Loading..."
            if (libraryModel.error) return libraryModel.error
            return libraryModel.filteredVoicings.length + " of " + libraryModel.voicings.length + " voicings"
        }
        font.pixelSize: 11
        color: libraryModel.error ? theme.errorText : theme.textSecondary
    }

    // Voicing list
    VoicingGrid {
        Layout.fillWidth: true
        Layout.fillHeight: true
        voicings: libraryModel.filteredVoicings
        onVoicingSelected: function(v) {
            panelView.insertRequested(v)
        }
    }
}
