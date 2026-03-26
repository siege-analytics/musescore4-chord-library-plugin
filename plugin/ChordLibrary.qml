import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import "ui"
import "model"

MuseScore {
    id: chordLibrary
    title: "Chord Library"
    description: "Jazz guitar chord voicing library with filtering and auto-transposition"
    version: "0.2.0"
    pluginType: "dock"
    dockArea: "right"

    width: 340
    height: 600

    property string jsonUrl: "https://raw.githubusercontent.com/siege-analytics/musescore4-chord-library-plugin/main/data/voicings.json"

    LibraryModel {
        id: library
        jsonUrl: chordLibrary.jsonUrl
    }

    VoicingInserter {
        id: inserter
    }

    Component.onCompleted: {
        library.fetchVoicings()
    }

    PanelView {
        anchors.fill: parent
        anchors.margins: 8
        libraryModel: library
        onInsertRequested: function(voicing) {
            var result = inserter.insertAtCursor(voicing, curScore)
            if (result.success) {
                statusMessage.text = result.message
                statusMessage.color = "#060"
            } else {
                statusMessage.text = result.message
                statusMessage.color = "#c00"
            }
        }
    }

    // Status message overlay (bottom)
    Label {
        id: statusMessage
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        wrapMode: Text.WordWrap
        font.pixelSize: 10
        color: "#666"
        text: ""

        Timer {
            running: statusMessage.text.length > 0
            interval: 8000
            onTriggered: statusMessage.text = ""
        }
    }
}
