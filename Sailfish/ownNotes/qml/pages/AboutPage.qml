import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0


Page {
    id: page

    property alias title:title.text
    property alias icon: icon.source
    property alias slogan: slogan.text
    property string contentText

    SilicaFlickable {
        id: aboutFlick
        anchors.fill: parent
        contentHeight: contentItem.childrenRect.height
        contentWidth: aboutFlick.width

        Column {
            id: aboutColumn

            anchors {
                left: parent.left
                right: parent.right
                margins: 0
            }

            spacing: 2

            PageHeader {
                title: qsTr('About ownNotes')
            }

            Image {
                id: icon
                source: ''
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Label {
                id:title
                text: 'Name 0.0.0'
                font.pixelSize: 40
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Label {
                id: slogan
                text: 'Slogan!'
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item {
                width: 1
                height: 50
            }

            TextArea {
                id: content
                text: '<style>a:link {color: ' + Theme.highlightColor + '; }</style>' + contentText
                width: aboutFlick.width
                wrapMode: TextEdit.WordWrap
                readOnly: true
                Component.onCompleted: {
                    _editor.textFormat = Text.RichText;
                }
            }
        }
    }
}





