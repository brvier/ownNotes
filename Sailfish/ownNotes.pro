# The name of your app
TARGET = ownNotes

INCLUDEPATH += $$system(python-config --includes)
QMAKE_CXXFLAGS += $$system(python-config --includes)
#LIBS += -Lpython2.7 #$$system(python-config --libs)

#QMAKE_CXXFLAGS += $$system(python-config --includes)

CONFIG(debug, debug|release) {
    QMAKE_LIBS += $$system(python-config --ldflags)
}

CONFIG(release, debug|release) {
    QMAKE_LIBS += $$system(python-config --libs)
}

# C++ sources
SOURCES += main.cpp \
    qpython.cpp

# C++ headers
HEADERS += \
    qpython.h

# QML files and folders
qml.files = *.qml pages cover main.qml

# QML files and folders
python.files = *.py python

# The .desktop file
desktop.files = *.desktop

# Please do not modify the following line.
include(sailfishapplication/sailfishapplication.pri)

TARGETPATH = /opt/$$TARGET
target.path = $$TARGETPATH

DEPLOYMENT_PATH = /opt/$$TARGET
qml.path = $$DEPLOYMENT_PATH
desktop.path = /usr/share/applications

OTHER_FILES = \
    cover/*.qml \
    pages/*.qml \
    python/* \
    icons/ownnotes.png \
    icons/ownnotes.svg \
    rpm/ownNotes.spec \
    rpm/ownNotes.yaml \
    ownNotes.desktop

INSTALLS += python_files icon_files
python_files.files = python/*
python_files.path = /opt/$$TARGET/python
icon_files.files = icons/*
icon_files.path = /opt/$$TARGET/icons

