import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1
import net.khertan.python 1.0
import 'components'

/* TODO
* Tests
* Detect available qt quick components set
*/

PageStackWindow {
    id: appWindow

    initialPage: mainPage

    Item {
        id: aboutInfos
        property string version:'1.0.0'
        property string text:'A note taking application with sync for ownCloud or any WebDav.' +
                           '<br>Web Site : http://khertan.net/ownnotes' +
                           '<br><br>By Benoît HERVIER (Khertan)' +
                           '<br><b>Licenced under GPLv3</b>' +
                           '<br><br><b>Changelog : </b><br>' +
                           '<br>1.0.0 : <br>' +
                           '  * Initial Fork from KhtNotes<br>' +
                           '  * Use PyOtherSide instead of PySide' +
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


    MainPage {
        id: mainPage
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
            notesModelLoader.listNotes(searchField.text);
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
            addImportPath('/opt/ownNotes/python');            
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

        /*onMessage: {
            notesModel.fill(message)
        }*/

        Component.onCompleted: {
            //addImportPath('python');
            addImportPath('/opt/ownNotes/python');
            importModule('ownnotes');
        }
    }


    function pushAbout() {
        pageStack.push(Qt.createComponent(Qt.resolvedUrl("components/AboutPage.qml")),
                       {
                           title : 'ownNotes ' + aboutInfos.version,
                           iconSource: Qt.resolvedUrl('../../icons/ownnotes.png'),
                           slogan : 'Notes in your own cloud !',
                           text : aboutInfos.text
                       }
                       );
    }

    function onError(errMsg) {
        errorEditBanner.text = errMsg;
        errorEditBanner.show();
    }

    InfoBanner{
        id:errorEditBanner
        text: ''
        topMargin: 40
        timerShowTime: 15000
        timerEnabled:true
        z:4
    }


    Menu {
        id: myMenu
        visualParent: pageStack
        MenuLayout {
            MenuItem { text: qsTr("About"); onClicked: pushAbout()}
            MenuItem { text: qsTr("Preferences"); onClicked: pageStack.push(Qt.createComponent(Qt.resolvedUrl("SettingsPage.qml"))); }
            MenuItem { text: qsTr("Report a bug");onClicked: {
                    Qt.openUrlExternally('https://github.com/khertan/ownNotes/issues/new');
                }
            }
        }
    }

}
