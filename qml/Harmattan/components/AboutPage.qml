import QtQuick 1.1
import com.nokia.meego 1.0

Page {
    id: aboutPage
    property alias iconSource: icon.source
    property alias title: title.text
    property alias slogan: slogan.text
    property alias text: content.text


    tools: ToolBarLayout {
        ToolIcon {
            iconId: 'toolbar-back'
            onClicked: pageStack.pop()
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: aboutContainer.height + 10
        contentWidth: aboutContainer.width - 10

        Item {
            id: aboutContainer
            width: aboutPage.width - 20
            height: aboutColumn.height

            Column {
                id: aboutColumn

                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                    margins: 10
                }

                spacing: 10

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

                Label {
                    id: content
                    text: ''
                   // textFormat: Text.RichText
                    width: aboutContainer.width
                    wrapMode: TextEdit.WordWrap
                }
            }
        }
    }
}
