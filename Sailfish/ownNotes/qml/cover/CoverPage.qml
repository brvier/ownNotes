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
        source: Qt.resolvedUrl('/usr/share/ownNotes/icons/cover.png')
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter;
        opacity: 0.3
        scale: 2.0
    }

    Label {
        id: subNoteLabel
        anchors.horizontalCenter: label.horizontalCenter
        anchors.top: label.bottom
        anchors.topMargin: 5
        text: {if (sync.running === true) qsTr("Syncing ..."); else sync.get_last_sync_datetime()}
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        //visible: sync.running
        //opacity: visible === true ? 1.0 : 0.0

    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-sync"
            onTriggered: {
                if (sync.running === false)
                    sync.launch()
            }
        }

        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                appWindow.activate();
                var path = pyNotes.createNote();
                pageStack.push(
                            Qt.createComponent(Qt.resolvedUrl("../pages/EditPage.qml")),
                            {path:path});
            }
        }

    }
}


