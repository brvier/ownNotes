import QtQuick 2.1
import QtQuick.Controls 1.0
import QtQuick.Controls.Styles 1.0
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.0
import net.khertan.python 1.0
import QtQuick.Window 2.1
Window {
    id: settingsPage
    title: qsTr("ownNotes Settings")
    width: 640
    height: 280
    visible: false

    Rectangle {
        color: syspal.window
        anchors.fill: parent

        Column {
            anchors {
                left: parent.left
                right: parent.right
                margins: 10
            }

            GroupBox {
                title: 'Appearance'

                RowLayout {
                    anchors.fill: parent
                    ComboBox {
                        id: fontFamilyComboBox
                        implicitWidth: 200
                        model: Qt.fontFamilies()
                        property bool ready : false
                        onCurrentTextChanged: {
                            if ((ready == true) && (currentIndex != 0)) {
                                pyNotes.set('Display', 'fontfamily', currentText);
                            }
                        }
                        Component.onCompleted: {
                            console.debug(pyNotes.get('Display', 'fontfamily'))
                            var fontfam = pyNotes.get('Display', 'fontfamily')
                            var idx = model.indexOf(fontfam)

                            if (idx != -1) {
                                fontFamilyComboBox.currentIndex = idx
                            }

                            console.log('Qt.fontFamilies:' + Qt.fontFamilies())
                            console.log('currentIndex : ' + idx)
                            fontFamilyComboBox.ready = true
                        }
                    }
                    SpinBox {
                        id: fontSizeSpinBox
                        implicitWidth: 50
                        onValueChanged: {
                            console.log('FontSize Set')
                            pyNotes.set('Display', 'fontsize', value);
                        }
                        Component.onCompleted: {
                            console.debug(pyNotes.get('Display', 'fontsize'))
                            value = pyNotes.get('Display', 'fontsize')

                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            GroupBox {
                title: 'ownCloud/WebDav Sync'

                ColumnLayout {

                    RowLayout {
                        width: parent.width

                        TextField {
                            implicitWidth: 300

                            placeholderText: "Url"
                            onTextChanged: {
                                console.log('Set webdav url')
                                pyNotes.set('WebDav', 'url', text)
                            }
                            Component.onCompleted: {
                                text = pyNotes.get('WebDav', 'url')
                            }
                        }


                        TextField {
                            implicitWidth: 150

                            placeholderText: "Remote Folder Name"
                            onTextChanged: {
                                pyNotes.set('WebDav', 'remoteFolder', text)
                            }
                            Component.onCompleted: {
                                text = pyNotes.get('WebDav', 'remoteFolder')
                            }
                        }

                        CheckBox {
                            width: 100

                            text: "Use auto merge"
                            //description: "When note are edited in several places, ownNotes will try to merge the changes if possible"
                            onCheckedChanged:  {
                                pyNotes.set('WebDav','merge',checked)
                            }
                            Component.onCompleted: {
                                checked = pyNotes.get('WebDav','merge')
                            }
                        }

                    }

                    RowLayout {
                        width: parent.width

                        TextField {
                            implicitWidth: 300
                            placeholderText: "Login"
                            onTextChanged: {
                                pyNotes.set('WebDav', 'login', text)
                            }
                            Component.onCompleted: {
                                text = pyNotes.get('WebDav', 'login')

                            }
                        }

                        TextField {
                            implicitWidth: 300
                            //label: "Password"
                            placeholderText: "Password"
                            echoMode: TextInput.Password
                            onTextChanged: {
                                pyNotes.set('WebDav', 'password', text)
                            }
                            Component.onCompleted: {
                                text = pyNotes.get('WebDav', 'password')
                            }
                        }

                    }
                }
            }

            GroupBox {
                title: 'Scriptogr.am'
                width: parent.width

                TextField {
                    width: parent.width
                    placeholderText: "User ID"
                    onTextChanged: {
                        pyNotes.set('Scriptogram', 'userid', text)
                    }
                    Component.onCompleted: {
                        text = pyNotes.get('Scriptogram','userid')
                    }
                }
            }

            GroupBox {
                title: 'KhtCms'
                width: parent.width

                RowLayout {
                    width: parent.width

                    TextField {
                        implicitWidth: 300

                        placeholderText: "Url"
                        onTextChanged: {
                            pyNotes.set('KhtCms', 'url', text)
                        }
                        Component.onCompleted: {
                            text = pyNotes.get('KhtCms','url')
                        }
                    }

                    TextField {
                        implicitWidth: 300
                        placeholderText:"Api Key"

                        onTextChanged: {
                            pyNotes.set('KhtCms', 'apikey', text)
                        }
                        Component.onCompleted: {
                            text = pyNotes.get('KhtCms','apikey')
                        }
                    }
                }
            }
        }
    }
}
