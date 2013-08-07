import QtQuick 1.1
import com.nokia.meego 1.0
import 'components'
import 'common.js' as Common

Page {
    tools: simpleBackTools
    id: settingsPage

    PageHeader {
        id: header
        title: 'ownNotes'
    }

    Flickable {
        id: flick
        interactive: true
        anchors.top: header.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        contentWidth: parent.width
        contentHeight: settingsColumn.height + 30
        clip: true

        Column {
            id: settingsColumn
            spacing: 10
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            
            TitleLabel {
                text: qsTr("Appearance")
            }

            Label {
                text: qsTr("Display Header")
                width: parent.width
                height: displayHeaderSwitch.height
                verticalAlignment: Text.AlignVCenter
                Switch {
                    id: displayHeaderSwitch
                    anchors.right: parent.right
                    checked: pyNotes.get('Display','header')
                    onCheckedChanged: {
                        pyNotes.set('Display','header',displayHeaderSwitch.checked)
                    }
                }
            }

            Label {
                text: qsTr("Font size")
                width: parent.width
                height: fontSlider.height
                verticalAlignment: Text.AlignVCenter
                Slider {
                    id: fontSlider
                    stepSize: 1
                    width: 300
                    valueIndicatorVisible: true
                    anchors.right: fontSliderLabel.left

                    onValueChanged:  {
                        pyNotes.set('Display','fontsize',fontSlider.value);
                    }

                    Component.onCompleted: {
                        fontSlider.value = pyNotes.get('Display','fontsize');
                        fontSlider.minimumValue = 9
                        fontSlider.maximumValue = 40
                    }
                }
                Label {
                    id: fontSliderLabel
                    text: fontSlider.value
                    width: 50
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
                        
            TitleLabel {
                text: qsTr('Webdav')
            }


            Label {
                text: qsTr("Url")
            }

            TextField {
                id: url
                text:pyNotes.get('WebDav','url')
                width: parent.width
                placeholderText: "https://owncloud.khertan.net/remote.php/webdav"
                onTextChanged:  {
                    pyNotes.set('WebDav', 'url', url.text)
                }
            }

            Label {
                text: qsTr("Login")
            }

            TextField {
                id: login
                text: pyNotes.get('WebDav','login')
                width: parent.width
                onTextChanged:  {
                    pyNotes.set('WebDav','login',login.text)
                }

            }

            Label {
                text: qsTr("Password")
            }

            TextField {
                id: password
                echoMode: TextInput.Password
                text:pyNotes.get('WebDav','password')
                width: parent.width
                onTextChanged: {if (password.text !== '') pyNotes.set('WebDav','password',password.text); } // Test if non null due to nasty bug on qml echoMode

            }

            Label {
                text: qsTr("Remote Folder Name")
            }

            TextField {
                id: remoteFolder
                text:pyNotes.get('WebDav','remoteFolder')
                width: parent.width
                onTextChanged:  {
                    pyNotes.set('WebDav', 'remoteFolder', remoteFolder.text)
                }
            }

            Label {
                width: parent.width
                height: mergeSwitch.height
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Use auto merge feature")

                Switch {
                    id: mergeSwitch
                    checked: pyNotes.get('WebDav','merge')
                    anchors.right: parent.right
                    onCheckedChanged:  {
                        pyNotes.set('WebDav','merge',mergeSwitch.checked)
                    }
                }
            }


            TitleLabel {
                text: qsTr("<b>Scriptogr.am</b>")
            }
            
            Label {
                text: qsTr("User ID")
            }

            TextField {
                id: scriptogramUserId
                text:pyNotes.get('Scriptogram','userid')
                width: parent.width
                onTextChanged:  {
                    pyNotes.set('Scriptogram', 'userid', scriptogramUserId.text)
                }
            }

          TitleLabel {
                text: qsTr("<b>KhtCMS</b>")
            }
            
            Label {
                text: qsTr("Url")
            }

            TextField {
                id: khtcmsUrl
                text:pyNotes.get('KhtCms','url')
                width: parent.width
                onTextChanged:  {
                    pyNotes.set('KhtCms','url',khtcmsUrl.text)
                }
            }

           
            Label {
                text: qsTr("Api Key")
            }

            TextField {
                id: khtcmsApiKey
                text:pyNotes.get('KhtCms','apikey')
                width: parent.width
                onTextChanged:  {
                    pyNotes.set('KhtCms','apikey', khtcmsApiKey.text)
                }
            }

        }
    }

    ScrollDecorator {
        flickableItem: flick
        platformStyle: ScrollDecoratorStyle {
        }}

    Menu {
        id: editMenu
        visualParent: pageStack
        MenuLayout {
            MenuItem { text: qsTr("About"); onClicked: pushAbout()}
        }
    }

    ToolBarLayout {
        id: simpleBackTools
        visible: true
        ToolIcon {
            platformIconId: "toolbar-back"
            anchors.left: (parent === undefined) ? undefined : parent.left
            onClicked: {
                pageStack.pop();
            }
        }

        ToolIcon {
            platformIconId: "toolbar-view-menu"
            anchors.right: (parent === undefined) ? undefined : parent.right
            onClicked: (editMenu.status === DialogStatus.Closed) ? editMenu.open() : editMenu.close()
        }
    }
} 
