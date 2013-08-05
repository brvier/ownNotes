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
                var categories = pyNotes.getCategories().split("\n");
                console.log(categories)
                var idx = 0;
                categoryQueryDialog.model.clear();
                for (;idx < categories.length; idx++) {
                    categoryQueryDialog.model.append({"name":categories[idx]});
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
