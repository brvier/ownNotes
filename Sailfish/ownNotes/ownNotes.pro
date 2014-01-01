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
    icons/*

HEADERS += \
    src/qpython.h

python_files.files = ../../python/*
python_files.path = /usr/share/$$TARGET/python
#icon_files.files = icons/*
#icon_files.path = /usr/share/$$TARGET/icons
INSTALLS += python_files #icon_files

lupdate_only {
SOURCES = main.qml \
          pages/*.qml \
          cover/*.qml
}

RESOURCES += \
    resources.qrc

TRANSLATIONS = l10n/en_US.ts \
            l10n/ru_RU.ts

