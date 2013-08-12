import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.python 1.0


Page {
    id: page
    objectName: 'fileBrowserPage'
    property string searchText: ''

    ListModel {
        id: notesModel

        function applyFilter(text) {
            pyNotes.listNotes(text);
        }

        function fill(data) {
            notesModel.clear();

            // Python returns a list of dicts - we can simply append
            // each dict in the list to the list model
            for (var i=0; i<data.length; i++) {
                notesModel.append(data[i]);
            }
        }

    }

    Connections {
        target: pyNotes
        onMessage: {
            notesModel.fill(data)
        }
        onRequireRefresh: {
            notesModel.applyFilter(searchText)
        }

    }

    // Place our content in a Column.  The PageHeader is always placed at the top
    // of the page, followed by our content.

    Component {
        id:notesViewDelegate

        ListItem {
            /*                Column {
                    x: Theme.paddingLarge
                    height: Theme.itemSizeSmall
                    width: notesView.width*/
            id: listItem
            menu: contextMenuComponent

            RemorseItem { id: remorse }
            function remorseDelete() {
                remorse.execute(listItem, "Deleting", function() {
                    pyNotes.remove(path);
                });

            }


            Label {
                id: itemTitle
                text: model.title
                truncationMode: TruncationMode.Fade
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                //font.weight: Font.Bold
                color:Theme.primaryColor
                //elide: Text.ElideRight
                maximumLineCount: 1
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingSmall
                    rightMargin: Theme.paddingSmall
                }
            }

            Label {
                text: model.timestamp;
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                anchors {
                    left: parent.left
                    leftMargin: Theme.paddingSmall
                    rightMargin: Theme.paddingSmall
                    bottom: parent.bottom
                    bottomMargin: Theme.paddingSmall
                }

                maximumLineCount: 1
            }

            Component {
                id: contextMenuComponent
                ContextMenu {
                    MenuItem {
                        text: "Category"
                        onClicked: {
                            pageStack.push(categoryPage,{path:model.path})
                        }
                    }
                    MenuItem {
                        text: "Duplicate"
                        onClicked: {
                            pyNotes.duplicate(model.path)
                        }
                    }
                    MenuItem {
                        text: "Delete"
                        onClicked: {
                            var path = model.path;
                            remorseDelete();
                        }
                    }
                }
            }

            onClicked: {

                console.log("Clicked " + path)
                var editingPage = Qt.createComponent(Qt.resolvedUrl("EditPage.qml"));
                pageStack.push(editingPage, {path: path});
            }
        }
    }

    SilicaListView {
        id: notesView
        model: notesModel
        anchors.fill: parent
        currentIndex: -1
        header: Column {
            width: parent.width
            PageHeader {
                id: header
                title: "ownNotes"

            }

            ProgressBar {
                width: parent.width
                indeterminate: true
                label: "Sync"
                valueText: "Sync"
                visible: sync.running ? true : false
            }

            SearchField {
                id: searchField
                placeholderText: "Search"
                width: parent.width
                onTextChanged: {
                    searchText = searchField.text;
                    notesModel.applyFilter(searchText)
                }

            }


        }
        section {
            property: 'category'
            delegate: SectionHeader {
                text: section
            }
        }
        delegate: notesViewDelegate

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
            MenuItem {
                text: "About"
                onClicked:
                    pageStack.push(Qt.createComponent(Qt.resolvedUrl("AboutPage.qml")),
                                   {
                                       title : 'ownNotes ' + aboutInfos.version,
                                       icon: Qt.resolvedUrl('/usr/share/ownNotesForSailfish/icons/ownnotes.png'),
                                       slogan : 'Notes in your own cloud !',
                                       text : aboutInfos.text
                                   })

            }
            MenuItem {
                text: "Settings"
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: "Sync"
                onClicked: {
                    if (sync.running === false)
                        sync.launch()
                }

            }
            MenuItem {
                text: "New note"
                onClicked: {
                    var path = pyNotes.createNote();
                    pageStack.push(
                                Qt.createComponent(Qt.resolvedUrl("EditPage.qml")),
                                {path:path});
                }
            }
        }

        PushUpMenu {

            MenuItem {
                text: "New note"
                onClicked: {
                    var path = pyNotes.createNote();
                    console.log('NEWPATH:'+path)
                    pageStack.push(
                                Qt.createComponent(Qt.resolvedUrl("EditPage.qml")),
                                {path:path});
                }
            }
        }

        ViewPlaceholder {
            enabled: notesModel.count == 0
            text: "No notes."
        }

    }
    Component.onCompleted: {
        console.debug('onCompleted notesModel')
        pyNotes.listNotes('');
    }

    //State used to detect when we should refresh view
    onStatusChanged: {
        if (status === PageStatus.Activating) {
            console.log('Page Status Activating (MainPage)')
            notesModel.applyFilter(searchText);
        }

    }

    Component {
        id: categoryPage

        Dialog {
            //canAccept: selector.value != ''
            acceptDestination: page
            acceptDestinationAction: PageStackAction.Pop
            property string path
            property string category

            ListModel {
                id: categoryModel

                function fill(data) {
                    categoryModel.clear();

                    // Python returns a list of dicts - we can simply append
                    // each dict in the list to the list model
                    for (var i=0; i<data.length; i++) {
                        console.log(data[i]);
                        categoryModel.append(data[i]);
                    }
                }

                Component.onCompleted: {
                    fill(pyNotes.getCategories());
                }
            }


            Flickable {
                // ComboBox requires a flickable ancestor
                width: parent.width
                height: parent.height
                interactive: false

                Column {
                    width: parent.width

                    DialogHeader {
                        acceptText: selector.value
                    }


                    TextField {
                        id: categoryField
                        text:''
                        width: parent.width
                        onTextChanged:  {
                            selector.value = text
                        }
                    }

                    ComboBox {
                        id: selector

                        width: parent.width
                        label: 'Category:'
                        currentIndex: -1

                        menu: ContextMenu {
                            Repeater {
                                model: categoryModel

                                MenuItem {
                                    text: modelData
                                }
                            }
                        }
                    }
                }
            }

            onAccepted: {
                //wizard.selection = selector.value
                pyNotes.setCategory(path, selector.value)
            }
        }
    }

}


