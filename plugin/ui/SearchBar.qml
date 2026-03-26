import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: searchBar
    spacing: 4

    signal searchChanged(string text)
    signal clearRequested()

    TextField {
        id: searchField
        placeholderText: "Search voicings..."
        Layout.fillWidth: true
        onTextChanged: searchBar.searchChanged(text)
    }

    Button {
        text: "Clear"
        visible: searchField.text.length > 0
        onClicked: {
            searchField.text = ""
            searchBar.clearRequested()
        }
    }
}
