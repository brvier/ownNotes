# The name of your app
TARGET = ownNotesForSailfish

#INCLUDEPATH += -I/usr/include/python2.7
#QMAKE_CXXFLAGS += -I/usr/include/python2.7
QMAKE_CXXFLAGS += $$system(python-config --includes)
#LIBS += -Lpython2.7 #$$system(python-config --libs)
QMAKE_LIBS += $$system(python-config --libs)
#QMAKE_CXXFLAGS += $$system(python-config --includes)

# C++ sources
SOURCES += main.cpp \
    qpython.cpp

# C++ headers
HEADERS += \
    qpython.h

# QML files and folders
qml.files = *.qml pages cover main.qml

# QML files and folders
#python.files = *.py python

# The .desktop file
desktop.files = *.desktop

# Please do not modify the following line.
include(sailfishapplication/sailfishapplication.pri)

OTHER_FILES = \
    rpm/ownNotesForSailfish.yaml \
    rpm/ownNotesForSailfish.spec \
    pages/MainPage.qml \
    pages/EditPage.qml \
    pages/AboutPage.qml \
    pages/SettingsPage.qml \
    python/* \
    icons/ownnotes.png \
    icons/ownnotes.svg

INSTALLS += python_files icon_files
python_files.files = python/*
python_files.path = /usr/share/ownNotesForSailfish/python
icon_files.files = icons/*
icon_files.path = /usr/share/ownNotesForSailfish/icons
