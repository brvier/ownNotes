/*

The MIT License (MIT)

Copyright (c) 2013 Benoit HERVIER <khertan@khertan.net>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import net.khertan.python 1.0
import Sailfish.Silica.theme 1.0

DockedPanel {
    id: root

    width: Screen.width
    height: content.height

    dock: Dock.Top

    Rectangle {
        id: content
        x: 0
        y: 0
        width: parent.width

        height: infoLabel.height + 2*Theme.paddingSmall
        color: Theme.highlighColor;
        opacity: 0.65;

        Label {
            id: infoLabel
            text : ''
            color: Theme.primaryColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            width: parent.width - 2*Theme.paddingSmall
            x: Theme.paddingSmall
            y: Theme.paddingSmall
            wrapMode: Text.WrapAnywhere
            }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.hide()
                autoClose.stop()
            }
        }
    }


    function displayError(errorMsg) {
        infoLabel.text = errorMsg
        root.show()
        autoClose.start()
    }

    Timer {
        id: autoClose
        interval: 15000
        running: false
        onTriggered: {
            root.hide()
            stop()
        }

    }
}
