import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ExportPanel — Export tab UI (Tab 2).
// Displays export path field and format buttons.
// All export logic stays in ChordLibrary.qml; this is the template.

Flickable {
    id: exportPanel

    // Data in
    property string defaultPath: ""
    property string statusText: ""
    property color statusColor: "black"

    // Actions out
    signal exportJson()
    signal exportMusicXML()
    signal exportGP5()
    signal exportChordSheet()
    signal exportDiagramsSVG()
    signal browseClicked(var targetField)

    // Expose path for parent to read
    property alias exportPath: exportPathField.text

    Layout.fillWidth: true
    Layout.fillHeight: true
    contentHeight: exportColumn.implicitHeight
    clip: true
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: exportColumn
        width: parent.width - 16
        spacing: 12

        Label {
            text: "Save current library to a file:"
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            TextField {
                id: exportPathField
                Layout.fillWidth: true
                font.pixelSize: 11
                text: exportPanel.defaultPath
                selectByMouse: true
            }

            Button {
                text: "Browse"
                onClicked: exportPanel.browseClicked(exportPathField)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Button {
                text: "Export JSON"
                font.pixelSize: 10
                onClicked: exportPanel.exportJson()
            }

            Button {
                text: "Export MusicXML"
                font.pixelSize: 10
                onClicked: exportPanel.exportMusicXML()
            }

            Button {
                text: "Export GP5"
                font.pixelSize: 10
                onClicked: exportPanel.exportGP5()
            }

            Button {
                text: "Chord Sheet (PDF)"
                font.pixelSize: 10
                onClicked: exportPanel.exportChordSheet()
            }

            Button {
                text: "Diagrams (SVG)"
                font.pixelSize: 10
                onClicked: exportPanel.exportDiagramsSVG()
            }
        }

        Label {
            id: exportStatusLabel
            visible: text.length > 0
            text: exportPanel.statusText
            color: exportPanel.statusColor
            font.pixelSize: 11
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
