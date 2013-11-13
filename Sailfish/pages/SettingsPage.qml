import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Silica.theme 1.0
import net.khertan.python 1.0

Page {
    id: page

    SilicaFlickable {
        id: flicker
        anchors.fill: parent
        contentHeight: contentItem.childrenRect.height
        contentWidth: flicker.width

        Column {
            anchors {
                left: parent.left
                right: parent.right
                margins: 10
            }

            PageHeader {
                title: qsTr("ownNotes Settings")
            }

            SectionHeader {
                text: qsTr('Appearance')
            }



            FontComboBox {
                id: fontChooser
                label: qsTr('Font:')

                model: ListModel {
                    id: fontList

                    function fontIndex(f) {
                        for (var i = 0; i < fontList.count; ++i) {
                            if (fontList.get(i).family === f) {
                                return i
                            }
                        }
                        return -1
                    }
                    Component.onCompleted: {
                        var ff = Theme._fontFamilies()
                        var s = pyNotes.get('Display', 'fontfamily');
                        for (var i = 0; i < ff.length; ++i) {

                            fontList.append({ 'family': ff[i] })
                            if (ff[i] === s) {
                                fontChooser.currentIndex = i;
                            }
                        }
                    }
                }
                onCurrentIndexChanged: {
                    console.log('Set');
                    console.log(currentIndex);
                    var ff = Theme._fontFamilies()
                    console.log(ff[currentIndex]);
                    console.log(currentItem);
                    if (currentItem) {
                        console.log(currentItem.text);
                        pyNotes.set('Display', 'fontfamily', ff[currentIndex]);
                    }

                }
            }

            Slider {
                id: fontSize
                label: qsTr('Size')
                minimumValue: 7
                maximumValue: 48
                stepSize: 1
                width: parent.width
                Component.onCompleted: {
                    console.log(pyNotes.get('Display', 'fontsize'));
                    valueText = pyNotes.get('Display', 'fontsize');
                    value = parseInt(pyNotes.get('Display', 'fontsize'));
                }
                onValueChanged: {
                    pyNotes.set('Display', 'fontsize', value);
                    valueText = ''+value;
                }

            }

            SectionHeader {
                text: qsTr('ownCloud/WebDav Sync')
            }

            TextField {
                width: parent.width
                label: qsTr("Url")
                text: pyNotes.get('WebDav', 'url')
                placeholderText: qsTr("Url")
                onTextChanged: {
                    pyNotes.set('WebDav', 'url', text)
                }
            }

            TextField {
                width: parent.width
                label: qsTr("Login")
                text: pyNotes.get('WebDav', 'login')
                placeholderText: qsTr("Login")
                onTextChanged: {
                    pyNotes.set('WebDav', 'login', text)
                }
            }

            TextField {
                width: parent.width
                label: qsTr("Password")
                text: pyNotes.get('WebDav', 'password')
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                onTextChanged: {
                    pyNotes.set('WebDav', 'password', text)
                }
            }

            TextField {
                width: parent.width
                label: qsTr("Remote Folder Name")
                text: pyNotes.get('WebDav', 'remoteFolder')
                placeholderText: qsTr("Remote Folder Name")
                onTextChanged: {
                    pyNotes.set('WebDav', 'remoteFolder', text)
                }
            }

            TextSwitch {
                text: qsTr("Use auto merge")
                description: qsTr("When note are edited in several places, ownNotes will try to merge the changes if possible")
                checked: pyNotes.get('WebDav','merge')
                onCheckedChanged:  {
                    pyNotes.set('WebDav','merge',checked)
                }
            }


            SectionHeader {
                text: 'Scriptogr.am'
            }

            TextField {
                width: parent.width
                label: qsTr("User ID")
                text: pyNotes.get('Scriptogram','userid')
                placeholderText: qsTr("User ID")
                onTextChanged: {
                    pyNotes.set('Scriptogram', 'userid', text)
                }
            }

            SectionHeader {
                text: 'KhtCms'
            }

            TextField {
                width: parent.width
                label: qsTr("Url")
                text: pyNotes.get('KhtCms','url')
                placeholderText: qsTr("Url")
                onTextChanged: {
                    pyNotes.set('KhtCms', 'url', text)
                }
            }

            TextField {
                width: parent.width
                label: qsTR("Api Key")
                text: pyNotes.get('KhtCms','apikey')
                placeholderText: qsTr("Api Key")
                onTextChanged: {
                    pyNotes.set('KhtCms', 'apikey', text)
                }
            }
        }

    }
}





