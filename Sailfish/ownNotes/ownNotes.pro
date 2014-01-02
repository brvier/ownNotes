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

SOURCES += src/ownNotes.cpp \
    src/qpython.cpp

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
    i18n/* \
    icons/*

HEADERS += \
    src/qpython.h

python_files.files = ../../python/*
python_files.path = /usr/share/$$TARGET/python
qm_files.files = i18n/*.qm
qm_files.path = /usr/share/$$TARGET/i18n
INSTALLS += python_files qm_files

lupdate_only {
SOURCES = main.qml \
          pages/*.qml \
          cover/*.qml
}

RESOURCES +=

TRANSLATIONS = i18n/en_US.ts \
            i18n/ru_RU.ts \
            i18n/fr_FR.ts

