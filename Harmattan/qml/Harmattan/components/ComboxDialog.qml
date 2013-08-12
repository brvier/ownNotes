import QtQuick 1.1
import com.nokia.meego 1.0

  Dialog {
    property alias placeholder: textfield.placeholderText
    property alias text: textfield.text
    property alias titleText: titleField.text
    property alias model: view.model

    id: root
    title: Label {
        id: titleField
        width: parent.width
        color: "white"
        text: 'Title'
        height: 50
    }

    content: 
        Rectangle {
            anchors.fill: parent
            id: contentItem
            height: 250
            color: '#000'

            TextField {
                id: textfield
                width: contentItem.width
                anchors.top: parent.top
            }

            ListView {
                id: view
                height: parent.height - textfield.height - 10
                anchors.bottom: parent.bottom
                width: contentItem.width
                clip: true

                model: ListModel {
                    /*function fill(data) {
                        notesModel.clear()

                        // Python returns a list of dicts - we can simply append
                        // each dict in the list to the list model
                        for (var i=0; i<data.length; i++) {
                            notesModel.append(data[i])
                        }
                    }

                    Component.onCompleted: {
                        pyNotes.listNotes('');
                    }*/

                }

                delegate: Component{
                    id: listViewDelegate
                    Label {
                        text: model.name
                        color: 'white'
                        height: 50
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                textfield.text = model.name
                            }
                        //}
                    }
                }
            }
        }
    }

    buttons: ButtonRow {
        style: ButtonStyle { }
        anchors.horizontalCenter: parent.horizontalCenter
        Button {text: "OK"; onClicked: root.accept()}
    }
}
