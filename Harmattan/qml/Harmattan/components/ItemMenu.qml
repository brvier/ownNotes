import QtQuick 1.1
import com.nokia.meego 1.0

Menu {
    id: itemMenu
    visualParent: pageStack

    property string path

    MenuLayout {
        /*MenuItem {
            text: qsTr("Favorite")
            onClicked: {
                notesModelLoader.favorite(index)
            }
        }*/
        MenuItem {
            text: qsTr("Category")
            onClicked: {
                var categories = pyNotes.getCategories();
                categoryQueryDialog.model.clear();
                for (var idx=0; idx<data.length; idx++) {
                    categoryQueryDialog.model.append(categories[idx]);
                }
                categoryQueryDialog.path = path;
                categoryQueryDialog.open();
            }
        }
        MenuItem {
            text: qsTr("Duplicate")
            onClicked: pyNotes.duplicate(path);
        }
        MenuItem {
            text: qsTr("Delete")
            onClicked: {
                deleteQueryDialog.path = path;
                deleteQueryDialog.open();
            }
        }
    }
}
