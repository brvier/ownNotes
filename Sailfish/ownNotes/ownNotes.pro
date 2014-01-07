# The name of your app.
# NOTICE: name defined in TARGET has a corresponding QML filename.
#         If name defined in TARGET is changed, following needs to be
#         done to match new name:
#         - corresponding QML filename must be changed
#         - desktop icon filename must be changed
#         - desktop filename must be changed
#         - icon definition filename in desktop file must be changed
TARGET = ownNotes

INCLUDEPATH += $$system(python-config --includes)
QMAKE_CXXFLAGS += $$system(python-config --includes)
QMAKE_LIBS += $$system(python-config --libs)

CONFIG += sailfishapp

#qtHaveModule(widgets) {
    QT += widgets
#}

SOURCES += src/ownNotes.cpp \
    src/qpython.cpp \
    src/documenthandler.cpp \
    src/highlighter.cpp

OTHER_FILES += qml/ownNotes.qml \
    qml/cover/CoverPage.qml \
    rpm/ownNotes.spec \
    rpm/ownNotes.yaml \
    ownNotes.desktop \
    qml/pages/SettingsPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/InfoBanner.qml \
    qml/pages/FontComboBox.qml \
    qml/pages/EditPage.qml \
    qml/pages/AboutPage.qml \
    icons/* \
    i18n/*

HEADERS += \
    src/qpython.h \
    src/documenthandler.h \
    src/highlighter.h

python_files.files = ../../python/*
python_files.path = /usr/share/$$TARGET/python
qm_files.files = i18n
qm_files.path = /usr/share/$$TARGET
icons_files.files = icons
icons_files.path = /usr/share/$$TARGET

INSTALLS += python_files qm_files icons_files

lupdate_only {
SOURCES = qml/ownNotes.qml \
          qml/pages/*.qml \
          qml/cover/*.qml
}

RESOURCES +=

TRANSLATIONS = i18n/ownNotes_en.ts \
            i18n/ownNotes_ru.ts \
            i18n/ownNotes_fr.ts

