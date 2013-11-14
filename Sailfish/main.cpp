#include <qpython.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QTranslator>
#include "sailfishapplication.h"

Q_DECL_EXPORT int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(Sailfish::createApplication(argc, argv));

    QPython::registerQML();

    QTranslator *appTranslator = new QTranslator;
    appTranslator->load(":/l10n/" + QLocale::system().name() + ".qm");
    app->installTranslator(appTranslator);

    QScopedPointer<QQuickView> view(Sailfish::createView("main.qml"));


    Sailfish::showView(view.data());
    
    return app->exec();
}


