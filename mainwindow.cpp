#include "mainwindow.h"
#include <QApplication>
#include <QRandomGenerator>
#include <QDebug>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , mapWidget(new QQuickWidget(this))
    , markerCounter(0)
{
    setupUI();
    setupMap();

    setWindowTitle("Мониторинг зашумленности радиоэфира - Оффлайн Карта");
    setMinimumSize(1024, 768);
}

MainWindow::~MainWindow()
{
}

void MainWindow::setupUI()
{
    // Создание центрального виджета
    QWidget *centralWidget = new QWidget(this);
    setCentralWidget(centralWidget);

    // Основной layout
    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);

    // Панель управления
    QHBoxLayout *controlLayout = new QHBoxLayout();

    // Координаты
    QLabel *latLabel = new QLabel("Широта:", this);
    latEdit = new QLineEdit(this);
    latEdit->setText("55.7558");
    latEdit->setMaximumWidth(100);

    QLabel *lngLabel = new QLabel("Долгота:", this);
    lngEdit = new QLineEdit(this);
    lngEdit->setText("37.6173");
    lngEdit->setMaximumWidth(100);

    QLabel *zoomLabel = new QLabel("Масштаб:", this);
    zoomEdit = new QLineEdit(this);
    zoomEdit->setText("10");
    zoomEdit->setMaximumWidth(50);

    // Кнопки
    flyToButton = new QPushButton("Перелететь", this);
    addMarkerButton = new QPushButton("Добавить маркер", this);
    clearMarkersButton = new QPushButton("Очистить маркеры", this);
    zoomInButton = new QPushButton("+", this);
    zoomOutButton = new QPushButton("-", this);

    zoomInButton->setMaximumWidth(30);
    zoomOutButton->setMaximumWidth(30);

    // Слайдер масштаба
    zoomSlider = new QSlider(Qt::Horizontal, this);
    zoomSlider->setRange(1, 20);
    zoomSlider->setValue(10);
    zoomSlider->setMaximumWidth(150);

    // Выбор типа карты
    QLabel *mapTypeLabel = new QLabel("Тип карты:", this);
    mapTypeCombo = new QComboBox(this);
    mapTypeCombo->addItem("Улицы");
    mapTypeCombo->addItem("Спутник");
    mapTypeCombo->addItem("Гибрид");
    mapTypeCombo->addItem("Террейн");
    mapTypeCombo->setMaximumWidth(120);

    // Компоновка элементов управления
    controlLayout->addWidget(latLabel);
    controlLayout->addWidget(latEdit);
    controlLayout->addWidget(lngLabel);
    controlLayout->addWidget(lngEdit);
    controlLayout->addWidget(zoomLabel);
    controlLayout->addWidget(zoomEdit);
    controlLayout->addWidget(flyToButton);
    controlLayout->addWidget(addMarkerButton);
    controlLayout->addWidget(clearMarkersButton);
    controlLayout->addWidget(zoomInButton);
    controlLayout->addWidget(zoomOutButton);
    controlLayout->addWidget(zoomSlider);
    controlLayout->addWidget(mapTypeLabel);
    controlLayout->addWidget(mapTypeCombo);
    controlLayout->addStretch();

    mainLayout->addLayout(controlLayout);
    mainLayout->addWidget(mapWidget);

    // Подключение сигналов
    connect(flyToButton, &QPushButton::clicked, this, &MainWindow::onFlyToClicked);
    connect(addMarkerButton, &QPushButton::clicked, this, &MainWindow::onAddMarkerClicked);
    connect(clearMarkersButton, &QPushButton::clicked, this, &MainWindow::clearMarkers);
    connect(zoomInButton, &QPushButton::clicked, this, &MainWindow::onZoomInClicked);
    connect(zoomOutButton, &QPushButton::clicked, this, &MainWindow::onZoomOutClicked);
    connect(zoomSlider, &QSlider::valueChanged, this, &MainWindow::onZoomSliderChanged);
    connect(mapTypeCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &MainWindow::onMapTypeChanged);

    // Статус бар
    statusBar()->showMessage("Инициализация карты...");
}

void MainWindow::setupMap()
{
    // Настройка QQuickWidget для отображения карты
    mapWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    mapWidget->setSource(QUrl("qrc:/map.qml"));

    // Подключение сигналов загрузки карты
    connect(mapWidget, &QQuickWidget::statusChanged, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Ready) {
            onMapLoaded();
        }
    });
}

bool MainWindow::invokeQMLMethod(const QString &method, const QVariant &arg1,
                                const QVariant &arg2, const QVariant &arg3)
{
    if (!mapWidget->rootObject()) {
        qDebug() << "Root object not available";
        return false;
    }

    QVariant returnedValue;
    bool success = false;

    if (arg3.isValid()) {
        success = QMetaObject::invokeMethod(mapWidget->rootObject(), method.toUtf8(),
                                           Q_RETURN_ARG(QVariant, returnedValue),
                                           Q_ARG(QVariant, arg1),
                                           Q_ARG(QVariant, arg2),
                                           Q_ARG(QVariant, arg3));
    } else if (arg2.isValid()) {
        success = QMetaObject::invokeMethod(mapWidget->rootObject(), method.toUtf8(),
                                           Q_RETURN_ARG(QVariant, returnedValue),
                                           Q_ARG(QVariant, arg1),
                                           Q_ARG(QVariant, arg2));
    } else if (arg1.isValid()) {
        success = QMetaObject::invokeMethod(mapWidget->rootObject(), method.toUtf8(),
                                           Q_RETURN_ARG(QVariant, returnedValue),
                                           Q_ARG(QVariant, arg1));
    } else {
        success = QMetaObject::invokeMethod(mapWidget->rootObject(), method.toUtf8(),
                                           Q_RETURN_ARG(QVariant, returnedValue));
    }

    if (!success) {
        qDebug() << "Failed to invoke QML method:" << method;
    }

    return success;
}

void MainWindow::onMapLoaded()
{
    statusBar()->showMessage("Карта успешно загружена");
    qDebug() << "Карта успешно загружена";
}

void MainWindow::onFlyToClicked()
{
    bool latOk, lngOk, zoomOk;
    double lat = latEdit->text().toDouble(&latOk);
    double lng = lngEdit->text().toDouble(&lngOk);
    int zoom = zoomEdit->text().toInt(&zoomOk);

    if (latOk && lngOk && zoomOk) {
        invokeQMLMethod("setCenter", lat, lng, zoom);
        statusBar()->showMessage(QString("Перелет к координатам: %1, %2").arg(lat).arg(lng));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты или масштаб");
    }
}

void MainWindow::onAddMarkerClicked()
{
    bool latOk, lngOk;
    double lat = latEdit->text().toDouble(&latOk);
    double lng = lngEdit->text().toDouble(&lngOk);

    if (latOk && lngOk) {
        // Генерация тестового уровня шума
        double noiseLevel = -85 - (QRandomGenerator::global()->generate() % 20);
        QString title = QString("Маркер %1: %2 дБм").arg(++markerCounter).arg(noiseLevel, 0, 'f', 1);

        addMarker(lat, lng, title, noiseLevel);
        statusBar()->showMessage(QString("Добавлен маркер: %1").arg(title));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты");
    }
}

void MainWindow::addMarker(double lat, double lng, const QString &title, double noiseLevel)
{
    invokeQMLMethod("addMarker", lat, lng, title);
}

void MainWindow::clearMarkers()
{
    invokeQMLMethod("clearMarkers");
    markerCounter = 0;
    statusBar()->showMessage("Маркеры очищены");
}

void MainWindow::onZoomInClicked()
{
    int currentZoom = zoomSlider->value();
    if (currentZoom < zoomSlider->maximum()) {
        zoomSlider->setValue(currentZoom + 1);
    }
}

void MainWindow::onZoomOutClicked()
{
    int currentZoom = zoomSlider->value();
    if (currentZoom > zoomSlider->minimum()) {
        zoomSlider->setValue(currentZoom - 1);
    }
}

void MainWindow::onZoomSliderChanged(int value)
{
    zoomEdit->setText(QString::number(value));
    invokeQMLMethod("setZoom", value);
}

void MainWindow::onMapTypeChanged(int index)
{
    QString mapType;
    switch (index) {
        case 0: mapType = "street"; break;
        case 1: mapType = "satellite"; break;
        case 2: mapType = "hybrid"; break;
        case 3: mapType = "terrain"; break;
        default: mapType = "street";
    }

    invokeQMLMethod("setMapType", mapType);
}
