import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ListView {
    id: voicingGrid
    clip: true
    spacing: 4

    property var voicings: []
    signal voicingSelected(var voicing)

    model: voicings.length

    delegate: VoicingCard {
        width: voicingGrid.width
        voicing: voicingGrid.voicings[index] || {}
        onDoubleClicked: function(v) {
            voicingGrid.voicingSelected(v)
        }
    }

    Label {
        anchors.centerIn: parent
        visible: voicingGrid.voicings.length === 0
        text: "No voicings match filters"
        color: "#999"
        font.pixelSize: 12
    }
}
