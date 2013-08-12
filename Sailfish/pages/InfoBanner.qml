import QtQuick 2.0
import Sailfish.Silica 1.0
import net.khertan.python 1.0
import Sailfish.Silica.theme 1.0

DockedPanel {
    id: root

    width: Screen.width - 2*Theme.paddingSmall
    height: content.height + 2*Theme.paddingSmall

    dock: Dock.Top

    Rectangle {
        id: content
        x: Theme.paddingSmall
        y: Theme.paddingSmall
        width: parent.width

        height: infoLabel.height + 2*Theme.paddingSmall
        color: 'black';
        opacity: 0.75;

        Label {
            id: infoLabel
            text : ''
            color: 'red'
            width: parent.width - 2*Theme.paddingSmall
            x: Theme.paddingSmall
            y: Theme.paddingSmall
            wrapMode: Text.WrapAnywhere
            }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.hide()
                autoClose.stop()
            }
        }
    }


    function displayError(errorMsg) {
        infoLabel.text = errorMsg
        root.show()
        autoClose.start()
    }

    Timer {
        id: autoClose
        interval: 15000
        running: false
        onTriggered: {
            root.hide()
            stop()
        }

    }
}
