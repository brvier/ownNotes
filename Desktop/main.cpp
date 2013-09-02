/*#include <QtGui/QGuiApplication>
#include "qtquick2applicationviewer.h"
#include "qpython.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QPython::registerQML();

    QtQuick2ApplicationViewer viewer;
    viewer.setMainQmlFile(QStringLiteral("qml/Desktop/main.qml"));
    viewer.showExpanded();

    return app.exec();
}
*/

#include <QtWidgets/QApplication>
#include <QtQml>
#include <QtQuick/QQuickView>
#include "qpython.h"

//SRC : http://doc-snapshot.qt-project.org/qt5-stable/qtquickcontrols/text-src-main-cpp.html
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    QPython::registerQML();

    //#ifdef QT_NO_DEBUG
    //    QQmlApplicationEngine engine(QUrl("qrc:/qml/Desktop/main.qml"));
    //#else
    QQmlApplicationEngine engine(QUrl("qml/Desktop/main.qml"));
    //#endif

    QObject *topLevel = engine.rootObjects().value(0);
    QQuickWindow *window = qobject_cast<QQuickWindow *>(topLevel);
    if ( !window ) {
        qWarning("Error: Your root item has to be a Window.");
        return -1;
    }
    window->show();
    return app.exec();
}
