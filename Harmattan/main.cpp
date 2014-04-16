#include <QtGui/QApplication>
#include "qmlapplicationviewer.h"
#include "qpython.h"

Q_DECL_EXPORT int main(int argc, char *argv[])
{
    QScopedPointer<QApplication> app(createApplication(argc, argv));

    QPython::registerQML();

    QmlApplicationViewer viewer;
    viewer.setOrientation(QmlApplicationViewer::ScreenOrientationAuto);
    viewer.setMainQmlFile(QLatin1String("qml/Harmattan/main.qml"));
    viewer.showExpanded();

    return app->exec();
}
