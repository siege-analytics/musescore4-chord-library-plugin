import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    id: filterBar
    spacing: 4

    signal contextChanged(string context)
    signal categoryChanged(string category)
    signal qualityChanged(string quality)

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        ComboBox {
            id: contextFilter
            model: ["All Contexts", "CM6", "CM7", "CV6", "CV7"]
            Layout.fillWidth: true

            property var contextLabels: {
                "CM6": "Chord Melody — 6 string",
                "CM7": "Chord Melody — 7 string",
                "CV6": "Comping/Vocal — 6 string",
                "CV7": "Comping/Vocal — 7 string"
            }

            displayText: {
                if (currentText === "All Contexts") return currentText
                return contextLabels[currentText] || currentText
            }

            onCurrentTextChanged: {
                contextChanged(currentText === "All Contexts" ? "" : currentText)
            }
        }

        ComboBox {
            id: categoryFilter
            model: ["All Types", "shell", "drop2", "drop3", "extended", "altered", "quartal"]
            Layout.fillWidth: true
            onCurrentTextChanged: {
                categoryChanged(currentText === "All Types" ? "" : currentText)
            }
        }
    }

    ComboBox {
        id: qualityFilter
        model: ["All Qualities", "maj7", "dom7", "min7", "min7b5", "maj6", "min6", "dim7",
                "dom7b9", "dom7sharp5", "dom7alt", "dom9", "sus4"]
        Layout.fillWidth: true
        onCurrentTextChanged: {
            qualityChanged(currentText === "All Qualities" ? "" : currentText)
        }
    }

    function reset() {
        contextFilter.currentIndex = 0
        categoryFilter.currentIndex = 0
        qualityFilter.currentIndex = 0
    }
}
