import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Label {
        id: label
        anchors.centerIn: parent
        text: "ownNotes"
    }
    Image {
        id: icon
        source: Qt.resolvedUrl('/opt/ownNotes/icons/ownnotes.png')
        anchors.horizontalCenter: label.horizontalCenter
        anchors.bottom: label.top
    }

}


