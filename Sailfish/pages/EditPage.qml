import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.python 1.0

Page {
    id: page
    property alias path: textEditor.path;

    /*function saveFile() {
        if ((textEditor.modified == true)) {
            noteSaver.saveNote(textEditor.path, textEditor.text);
        }
    }*/

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
            addImportPath('/usr/share/ownNotesForSailfish/python');
            importModule('ownnotes');
        }
    }

    Python {
        id: noteHighlighter

        function highligth() {
            threadedCall('ownnotes.reHighlight', [textEditor.text,])
        }

        onException: {
            console.log(type + ':' +data)
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/usr/share/ownNotesForSailfish/python');
            importModule('ownnotes');
        }
    }

    Connections {
        target: noteHighlighter
        onMessage: {
            textEditor.fill(data)
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight:  contentItem.childrenRect.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Publish to Scriptogr.am");
                visible: pyNotes.get('Scriptogram','userid') != '' ? true : false;
                onClicked: {pyNote.publishToScriptogram(textEditor.text);
                }
            }
            MenuItem {
                text: qsTr("Publish as Post to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                onClicked: {pyNotes.publishAsPostToKhtCMS(textEditor.text);
                }
            }
            MenuItem {
                text: qsTr("Publish as Page to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                onClicked: {pyNote.publishAsPageToKhtCMS(textEditor.text);
                }
            }
        }

        Column {
            width: page.width
            spacing: 20
            PageHeader {
                title: "ownNotes"
            }
            TextArea {
                id:textEditor
                property bool modified: false
                property string path
                width: parent.width
                color: Theme.primaryColor
                font.family: pyNotes.get('Display', 'fontfamily')
                font.pointSize: pyNotes.get('Display', 'fontsize')

                function fill(data){
                    var curPos = textEditor.cursorPosition;
                    var selStart = textEditor.selectionStart;
                    var selEnd = textEditor.selectionEnd;
                    var txt = data;
                    textEditor.text = txt;
                    textEditor.cursorPosition = curPos;
                    textEditor.select(selStart,selEnd);
                    autoTimer.stop();
                }

                Component.onCompleted: {
                    pyNotes.setColors(Theme.highlightColor,
                                      Theme.secondaryHighlightColor,
                                      '#65ffdd')
                    var txt = pyNotes.loadNote(textEditor.path);
                    _editor.textFormat = Text.RichText;
                    textEditor.text = txt;
                    textEditor.modified = false;
                    autoTimer.stop();
                }

                onTextChanged: {
                    console.log('onTextChanged emited')
                    textEditor.modified = true;
                    autoTimer.restart();
                }

                /*Component.onDestruction: {
                    console.log('On destruction texteditor called');
                    console.log(textEditor.modified);
                    if (textEditor.modified == true) {
                        console.log('saving notes');
                        console.log(textEditor.path);
                        console.log(textEditor.text);
                        noteSaver.saveNote(textEditor.path, textEditor.text);
                    }
                }*/

                Timer {
                    id: autoTimer
                    interval: 2000
                    repeat: false
                    onTriggered: {
                        if (textEditor.modified) {
                            noteHighlighter.highligth();
                        }
                    }
                }
            }

        }
    }

    onStatusChanged: {
        if (status == PageStatus.Deactivating) {
            console.debug('onStatusChanged');
            noteSaver.saveNote(textEditor.path, textEditor.text);
        }
    }
}




