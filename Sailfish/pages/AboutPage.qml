import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0


Page {
    id: page

    property alias title:title.text
    property alias icon: icon.source
    property alias slogan: slogan.text
    property alias text: content.text

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
                margins: 10
            }

            spacing: 10

            PageHeader {
                title: 'About ownNotes'
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
                text: 'Slogan !'
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item {
                width: 1
                height: 50
            }

            TextArea {
                id: content
                text: ''
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





