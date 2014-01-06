import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.python 1.0
import net.khertan.documenthandler 1.0

Page {
    id: page
    property alias path: textEditor.path;

    Python {
        id: noteSaver

        function saveNote(filepath, data) {

            console.debug('Calling saveNote')
            var new_filepath = call('ownnotes.saveNote', [filepath, data, false]);
            if (filepath != new_filepath) {
                textEditor.modified = false;
                textEditor.load(new_filepath); }
            else {
                textEditor.modified = false;
                autoTimer.stop()
            }
            //pyNotes.requireRefresh();
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
            addImportPath('/usr/share/ownNotes/python');
            importModule('ownnotes');
        }
    }

    Python {
        id: noteHighlighter

        /*function highligth() {
            textEditor.fill(call('ownnotes.reHighlight', [textEditor.text,]))
            //autoTimer.stop();
        }*/

        onException: {
            console.log(type + ':' +data)
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/usr/share/ownNotes/python');
            importModule('ownnotes');
        }
    }

    /*Connections {
        target: noteHighlighter
        onMessage: {
            textEditor.fill(data)
        }
    }*/

    function publishToScriptogram() {
        remorsePublish.execute(qsTr("Publish to Scriptogr.am"),
                               function() { pyNotes.publishToScriptogram(documentHandler.text) } )
    }
    function publishAsPostToKhtCMS() {
        remorsePublish.execute(qsTr("Publish as Post to KhtCms"),
                               function() { pyNotes.publishAsPostToKhtCMS(documentHandler.text) } )
    }
    function publishAsPageToKhtCMS() {
        remorsePublish.execute(qsTr("Publish as Page to KhtCms"),
                               function() { pyNotes.publishAsPageToKhtCMS(documentHandler.text) } )
    }

    RemorsePopup {
        id: remorsePublish
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight:  contentColumn.height
        contentWidth: flick.width

        /*PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked:
                    pageStack.push(Qt.createComponent(Qt.resolvedUrl("AboutPage.qml")),
                                   {
                                       title : 'ownNotes ' + aboutInfos.version,
                                       icon: Qt.resolvedUrl('/usr/share/ownNotes/icons/ownnotes.png'),
                                       slogan : qsTr('Notes in your own cloud !'),
                                       contentText : aboutInfos.contentText
                                   })

            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }

        }*/

        PullDownMenu {
            MenuItem {
                text: qsTr("Publish to Scriptogr.am");
                visible: pyNotes.get('Scriptogram','userid') != '' ? true : false;
                onClicked: {publishToScriptogram();}
            }
            MenuItem {
                text: qsTr("Publish as Post to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                onClicked: {publishAsPostToKhtCMS();}
            }

            MenuItem {
                text: qsTr("Publish as Page to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                onClicked: {publishAsPageToKhtCMS();}
            }

        }

        Column {
            id: contentColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 5

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
                font.pixelSize: pyNotes.get('Display', 'fontsize')
                text: documentHandler.text
                //textFormat: Text.PlainText
                /*function fill(data){
                    var curPos = textEditor.cursorPosition;
                    var rectPos = textEditor.positionToRectangle(curPos)
                    var selStart = textEditor.selectionStart;
                    var selEnd = textEditor.selectionEnd;
                    var txt = data;
                    textEditor.text = document.text;
                    curPos = textEditor.positionAt(rectPos.x, rectPos.y)
                    textEditor.cursorPosition = curPos
                    textEditor.select(selStart,selEnd);
                    //autoTimer.stop();
                }*/

                Component.onCompleted: {
                    /*pyNotes.setColors(Theme.highlightColor,
                                      Theme.secondaryHighlightColor,
                                      '#65ffdd')*/
                    var txt = pyNotes.loadNote(textEditor.path);
                    //_editor.textFormat = Text.RichText;
                    documentHandler.text = txt;
                    textEditor.modified = false;
                    autoTimer.stop();
                    textEditor.forceActiveFocus();
                }

                onTextChanged: {
                    if (focus) {
                        textEditor.modified = true;
                        autoTimer.restart();
                    }
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
                    interval: 5000
                    repeat: false
                    onTriggered: {
                        if (textEditor.modified) {
                            noteSaver.saveNote(textEditor.path, textEditor.text);
                        }
                    }
                }

                DocumentHandler {
                    id: documentHandler
                    target: textEditor._editor

                    cursorPosition: textEditor.cursorPosition
                    selectionStart: textEditor.selectionStart
                    selectionEnd: textEditor.selectionEnd
                    Component.onCompleted: {
                        documentHandler.setStyle(Theme.primaryColor, Theme.secondaryColor,
                                                  Theme.highlightColor, Theme.secondaryHighlightColor,
                                                  textEditor.font.pixelSize);

                        var txt = pyNotes.loadNote(textEditor.path);
                        documentHandler.text = txt;
                        textEditor.modified = false;
                        autoTimer.stop();
                        textEditor.forceActiveFocus();

                    }
                    onTextChanged: {
                        textEditor.update()
                    }

                }
            }

        }
    }

    onStatusChanged: {
        if (status == PageStatus.Deactivating) {
            console.debug('onStatusChanged : PageStatus.Deactivating');
            noteSaver.saveNote(textEditor.path, textEditor.text);
            pyNotes.requireRefresh();
        }
    }
}



