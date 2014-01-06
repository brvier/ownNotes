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

    Item {
        id: aboutInfos
        property string version:'1.5.0'
        property string contentText:'A note taking application with sync for ownCloud or any WebDav.' +
                                    '<br>Web Site : http://khertan.net/ownnotes' +
                                    '<br><br>By Benoît HERVIER (Khertan)' +
                                    '<br><b>Licensed under GPLv3</b>' +
                                    '<br><br><b>Changelog : </b><br>' +
                                    '<br>1.0.0 : <br>' +
                                    '  * Initial Fork from KhtNotes<br>' +
                                    '  * Use PyOtherSide instead of PySide<br>' +
                                    '<br>1.0.1 : <br>' +
                                    '  * Add auto sync at launch<br>' +
                                    '  * Push modification of a note to server once saved<br>' +
                                    '<br>1.0.2 : <br>' +
                                    '  * Fix rehighlighting that can lose cursor position<br>' +
                                    '<br>1.1.0 : <br>' +
                                    '  * First Desktop UX release<br>' +
                                    '  * Fix an other rehighlight bug<br>' +
                                    '<br>1.1.1 : <br>' +
                                    '  * Should fix the crash at startup on Jolla Device (Send me a device to be sure and i could test :p )<br>' +
                                    '<br>1.1.2 : <br>' +
                                    '  * Fix incorrect font size of the editor on SailfishOS.<br>' +
                                    '<br>1.2.0 : <br>' +
                                    '  * Fix rehighlighting bug generating utf8 decode error<br>' +
                                    '  * Russian and French translation of Sailfish UI<br>' +
                                    '  * Fix sync encoding error<br>' +
                                    '<br>1.2.1 : <br>' +
                                    '  * Fix packaging<br>' +
                                    '<br>1.2.2 : <br>' +
                                    '  * Fix encoding error in notes list view<br>' +
                                    '<br>1.2.3 : <br>' +
                                    '  * Bump release version (as previous release didn\'t display right version)<br>' +
                                    '<br>1.2.4 : <br>' +
                                    '  * Add translation (Sailfish)<br>' +
                                    '  * Fix about (Sailfish)<br>' +
                                    '  * Add a workarround for link color in About (Sailfish)<br>' +
                                    '<br>1.2.5 : <br>' +
                                    '  * Add french translation (Sailfish)<br>' +
                                    '<br>1.2.6 : <br>' +
                                    '  * Fix refreshing bug after creating a new note (Sailfish)<br>' +
                                    '  * Add sync and new feature to cover, and sync indicator (Sailfish)<br>' +
                                    '  * Fix a bug in unlock at end of a sync<br>' +
                                    '  * Fix a bug in delete between list refresh and remorse item (Sailfish)<br>' +
                                    '  * Fix loading of translations (still partial) (Sailfish)<br>' +
                                    '<br>1.2.7 : <br>' +
                                    '  * Replace busycircle on Cover for a label (Sailfish)<br>' +
                                    '  * Add remorse to publish menu (Sailfish)<br>' +
                                    '  * Use pull down busy instead of ugly progress bar (Sailfish)<br>' +
                                    '<br>1.5.0 : <br>' +
                                    '  * Use a real markdown parser with QSyntaxHighligher (Sailfish)<br>' +
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


