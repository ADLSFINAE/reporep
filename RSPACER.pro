QT       += core gui  location positioning quickwidgets

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

CONFIG += c++11

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
    QmlBridge.cpp \
    data_storage.cpp \
    main.cpp \
    mainwindow.cpp

HEADERS += \
    QmlBridge.h \
    data_storage.h \
    mainwindow.h

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \
    Map/Items/Marker.qml \
    Map/Items/NoiseCircle.qml \
    Map/Items/Satellite.qml \
    Map/JsonWorker/JsonData.qml \
    Map/map.qml \
    SettingsWindow/solarsystem.qml \
    main.qml

RESOURCES += \
    Images.qrc \
    JsonFiles/circles.qrc \
    qml.qrc
