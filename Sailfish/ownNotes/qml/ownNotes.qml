import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import net.khertan.python 1.0
import Sailfish.Silica.theme 1.0

ApplicationWindow
{
    id: appWindow
    initialPage: MainPage { }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    InfoBanner {
        id: errorPanel
    }

    Python {
        id: sync
        property bool running: false

        function launch() {
            if (!running) {
                running = true;
                console.debug('Sync launched')
                threadedCall('ownnotes.launchSync', [])
            }
        }

        onFinished: {
            running = false;
            console.debug('Sync finished :' + sync.running)
            pyNotes.requireRefresh();
        }

        onMessage: {
            console.debug('Sync:'+data)
        }

        onException: {
            console.debug(type + ' : ' + data)
            onError('Sync Error' + type + ' : ' + data);
            running = false;
        }

        Component.onCompleted: {
            addImportPath('/usr/share/ownNotes/python');
            importModule('ownnotes');
            if (call('ownnotes.getSetting', ['WebDav', 'startupsync']) == true) {
                launch();
            }
        }

    }

    Python {
        id: pyNotes
        signal requireRefresh()
        signal noteDeleted(string path)

        function readChangeslog() {
            var message = call('ownnotes.readChangeslog', []);
            return message;
        }

        function loadNote(path) {
            var message = call('ownnotes.loadNote', [path, false]);
            return message;
        }

        function setColors(title, subtitle, link) {
            call('ownnotes.setColors', [title, subtitle, link]);
        }

        function listNotes(text) {
            threadedCall('ownnotes.listNotes', [text,]);
            console.log('listNotes called');
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
            noteDeleted(path);
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
            console.log('Message:' + data);
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/usr/share/ownNotes/python');
            importModule('ownnotes');
        }
    }


    function onError(errMsg) {
        errorPanel.displayError(errMsg)
        console.log(errMsg)
    }

}


