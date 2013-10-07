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
    x: (Screen.width / 2) - 320
    y: (Screen.height / 2) - 240

    Window {
        x: (root.width / 2) - 320
        y: (root.height / 2) - 240
        width: 320
        height: 300
        id: aboutWindow
        ScrollView {
            id: scrollView
            anchors.fill: parent
            contentItem:
                Column {
                width: scrollView.width - 20
                spacing: 10

                Image {
                    id: ownNoteicon
                    source: "../../icons/ownnotes.svg"
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceSize.height: 64
                    sourceSize.width: 64
                    width:64
                    height: 64
                }
                Label {
                    text: '<b>Version '+aboutInfos.version+'</b>'
                    horizontalAlignment: Text.AlignHCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                }
                Label {
                    text: aboutInfos.text
                    wrapMode: Text.WordWrap
                    anchors.left: parent.left
                    anchors.right: parent.right
                }
            }
        }
    }

    Window {
        x: (root.width / 2) - 320
        y: (root.height / 2) - 240
        width: 320
        height: 200
        id: deleteWindow
        //modality: Qt.ApplicationModal
        property string noteTitle: '';
        property string notePath: '';

        function showIt(path, title) {
            deleteWindow.show()
            console.log('ShowIt:'+path)
            deleteWindow.notePath = path
            deleteWindow.noteTitle = title
        }

        function hideIt() {
            deleteWindow.hide()
            deleteWindow.notePath = ''
            deleteWindow.noteTitle = ''
            root.show()
        }

        Label {
            text: "Are you sure you want to delete the note \""
                  + deleteWindow.noteTitle + "\" ?"
            horizontalAlignment: Text.AlignHCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
        }

        RowLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10

            Button {
                text: 'No'
                onClicked: {
                    deleteWindow.hideIt();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: 'Yes'
                onClicked: {
                    editor.path = '';
                    editor.text = '';
                    pyNotes.remove(deleteWindow.notePath);
                    deleteWindow.hideIt();
                }
            }
        }
    }

    SystemPalette {id: syspal}

    SettingsPage {
        id: settingsPage
    }

    Item {
        id: aboutInfos
        property string version:'1.1.0'
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
                             '<br>1.1.0 : <br>' +
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

        function getTitleFromPath(path) {
            var title = call('ownnotes.getTitleFromPath', [path,]);
            return title;
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
            console.log('Remove path:' + path)
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
        onTriggered: sync.launch()
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
        id: aboutAction
        text: "&About"
        iconName: "gnome-help"
        onTriggered: {
            aboutWindow.show()
        }
    }

    Action {
        id: deleteAction
        text: "&Delete Note"
        iconName: "gtk-delete"
        enabled: editor.path != ''
        onTriggered: {
            deleteWindow.showIt(editor.path, editor.title);
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
    /*    Action {
        id: categoryAction
        text: "C&hange Category"
        iconName: "gnome-category"
        enabled: editor.path != ''
        onTriggered: {
            console.log('Not yet implemented')
        }
    }*/
    toolBar: ToolBar {
        id: toolbar

        RowLayout {
            id: toolbarLayout
            spacing: 0
            anchors.right: parent.right
            anchors.left: parent.left

            ToolButton {
                action: newAction
            }

            ToolButton {
                action: syncAction
                checked: sync.running ? true : false
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                action: settingsAction
            }
            ToolButton {
                action: aboutAction
                //anchors.right: parent.right
            }


            /*ToolButton {
                action: duplicateAction
            }

            ToolButton {
                action: deleteAction
            }

            ToolButton {
                action: categoryAction
            }*/

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

    SplitView {
        id: mainLayout
        anchors.fill: parent


        ColumnLayout {
            id: listViewLayout
            spacing: 1

            TextField {
                id: searchField
                placeholderText: 'Search'
                Accessible.name: "Search Notes"
                onTextChanged: notesModel.applyFilter(text)
                Layout.fillWidth: true
            }

            ScrollView {
                id: scrollViewOfNotesList
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notesView
                    model: notesModel
                    width: scrollViewOfNotesList.width

                    delegate:
                        Rectangle {
                        color: "white"
                        width: parent.width
                        height: 40

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
                            height: 25
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
        }

        ColumnLayout {
            spacing: 1

            TextArea {
                id: editor
                property string path:''
                property string category:''
                property string title:''
                property bool modified:false
                Layout.fillWidth: true
                Layout.fillHeight: true
                enabled: path != ''

                onPathChanged: {
                    if (path !== '') {
                        category = pyNotes.getCategoryFromPath(path);
                        title = pyNotes.getTitleFromPath(path);
                    }
                }

                function load(newpath) {
                    if (newpath !== undefined) {
                        if ((path !== '') && modified) {
                            editor.save(path);
                        }

                        editor.path = newpath;
                        editor.enabled = true;
                        editor.text = pyNotes.loadNote(newpath);
                        editor.modified = false;
                        editor.forceActiveFocus();
                        categoryComboxBox.currentIndex = -1;
                        editor.font.family = pyNotes.get('Display', 'fontfamily')
                        editor.font.pixelSize = pyNotes.get('Display', 'fontsize')

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
                textFormat: Text.RichText;
                onTextChanged: {
                    if (focus) {
                        modified = true;
                        autoTimer.restart()
                    }
                }
            }

            RowLayout {

                TextField {
                    id:categoryField
                    text: ''
                    implicitWidth: 150
                    enabled: editor.path != ''

                    onTextChanged: {
                        categoryTimer.path = editor.path
                        categoryTimer.category = text
                        categoryTimer.restart()
                    }

                    Timer {
                        id: categoryTimer
                        property string path: ''
                        property string category: ''
                        repeat: false
                        interval: 700
                        onTriggered: {
                            editor.path = pyNotes.setCategory(editor.path, category);
                            editor.category = category;
                            categoryTimer.stop()
                        }
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
                            categoryField.text = categoryComboxBox.currentText
                            console.log(categoryComboxBox.currentText)
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

        }
    }

    Component.onCompleted: {
        pyNotes.listNotes('');
        console.log('Notes loaded')
    }
}
