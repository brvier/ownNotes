import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover
    allowResize: true
    property string current: ""
    property bool preview: (current !== "")

    Component.onCompleted: {
        current = pyNotes.get('Display', 'covernote');
    }

    Connections {
        target: pyNotes
        onRequireRefresh: {
            if (cover.status == Cover.Active) {
                console.log("Require refresh")
                cover.updateCoverText(0)
            }
        }
        onNoteDeleted: {
            if (cover.status == Cover.Active) {
                console.log("Note delete")
                cover.updateCoverText(0)
            }
        }
    }

    Label {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (cover.size === Cover.Small ? -Theme.paddingLarge : 0)
        text: "ownNotes"
        font {
            pixelSize: (cover.size === Cover.Small ? Theme.fontSizeExtraSmall : Theme.fontSizeMedium)
        }

        visible: !cover.preview
    }
    Image {
        id: icon
        source: (cover.size == Cover.Small ?
                    Qt.resolvedUrl('/usr/share/ownNotes/icons/coversmall.png') :
                    Qt.resolvedUrl('/usr/share/ownNotes/icons/coverlarge.png'))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter;
        opacity: 0.15
        scale: 1.0
    }

    Column {
        id: previewNote
        width: parent.width
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.paddingMedium
        anchors.leftMargin: (cover.size === Cover.Small ? Theme.paddingMedium : Theme.paddingLarge)
        anchors.rightMargin: (cover.size === Cover.Small ? Theme.paddingMedium : Theme.paddingLarge)
        spacing: 2
        visible: cover.preview

        Text {
            id: previewTitle
            text: cover.current.substring(cover.current.lastIndexOf("/") + 1, cover.current.length - 4)
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            color: Theme.highlightColor
            font {
                pixelSize: (cover.size === Cover.Small ? Theme.fontSizeTiny : Theme.fontSizeExtraSmall)
                family: Theme.fontFamily
                weight: Font.Bold
            }
            width: parent.width

        }

        Item {
            Text {
                id: previewBody
                text: ""
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: Theme.primaryColor
                font {
                    pixelSize: Theme.fontSizeTiny
                    family: Theme.fontFamily
                }
                clip: true
                width: parent.width
                height: parent.height
            }
            width: parent.width
            height: parent.height - Theme.paddingLarge - previewTitle.height

            OpacityRampEffect {
                sourceItem: previewBody
                direction: OpacityRamp.TopToBottom
                offset: 0.5
                slope: 2.0
            }
        }
    }

    Label {
        id: subNoteLabel
        anchors.horizontalCenter: label.horizontalCenter
        anchors.top: label.bottom
        anchors.topMargin: 5
        text: {if (sync.running === true) qsTr("Syncing ..."); else sync.get_last_sync_datetime()}

        font {
            family: Theme.fontFamily
            pixelSize: (cover.size === Cover.Small ? Theme.fontSizeTiny : Theme.fontSizeSmall)
        }
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - Theme.paddingMedium
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        //visible: sync.running
        //opacity: visible === true ? 1.0 : 0.0
        visible: !cover.preview
    }

    onStatusChanged: {
        if (status == Cover.Activating) {
            console.log("Update")
            updateCoverText(0);
        }
    }

    CoverActionList {
        id: coverActions

        CoverAction {
            iconSource: "image://theme/icon-cover-previous"
            onTriggered: {
                updateCoverText(-1);
            }
        }

        CoverAction {
            iconSource: "image://theme/icon-cover-next"
            onTriggered: {
                updateCoverText(+1);
            }
        }
    }

    function updateCoverText(offset) {
        var current = cover.current;
        current = pyNotes.nextNoteFile(current, offset);
        cover.current = current;
        pyNotes.set('Display', 'covernote', current);
        if (current !== '') {
            var txt = pyNotes.loadPreview(current);
            previewBody.text = txt;
        }
    }
}


