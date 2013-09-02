import QtQuick 2.1
import QtQuick.Controls 1.0
import QtQuick.Controls.Styles 1.0
import QtQuick.Window 2.0
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.0
import net.khertan.python 1.0

ApplicationWindow {
    title: qsTr("ownNotes")
    width: 640
    height: 480

    Item {
        id: aboutInfos
        property string version:'1.0.1'
        property string text:'A note taking application with sync for ownCloud or any WebDav.' +
                             '<br>Web Site : http://khertan.net/ownnotes' +
                             '<br><br>By Benoît HERVIER (Khertan)' +
                             '<br><b>Licensed under GPLv3</b>' +
                             '<br><br><b>Changelog : </b><br>' +
                             '<br>1.0.0 : <br>' +
                             '  * Initial Fork from KhtNotes<br>' +
                             '  * Use PyOtherSide instead of PySide' +
                             '<br>1.0.1 : <br>' +
                             '  * Add auto sync at launch<br>' +
                             '  * Push modification of a note to server once saved<br>' +
                             '<br><br><b>Thanks to : </b>' +
                             '<br>Radek Novacek' +
                             '<br>caco3 on talk.maemo.org' +
                             '<br>Thomas Perl for PyOtherSide' +
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

    function onError(message) {

    }

    Python {
        id: sync
        property bool running: false

        function launch() {
            if (!running) {
                running = true;
                threadedCall('ownnotes.launchSync', [])
            }
        }

        onFinished: {
            running = false;
            pyNotes.listNotes(searchField.text);
        }

        onMessage: {
            console.log('Sync:'+data)
        }

        onException: {
            console.log(type + ' : ' + message)
            onError(type + ' : ' + message);
            running = false;
        }

        Component.onCompleted: {
            //addImportPath('/opt/ownNotes/python');
            addImportPath('python');
            importModule('ownnotes');
        }

    }

    Python {
        id: pyNotes
        signal requireRefresh

        function loadNote(path) {
            var message = call('ownnotes.loadNote', [path,]);
            return message;
        }

        function listNotes(text) {
            threadedCall('ownnotes.listNotes', [text,]);
            console.debug('listNotes called')
        }

        function getCategories() {
            var categories = call('ownnotes.getCategories', []);
            return categories;
        }

        function setCategory(path, category) {
            call('ownnotes.setCategory', [path, category]);
            requireRefresh();
        }

        function remove(path) {
            call('ownnotes.rm', [path, ]);
            requireRefresh();
        }

        function duplicate(path) {
            call('ownnotes.duplicate', [path, ]);
            requireRefresh();
        }

        function get(section, option) {
            return call('ownnotes.getSetting', [section, option])
        }

        function set(section, option, value) {
            call('ownnotes.setSetting', [section, option, value])
        }

        function createNote() {
            var path = call('ownnotes.createNote', []);
            return path;
        }

        function publishToScriptogram(text) {
            call('ownnotes.publishToScriptogram', [text]);
        }

        function publishAsPostToKhtCMS(text) {
            call('ownnotes.publishAsPostToKhtCMS', [text]);
        }

        function publishAsPageToKhtCMS(text) {
            call('ownnotes.publishAsPageToKhtCMS', [text]);
        }
        onException: {
            console.log('Type:' + type);
            console.log('Message:' + message);
            onError(type + ' : ' + message);
        }

        Component.onCompleted: {
            addImportPath('python');
            //addImportPath('/opt/ownNotes/python');
            importModule('ownnotes');
        }
    }


    Action {
        id: syncAction
        text: "&Sync"
        shortcut: "Ctrl+S"
        iconName: "view-refresh"
        onTriggered: console.log('sync not yet implemented')
        tooltip: "Sync notes"
    }

    Action {
        id: newAction
        text: "&New"
        iconName: "document-new"
        shortcut: "ctrl+n"
        onTriggered: {
            var path = pyNotes.createNote();
            console.log('NEWPATH:'+path);
            editor.load(path);
        }
    }

    Action {
        id: settingsAction
        text: "&Settings"
        iconName: "gnome-settings"
        onTriggered: console.log('settings not yet implemented')
    }

    toolBar: ToolBar {
        id: toolbar
        RowLayout {
            id: toolbarLayout
            spacing: 0
            width: parent.width
            ToolButton {
                action: newAction
            }

            ToolButton {
                action: syncAction
            }
            ToolButton {
                action: settingsAction
            }

            Item { Layout.fillWidth: true }
            TextField {
                id: searchField
                placeholderText: 'Search'
                Accessible.name: "Search Notes"
                onTextChanged: notesModel.applyFilter(text)
            }
        }
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

    /*ListModel {
        id: dummyModel
        Component.onCompleted: {
            clear();
            for (var i = 1 ; i < 100 ; i++) {
                append({"title": "A title " + i, "category":"Test", "timestamp" :"10 Mai 1982 10h56"});
            }

        }
    }*/

    SplitView {
        id: mainLayout
        anchors.fill: parent

        ListView {
            id: notesView
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width / 3
            model: notesModel

            delegate:
                Rectangle {
                color: "white"
                width: parent.width
                height: 40
                //height: childrenRect.height + 5

                Column {
                    width: parent.width

                    Label {
                        text: title
                        font.pixelSize: 16
                        font.bold: true

                    }
                    Label {
                        text: timestamp
                        font.pixelSize: 12
                        color: "#333"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log('loading notes:'+path)
                    editor.load(path);
                }
                }

            }
            section {
                property: "category"
                criteria: ViewSection.FullString
                delegate: Rectangle {
                    color: "#ccc"
                    width: parent.width
                    height: childrenRect.height
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        text: section
                        font.pixelSize:16
                        font.bold: true
                    }
                }
            }
        }

        TextArea {
            id: editor
            property string path:''
            property bool modified:false

            function load(newpath) {
                if ((path !== '') && modified) {
                    console.log('oups:'+path)
                    editor.save(path);
                }

                editor.path = newpath;
                editor.visible = true;
                editor.text = pyNotes.loadNote(newpath);
                editor.modified = false
            }

            Python {
                id: noteSaver

                function saveNote(filepath, data) {
                    threadedCall('ownnotes.saveNote', [filepath, data]);
                }

                onFinished: {
                    pyNotes.requireRefresh();
                }

                onMessage: {
                    console.log('saveNote result:' + data);
                }

                onException: {
                    console.log(type + ':' + data)
                    onError(type + ' : ' + data);
                }

                Component.onCompleted: {
                    addImportPath('python');
                    importModule('ownnotes');
                }
            }

            function save(path) {
                noteSaver.saveNote(path, editor.text);
            }

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            text: ''
            visible: false           
            textFormat: Text.RichText;
            onTextChanged: {
                modified = true;
            }
        }

    }

    Component.onCompleted: {
        pyNotes.listNotes('');
        console.log('Notes loaded')
    }
}
