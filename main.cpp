#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "mainwindow.h"
#include "data_storage.h"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    // Устанавливаем информацию о приложении
    app.setApplicationName("Мониторинг радиоизлучения");
    app.setOrganizationName("Геофизика");
    app.setApplicationVersion("1.0.0");

    MainWindow window;
    window.show();

    return app.exec();
}
