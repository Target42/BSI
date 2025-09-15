QT       += core gui network xml

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

CONFIG += c++17

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
    book/basenode.cpp \
    book/book.cpp \
    book/chapter.cpp \
    book/emphasis.cpp \
    book/indexnode.cpp \
    book/indexstore.cpp \
    book/info.cpp \
    book/itemlist.cpp \
    book/listitem.cpp \
    book/nodefactory.cpp \
    book/para.cpp \
    book/section.cpp \
    book/title.cpp \
    book/wordindex.cpp \
    editorwidget.cpp \
    main.cpp \
    mainwindow.cpp

HEADERS += \
    book/basenode.h \
    book/book.h \
    book/chapter.h \
    book/emphasis.h \
    book/indexnode.h \
    book/indexstore.h \
    book/info.h \
    book/itemlist.h \
    book/listitem.h \
    book/nodefactory.h \
    book/para.h \
    book/section.h \
    book/title.h \
    book/wordindex.h \
    editorwidget.h \
    mainwindow.h

FORMS += \
    editorwidget.ui \
    mainwindow.ui

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
