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
    id: root

    SystemPalette {id: syspal}

    SettingsPage {
        id: settingsPage
    }

    Item {
        id: aboutInfos
        property string version:'1.0.3'
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
                             '<br>1.0.2 : <br>' +
                             '  * Fix rehighlight<br>' +
                             '<br>1.0.3 : <br>' +
                             '  * First Desktop UX release<br>' +
                             '  * Fix an other rehighlight bug<br>' +
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

        function getCategoryFromPath(path) {
            var cat = call('ownnotes.getCategoryFromPath', [path,]);
            return cat;
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
            var path = call('ownnotes.setCategory', [path, category]);
            requireRefresh();
            return path;
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

    Python {
        id: noteHighlighter

        function highligth() {

            var curPos = editor.cursorPosition;
            var rectPos = editor.positionToRectangle(curPos);

            var selStart = editor.selectionStart;
            var selEnd = editor.selectionEnd;

            editor.text = call('ownnotes.reHighlight', [editor.text,]);
            editor.modified = false;

            curPos = editor.positionAt(rectPos.x, rectPos.y);
            editor.cursorPosition = curPos;

            editor.select(selStart,selEnd);
            autoTimer.stop();

        }

        /*function threadedHighligth() {
            console.log(textEditor.text)
            threadedCall('ownnotes.reHighlight', [textEditor.text,])
        }

        onMessage: {
            var curPos = textEditor.cursorPosition;
            var rectPos = textEditor.positionToRectangle(curPos);

            var selStart = textEditor.selectionStart;
            var selEnd = textEditor.selectionEnd;

            textEditor.text = data;

            curPos = textEditor.positionAt(rectPos.x, rectPos.y)
            textEditor.cursorPosition = curPos

            textEditor.select(selStart,selEnd);
            autoTimer.stop();
        }*/

        onException: {
            console.log(type + ':' +data)
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/opt/ownNotes/python');
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
            pyNotes.requireRefresh();
        }
    }

    Action {
        id: settingsAction
        text: "&Settings"
        iconName: "gnome-settings"
        onTriggered: {
            settingsPage.visible = true;
        }
    }

    Action {
        id: deleteAction
        text: "&Delete Note"
        iconName: "gtk-delete"
        enabled: editor.path != ''
        onTriggered: {

            //settingsPage.visible = true;
        }
    }
    Action {
        id: duplicateAction
        text: "Duplica&te Note"
        iconName: "gtk-save-as"
        enabled: editor.path != ''
        onTriggered: {
            pyNotes.duplicate(editor.path)
        }
    }
    Action {
        id: categoryAction
        text: "C&hange Category"
        iconName: "gnome-category"
        enabled: editor.path != ''
        onTriggered: {
            console.log('Not yet implemented')
        }
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

            ToolBarSeparator { }

            /*ToolButton {
                action: duplicateAction
            }

            ToolButton {
                action: deleteAction
            }

            ToolButton {
                action: categoryAction
            }*/

            Item { Layout.fillWidth: true }


            TextField {
                id: searchField
                implicitWidth: 150
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

        ScrollView {
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
                            categoryComboxBox.model.fill(pyNotes.getCategories());
                            categoryField.text = editor.category
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
        }

        ColumnLayout {
            spacing: 0

            RowLayout {
                height: 60

                TextField {
                    id:categoryField
                    text: ''
                    implicitWidth: 150
                    enabled: editor.path != ''

                    onTextChanged: {
                        console.log(editor.path)
                        console.log(text)
                        editor.path = pyNotes.setCategory(editor.path, text)
                        editor.category = text
                    }

                    ComboBox {
                        id: categoryComboxBox
                        textRole: 'name'
                        anchors.right: parent.right
                        width: 25
                        enabled: editor.path != ''

                        property bool ready : false
                        style: ComboBoxStyle {
                            label: Label {
                                visible: false
                            }
                        }

                        model: ListModel {
                            id: catModel

                            function fill(data) {
                                catModel.clear()
                                for (var i=0; i<data.length; i++) {
                                    catModel.append(data[i]);
                                }
                            }

                        }

                        onCurrentTextChanged: {
                            if (ready == true) {
                                categoryField.text = categoryComboxBox.currentText
                            }
                        }
                    }

                }



                ToolButton {
                    action: duplicateAction
                }

                Item { Layout.fillWidth: true }

                ToolButton {
                    action: deleteAction
                }

            }

            TextArea {
                id: editor
                property string path:''
                property string category:''
                property bool modified:false
                Layout.fillWidth: true
                Layout.fillHeight: true

                onPathChanged: {
                    if (path !== '')
                        category = pyNotes.getCategoryFromPath(path)
                }

                function load(newpath) {
                    if (newpath !== undefined) {
                        if ((path !== '') && modified) {
                            editor.save(path);
                        }

                        editor.path = newpath;
                        editor.visible = true;
                        editor.text = pyNotes.loadNote(newpath);
                        editor.modified = false
                    }
                }

                Python {
                    id: noteSaver

                    function saveNote(filepath, data) {
                        var new_filepath = call('ownnotes.saveNote', [filepath, data]);
                        if (filepath != new_filepath) {
                            editor.modified = false;
                            editor.load(new_filepath); }
                        else {
                            editor.modified = false;
                            autoTimer.stop()
                        }
                        pyNotes.requireRefresh();
                    }

                    onFinished: {
                        console.log('saveNote on finished')
                        pyNotes.requireRefresh();
                    }

                    onMessage: {
                        if (data != editor.path)
                            editor.path = data;
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

                Timer {
                    id: autoTimer
                    interval: 2000
                    repeat: false
                    onTriggered: {
                        if (editor.modified) {
                            noteHighlighter.highligth();
                            noteSaver.saveNote(editor.path, editor.text)
                        }
                    }
                }

                text: ''
                visible: false
                textFormat: Text.RichText;
                onTextChanged: {
                    if (focus) {
                        modified = true;
                        autoTimer.restart()
                    }
                }
            }


        }
    }

    Component.onCompleted: {
        pyNotes.listNotes('');
        console.log('Notes loaded')
    }
}
