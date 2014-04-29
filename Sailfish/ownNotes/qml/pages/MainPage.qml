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

        function rm(path) {
            for (var i=0; i<data.length; i++) {
                if (notesModel.get(i).path === path ) {
                    notesModel.remove(i);
                    break;
                }
            }
        }
    }

    Connections {
        target: pyNotes
        onMessage: {
            notesModel.fill(data)
        }
        onRequireRefresh: {
            if (page.status === PageStatus.Active) {
                notesModel.applyFilter(searchText);
            }
        }
        onNoteDeleted: {
            notesModel.rm(path)
        }

    }


    Component {
        id:notesViewDelegate

        ListItem {
            id: listItem
            menu: contextMenuComponent

            RemorseItem { id: remorse }
            function remorseDelete() {
                remorse.execute(listItem, qsTr("Deleting"), function() {
                    console.log('ownNotes.rm:'+path)
                    if (path !== undefined)
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
                        text: qsTr("Category")
                        onClicked: {
                            pageStack.push(categoryPage,{path:model.path})
                        }
                    }
                    MenuItem {
                        text: qsTr("Duplicate")
                        onClicked: {
                            pyNotes.duplicate(model.path)
                        }
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        onClicked: {
                            var path = model.path;
                            remorseDelete();
                        }
                    }
                }
            }

            onClicked: {
                var editingPage = Qt.createComponent(Qt.resolvedUrl("EditPage.qml"));
                pageStack.push(editingPage, {path: path});
            }
        }
    }

    // Place our content in a Column.  The PageHeader is always placed at the top
    // of the page, followed by our content.
    SilicaListView {
        id: notesView
        model: notesModel
        anchors.fill: parent
        currentIndex: -1
        header: Column {
            width: parent.width
            height: header.height + searchField.height

            PageHeader {
                id: header
                title: "ownNotes"
            }

            SearchField {
                id: searchField
                placeholderText: qsTr("Search")
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
            id: pullDownMenu
            busy: sync.running

            MenuItem {
                text: qsTr("About")
                onClicked: {
                    aboutInfos.changelog = pyNotes.readChangeslog();
                    pageStack.push(Qt.createComponent(Qt.resolvedUrl("AboutPage.qml")),
                                   {
                                       title : 'ownNotes ' + aboutInfos.version,
                                       icon: Qt.resolvedUrl('/usr/share/ownNotes/icons/ownnotes.png'),
                                       slogan : qsTr('Notes in your own cloud !'),
                                       contentText : aboutInfos.firstPart + aboutInfos.changelog + aboutInfos.secondPart
                                   })}

            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: qsTr("Sync")
                onClicked: {
                    if (sync.running === false)
                        sync.launch()
                }

            }
            MenuItem {
                text: qsTr("New note")
                onClicked: {
                    var path = pyNotes.createNote();
                    pageStack.push(
                                Qt.createComponent(Qt.resolvedUrl("EditPage.qml")),
                                {path:path});
                }
            }

            MenuLabel {
                text: pullDownMenu.busy == true ? qsTr("Syncing ...") : ""
            }

        }

        PushUpMenu {

            MenuItem {
                text: qsTr("New note")
                onClicked: {
                    var path = pyNotes.createNote();
                    console.log('NEWPATH:'+path)
                    pageStack.push(
                                Qt.createComponent(Qt.resolvedUrl("EditPage.qml")),
                                {path:path});
                }
            }
        }

        VerticalScrollDecorator {
        }

        ViewPlaceholder {
            enabled: notesModel.count == 0
            text: qsTr("No notes.")
        }

        Component.onCompleted: {
            notesView.scrollToTop()
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
                        label: qsTr('Category:')
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
                pyNotes.setCategory(path, selector.value)
            }
        }
    }

    //State used to detect when we should refresh view
    onStatusChanged: {
        if (status === PageStatus.Active) {
            console.log('Page Status Activating (MainPage)')
            notesModel.applyFilter(searchText);
        }
    }

    Item {
        id: aboutInfos
        property string version:VERSION
        property string changelog:''
        property string firstPart:qsTr('A note taking application with sync for ownCloud or any WebDav.') +
                                    '<br>' + qsTr('Web Site : http://khertan.net/ownnotes') +
                                    '<br><br>' + qsTr('By') +' Benoît HERVIER (Khertan)' +
                                    '<br><b>' + qsTr('Licensed under GPLv3') + '</b>'+
                                    '<br><br><b>Changeslog : </b><br><br>'
        property string secondPart: '<br><br><b>Thanks to : </b>' +
                                    '<br>* Radek Novacek' +
                                    '<br>* caco3 on talk.maemo.org for debugging' +
                                    '<br>* Thomas Perl for PyOtherSide' +
                                    '<br>* Antoine Vacher for debugging help and tests' +
                                    '<br>* 太空飞瓜 for Chinese translation' +
                                    '<br>* Janne Edelman for Finnish translation' +
                                    '<br>* André Koot for Dutch translation' +
                                    '<br>* Equeim for Russian translation and translation patch' +
                                    '<br><br><b>Privacy Policy : </b>' +
                                    '<br>ownNotes can sync your notes with a webdav storage or ownCloud instance. For this ownNotes need to know the Url, Login and Password to connect to. But this is optionnal, and you can use ownNotes without the sync feature.' +
                                    '<br><br>' +
                                    'Which datas are transmitted :' +
                                    '<br>* Login and Password will only be transmitted to the url you put in the Web Host setting.' +
                                    '<br>* When using the sync features all your notes can be transmitted to the server you put in the Web Host setting' +
                                    '<br><br>' +
                                    'Which datas are stored :' +
                                    '<br>* All notes are stored as text files' +
                                    '<br>* An index of all files, with last synchronization datetime' +
                                    '<br>* Url & Path of the server, and login and password are stored in the settings file.'  +
                                    '<br><br>' +
                                    '<b>Markdown format :</b>' +
                                    '<br>For a complete documentation on the markdown format,' +
                                    ' see <a href="http://daringfireball.net/projects/markdown/syntax">Daringfireball Markdown Syntax</a>. Hilighting on ownNotes support only few tags' +
                                    'of markdown syntax: title, bold, italics, links'
    }
}


