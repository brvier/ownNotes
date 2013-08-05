import QtQuick 1.1
import com.nokia.meego 1.0

Rectangle {
   property alias text: root.text
   height: 70
   color: '#eee'

   TextField {
        id: root
        anchors.margins: 10
        anchors.fill: parent
        platformStyle: TextFieldStyle {
            backgroundSelected: "image://theme/color6-meegotouch-textedit-background-selected"
        }
        placeholderText: "Search"
        inputMethodHints: Qt.ImhNoPredictiveText 
			  | Qt.ImhPreferLowercase 
			  | Qt.ImhNoAutoUppercase

    Image {
        anchors { top: parent.top; right: parent.right; margins: 5 }
        smooth: true
        fillMode: Image.PreserveAspectFit
        source: root.text ? "image://theme/icon-m-input-clear" 
			  : "image://theme/icon-m-common-search"
        height: parent.height - platformStyle.paddingMedium * 2
        width: parent.height - platformStyle.paddingMedium * 2

        MouseArea {
            anchors.fill: parent
            anchors.margins: -10 // Make area bigger then image
            enabled: root.text
            onClicked: root.text = ""
        }
    }
}
}
