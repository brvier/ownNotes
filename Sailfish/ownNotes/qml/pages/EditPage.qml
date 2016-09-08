import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.python 1.0
import net.khertan.documenthandler 1.0

Page {
    id: page
    allowedOrientations: Orientation.All;
    property alias path: textEditor.path;

    Python {
        id: noteSaver

        function saveNote(filepath, data) {

            console.debug('Calling saveNote')
            var new_filepath = call('ownnotes.saveNote', [filepath, data, false]);
            if (filepath !== new_filepath) {
                textEditor.modified = false;
                textEditor.load(new_filepath); }
            else {
                textEditor.modified = false;
                autoTimer.stop()
            }
            pyNotes.requireRefresh();
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

        onException: {
            console.log(type + ':' +data)
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/usr/share/ownNotes/python');
            importModule('ownnotes');
        }
    }

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

        PullDownMenu {
            visible: pyNotes.publishable();
            MenuItem {
                text: qsTr("Publish to Scriptogr.am");
                visible: pyNotes.get('Scriptogram','userid') !== '' ? true : false;
                onClicked: {publishToScriptogram();}
            }
            MenuItem {
                text: qsTr("Publish as Post to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') !== '' ? true : false;
                onClicked: {publishAsPostToKhtCMS();}
            }

            MenuItem {
                text: qsTr("Publish as Page to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') !== '' ? true : false;
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

                Component.onCompleted: {
                    var txt = pyNotes.loadNote(textEditor.path);
                    documentHandler.text = txt;
                    textEditor.modified = false;
                    autoTimer.stop();
                    textEditor.forceActiveFocus();
                }

                onTextChanged: {
                    if (focus) {
                        console.debug("onTextChanged")
                        textEditor.modified = true;
                        autoTimer.restart();
                    }
                }


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
        if (status === PageStatus.Deactivating) {
            console.debug('onStatusChanged : PageStatus.Deactivating');
            if (textEditor.modified===true) {
                noteSaver.saveNote(textEditor.path, textEditor.text);
                pyNotes.requireRefresh();
            }
        }
    }
}



