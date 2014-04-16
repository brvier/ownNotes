import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import net.khertan.python 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.fileio 1.0

ApplicationWindow
{
    id: appWindow
    initialPage: MainPage { }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")

    InfoBanner {
        id: errorPanel
    }

    FileIO {
        property string text:'';
        id: changelog
        source: "/usr/share/ownNotes/datas/changelog.html"
        onError: console.log(msg)
    }

    Item {
        id: aboutInfos
        property string version:VERSION
        property string contentText:qsTr('A note taking application with sync for ownCloud or any WebDav.') +
                                    '<br>' + qsTr('Web Site : http://khertan.net/ownnotes') +
                                    '<br><br>' + qsTr('By') +' Benoît HERVIER (Khertan)' +
                                    '<br><b>' + qsTr('Licensed under GPLv3') + '</b>'+
                                    '<br><br><b>Changeslog : </b><br>' +
                                    + changelog.read() +
                                    '<br><br><b>Thanks to : </b>' +
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
            launch();
        }

    }


    Python {
        id: pyNotes
        signal requireRefresh()
        signal noteDeleted(string path)

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


