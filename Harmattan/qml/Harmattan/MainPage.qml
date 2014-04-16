import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1
import 'components'
import net.khertan.python 1.0

Page {
    tools: mainTools
    objectName: 'fileBrowserPage'
    property string searchFieldText: searchField.text

    PageHeader {
        id: pageHeader
        title: 'ownNotes'
    }

    Component {
        id: notesCategory
        Rectangle {
            width: notesView.width
            height: 40
            color: "#555"

            Label {
                text: section
                font.bold: true
                font.family: "Nokia Pure Text"
                font.pixelSize: 18
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.fill: parent
             }
        }
    }

    SearchField {
        id: searchField
        onTextChanged: notesModel.applyFilter(text)
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
        }
    }

    ItemMenu {
        id: itemMenu
    }

    ListModel {
        id: notesModel

        function applyFilter(searchText) {
            pyNotes.listNotes(searchText);
        }

        function fill(data) {
            notesModel.clear()

            // Python returns a list of dicts - we can simply append
            // each dict in the list to the list model
            for (var i=0; i<data.length; i++) {
                notesModel.append(data[i])
            }
        }

        Component.onCompleted: {
            pyNotes.listNotes('');
        }

    }

    Connections {
        target: pyNotes
        onMessage: {
            notesModel.fill(data)
        }
        onRequireRefresh: {
            notesModel.applyFilter(searchField.text)
        }

    }

    ListView {
        id: notesView
        anchors.top: searchField.bottom
        anchors.bottom: parent.bottom
        height: pageHeader.height
        width: parent.width
        clip: true
        z:1

        model: notesModel

        delegate: Component {
            id: fileDelegate
            Rectangle {
                width:parent.width
                height: 80
                anchors.leftMargin: 10
                color:"white"

                Rectangle {
                    id: background
                    anchors.fill: parent
                    color: "darkgray";
                    opacity: 0.0
                    Behavior on opacity { NumberAnimation {} }
                }

                Column {
                    spacing: 10
                    anchors.leftMargin:10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Label {text: model.title
                        font.family: "Nokia Pure Text"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        color:"black"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Label {
                        text: model.timestamp;
                        font.family: "Nokia Pure Text"
                        font.pixelSize: 16
                        color: "#cc6633"
                        anchors.left: parent.left;
                        anchors.right: parent.right
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                }


                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-toolbar-favorite-mark"
                    visible: favorited
                    opacity: favorited ? 1.0 : 0.0
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: background.opacity = 1.0;
                    onReleased: background.opacity = 0.0;
                    onPositionChanged: background.opacity = 0.0;

                    onClicked: {
                        var editingPage = Qt.createComponent(Qt.resolvedUrl("EditPage.qml"));
                        pageStack.push(editingPage, {path: path});
                    }

                    onPressAndHold: {
                        itemMenu.path = model.path;
                        itemMenu.open();
                    }
                }
            }
        }

        section.property: "category"
        section.criteria: ViewSection.FullString
        section.delegate: notesCategory

    }

    SectionScroller {
        id:sectionScroller
        listView: notesView
        z:4
    }

    ScrollDecorator {
        id: scrollDecorator
        flickableItem: notesView
        z:3
        platformStyle: ScrollDecoratorStyle {
        }
    }

    ToolBarLayout {
        id: mainTools
        visible: true
        ToolIcon {
            platformIconId: "toolbar-add"
            onClicked: {
                var path = pyNotes.createNote();
                console.log('NEWPATH:'+path)
                pageStack.push(
                    Qt.createComponent(Qt.resolvedUrl("EditPage.qml")),
                                       {path:path});
            }
        }
        ToolIcon {
            platformIconId: 'toolbar-refresh'
            visible: sync.Running ? false : true;
            onClicked: sync.launch()
        }
        ToolIcon {
            platformIconId: "toolbar-view-menu"
            anchors.right: (parent === undefined) ? undefined : parent.right
            onClicked: (myMenu.status === DialogStatus.Closed) ? myMenu.open() : myMenu.close()
        }

    }

    ComboxDialog {
        property string path
        id: categoryQueryDialog
        titleText: 'Pick a category'
        onAccepted: {
             pyNotes.setCategory(path, categoryQueryDialog.text);
        }
    }

    QueryDialog {

        property string path

        id: deleteQueryDialog
        icon: Qt.resolvedUrl('../../icons/ownnotes.png')
        titleText: "Delete"
        message: "Are you sure you want to delete this note ?"
        acceptButtonText: qsTr("Delete")
        rejectButtonText: qsTr("Cancel")
        onAccepted: {
            pyNotes.remove(path);
        }
    }

    //State used to detect when we should refresh view
    states: [
        State {
            name: "fullsize-visible"
            when: platformWindow.viewMode === WindowState.Fullsize && platformWindow.visible
            StateChangeScript {
                script: {
                    if (pageStack.currentPage.objectName === 'fileBrowserPage')
                        notesModel.applyFilter(searchField.text);
                    
                    }
        }
        }
    ]

}    
