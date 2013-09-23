import QtQuick 1.1
import com.nokia.meego 1.0
import 'components'
import 'common.js' as Common
import net.khertan.python 1.0

Page {
    tools: editTools
    id: editPage

    property bool modified;
    property string path;

    function exitFile() {
        modified = false;
        pageStack.pop();
        notesModel.applyFilter(searchField.text);
    }

    function saveFile() {
        if ((modified == true)) {
            noteSaver.saveNote(path, textEditor.text);
            }
    }

    Python {
        id: noteSaver

        /*function saveNote(filepath, data) {
            threadedCall('ownnotes.saveNote', [filepath, data]);
        }*/
        function saveNote(filepath, data) {

            var new_filepath = call('ownnotes.saveNote', [filepath, data]);
            if (filepath != new_filepath) {
                textEditor.modified = false;
                textEditor.load(new_filepath); }
            else {
                textEditor.modified = false;
                autoTimer.stop()
            }
            pyNotes.requireRefresh();
        }

        onException: {
            console.log(type + ':' +data)
            onError(type + ' : ' + data);
        }

        Component.onCompleted: {
            addImportPath('/opt/ownNotes/python');
            importModule('ownnotes');
        }
    }

    Python {
        id: noteHighlighter

        function highligth() {

            var curPos = textEditor.cursorPosition;
            var rectPos = textEditor.positionToRectangle(curPos);

            var selStart = textEditor.selectionStart;
            var selEnd = textEditor.selectionEnd;

            textEditor.text = call('ownnotes.reHighlight', [textEditor.text,])

            curPos = textEditor.positionAt(rectPos.x, rectPos.y)
            textEditor.cursorPosition = curPos

            textEditor.select(selStart,selEnd);
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

    PageHeader {
        id: header
        title: 'ownNotes'
    }

    BusyIndicator {
        id: busyindicator
        platformStyle: BusyIndicatorStyle { size: "large" }
        running: true;
        opacity: 1.0;
        anchors.centerIn: parent
    }

    Flickable {
        id: flick
        opacity: 0.0
        flickableDirection: Flickable.VerticalFlick
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.leftMargin: -2
        anchors.right: parent.right
        anchors.rightMargin: -2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        anchors.topMargin: -2
        clip: true
        contentWidth: flick.width
        contentHeight: textEditor.height
        pressDelay: 200

        function ensureVisible(r)
        {
            /*if (contentX >= r.x)
                contentX = r.x;
            else if (contentX+width <= r.x+r.width)
                contentX = r.x+r.width-width;*/
            if (contentY >= r.y)
                contentY = r.y;
            else if (contentY+height <= r.y+r.height)
                contentY = r.y+r.height-height;
        }
        onContentYChanged: {
            if ((flick.contentY == 0) && (textEditor.cursorPosition != 0)) {
                flick.ensureVisible(
                            textEditor.positionToRectangle(textEditor.cursorPosition));
            }
        }

        TextArea {
            id: textEditor
            anchors.top: parent.top
            height: Math.max (implicitHeight, flick.height + 4, editPage.height, 720)
            width:  flick.width + 4
            wrapMode: TextEdit.WrapAnywhere
            inputMethodHints: Qt.ImhAutoUppercase | Qt.ImhNoPredictiveText
            textFormat: TextEdit.RichText
            font { bold: false;
                family: pyNotes.get('Display', 'fontfamily');
                pixelSize:  pyNotes.get('Display', 'fontsize');}

            onTextChanged: {
                if(focus){
                    modified = true;
                    autoTimer.restart();
                }
            }

            Component.onDestruction: {
                console.log('On destruction texteditor called');
                if (modified == true) {
                    noteSaver.saveNote(path, textEditor.text)
                }
            }

            Component.onCompleted: {
                var txt = pyNotes.loadNote(path);
                textEditor.text = txt;
                flick.opacity = 1.0;
                busyindicator.opacity = 0.0;
                busyindicator.visible = false;
                modified = false;
                autoTimer.stop();
            }

            Timer {
                id: autoTimer
                interval: 2000
                repeat: false
                onTriggered: {
                    if (modified) {
                        noteHighlighter.highligth();
                    }
                }
            }
        }
    }

    ScrollDecorator {
        flickableItem: flick
        platformStyle: ScrollDecoratorStyle {}
    }

    Menu {
        id: editMenu
        visualParent: pageStack
        MenuLayout {
            MenuItem { text: qsTr("About"); onClicked: pushAbout()}
/*            MenuItem { text: qsTr("MarkDown Preview");
                                    onClicked: pageStack.push(Qt.createComponent(Qt.resolvedUrl("Harmattan_PreviewPage.qml")), {html:Note.previewMarkdown(textEditor.text)}); }
            MenuItem { text: qsTr("ReStructuredText Preview"); onClicked: pageStack.push(Qt.createComponent(Qt.resolvedUrl("Harmattan_PreviewPage.qml")), {html:Note.previewReStructuredText(textEditor.text)}); }*/
            MenuItem { text: qsTr("Publish to Scriptogr.am");
                visible: pyNotes.get('Scriptogram','userid') != '' ? true : false;
                       onClicked: {pyNote.publishToScriptogram(textEditor.text);}}
            MenuItem { text: qsTr("Publish as Post to KhtCms");
                       visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                       onClicked: {pyNotes.publishAsPostToKhtCMS(textEditor.text);}}
            MenuItem { text: qsTr("Publish as Page to KhtCms");
                visible: pyNotes.get('KhtCms','apikey') != '' ? true : false;
                       onClicked: {pyNote.publishAsPageToKhtCMS(textEditor.text);}}
            /*MenuItem { text: qsTr("Share");
                       onClicked: {saveFile(); Note.exportWithShareUI();}}*/

        }
    }

    ToolBarLayout {
        id: editTools
        visible: true
        ToolIcon {
            platformIconId: "toolbar-back"
            anchors.left: (parent === undefined) ? undefined : parent.left
            onClicked: {
                saveFile();
                exitFile();
            }
        }

        ToolIcon {
            platformIconId: "toolbar-view-menu"
            anchors.right: (parent === undefined) ? undefined : parent.right
            onClicked: (editMenu.status === DialogStatus.Closed) ? editMenu.open() : editMenu.close()
        }
    }
}   
