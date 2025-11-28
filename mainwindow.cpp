#include "mainwindow.h"
#include <QApplication>
#include <QRandomGenerator>
#include <QDebug>
#include <QGroupBox>
#include <QSpinBox>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , mapWidget(new QQuickWidget(this))
    , monitoringTimer(new QTimer(this))
    , measurementCounter(0)
    , isMonitoring(false)
{
    setupUI();
    setupMap();

    setWindowTitle("Мониторинг зашумленности радиоэфира");
    setMinimumSize(1200, 800);
}

MainWindow::~MainWindow()
{
    if (monitoringTimer) {
        monitoringTimer->stop();
    }
}

void MainWindow::setupUI()
{
    // Создание центрального виджета
    QWidget *centralWidget = new QWidget(this);
    setCentralWidget(centralWidget);

    // Основной layout
    QHBoxLayout *mainLayout = new QHBoxLayout(centralWidget);

    // Левая панель с управлением
    QWidget *controlPanel = new QWidget(this);
    controlPanel->setMaximumWidth(300);
    QVBoxLayout *controlLayout = new QVBoxLayout(controlPanel);

    // Группа управления картой
    QGroupBox *mapGroup = new QGroupBox("Управление картой", this);
    QVBoxLayout *mapLayout = new QVBoxLayout(mapGroup);

    // Координаты
    QHBoxLayout *coordsLayout = new QHBoxLayout();
    QLabel *latLabel = new QLabel("Широта:", this);
    latEdit = new QLineEdit(this);
    latEdit->setText("55.7558");

    QLabel *lngLabel = new QLabel("Долгота:", this);
    lngEdit = new QLineEdit(this);
    lngEdit->setText("37.6173");

    QLabel *zoomLabel = new QLabel("Масштаб:", this);
    zoomEdit = new QLineEdit(this);
    zoomEdit->setText("10");

    coordsLayout->addWidget(latLabel);
    coordsLayout->addWidget(latEdit);
    coordsLayout->addWidget(lngLabel);
    coordsLayout->addWidget(lngEdit);
    coordsLayout->addWidget(zoomLabel);
    coordsLayout->addWidget(zoomEdit);

    // Кнопки управления картой
    QHBoxLayout *mapButtonsLayout = new QHBoxLayout();
    flyToButton = new QPushButton("Перелететь", this);
    zoomInButton = new QPushButton("+", this);
    zoomOutButton = new QPushButton("-", this);

    zoomInButton->setMaximumWidth(30);
    zoomOutButton->setMaximumWidth(30);

    mapButtonsLayout->addWidget(flyToButton);
    mapButtonsLayout->addWidget(zoomInButton);
    mapButtonsLayout->addWidget(zoomOutButton);

    // Слайдер масштаба
    zoomSlider = new QSlider(Qt::Horizontal, this);
    zoomSlider->setRange(1, 20);
    zoomSlider->setValue(10);

    // Выбор типа карты
    QHBoxLayout *mapTypeLayout = new QHBoxLayout();
    QLabel *mapTypeLabel = new QLabel("Тип карты:", this);
    mapTypeCombo = new QComboBox(this);
    mapTypeCombo->addItem("Улицы");
    mapTypeCombo->addItem("Спутник");
    mapTypeCombo->addItem("Гибрид");
    mapTypeCombo->addItem("Террейн");

    mapTypeLayout->addWidget(mapTypeLabel);
    mapTypeLayout->addWidget(mapTypeCombo);

    mapLayout->addLayout(coordsLayout);
    mapLayout->addLayout(mapButtonsLayout);
    mapLayout->addWidget(zoomSlider);
    mapLayout->addLayout(mapTypeLayout);

    // Группа мониторинга
    QGroupBox *monitorGroup = new QGroupBox("Мониторинг излучения", this);
    QVBoxLayout *monitorLayout = new QVBoxLayout(monitorGroup);

    // Радиус измерения
    QHBoxLayout *radiusLayout = new QHBoxLayout();
    QLabel *radiusLabel = new QLabel("Радиус (км):", this);
    radiusSpinBox = new QSpinBox(this);
    radiusSpinBox->setRange(1, 100);
    radiusSpinBox->setValue(10);
    radiusSpinBox->setSuffix(" км");

    radiusLayout->addWidget(radiusLabel);
    radiusLayout->addWidget(radiusSpinBox);

    // Кнопки мониторинга
    QHBoxLayout *monitorButtonsLayout = new QHBoxLayout();
    addZoneButton = new QPushButton("Добавить зону", this);
    startMonitoringButton = new QPushButton("Старт", this);
    stopMonitoringButton = new QPushButton("Стоп", this);
    clearButton = new QPushButton("Очистить", this);

    stopMonitoringButton->setEnabled(false);

    monitorButtonsLayout->addWidget(addZoneButton);
    monitorButtonsLayout->addWidget(startMonitoringButton);
    monitorButtonsLayout->addWidget(stopMonitoringButton);
    monitorButtonsLayout->addWidget(clearButton);

    // Отображение данных
    statusLabel = new QLabel("Статус: Ожидание", this);
    measurement70cmLabel = new QLabel("70 см: -- дБм", this);
    measurement2mLabel = new QLabel("2 м: -- дБм", this);

    QFont dataFont;
    dataFont.setBold(true);
    measurement70cmLabel->setFont(dataFont);
    measurement2mLabel->setFont(dataFont);

    monitorLayout->addLayout(radiusLayout);
    monitorLayout->addLayout(monitorButtonsLayout);
    monitorLayout->addWidget(statusLabel);
    monitorLayout->addWidget(measurement70cmLabel);
    monitorLayout->addWidget(measurement2mLabel);

    // Компоновка левой панели
    controlLayout->addWidget(mapGroup);
    controlLayout->addWidget(monitorGroup);
    controlLayout->addStretch();

    // Правая часть с картой
    mainLayout->addWidget(controlPanel);
    mainLayout->addWidget(mapWidget);

    // Подключение сигналов
    connect(flyToButton, &QPushButton::clicked, this, &MainWindow::onFlyToClicked);
    connect(addZoneButton, &QPushButton::clicked, this, &MainWindow::onAddMeasurementZoneClicked);
    connect(startMonitoringButton, &QPushButton::clicked, this, &MainWindow::onStartMonitoringClicked);
    connect(stopMonitoringButton, &QPushButton::clicked, this, &MainWindow::onStopMonitoringClicked);
    connect(clearButton, &QPushButton::clicked, this, &MainWindow::onClearClicked);
    connect(zoomInButton, &QPushButton::clicked, this, &MainWindow::onZoomInClicked);
    connect(zoomOutButton, &QPushButton::clicked, this, &MainWindow::onZoomOutClicked);
    connect(zoomSlider, &QSlider::valueChanged, this, &MainWindow::onZoomSliderChanged);
    connect(mapTypeCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &MainWindow::onMapTypeChanged);
    connect(radiusSpinBox, QOverload<int>::of(&QSpinBox::valueChanged),
            this, &MainWindow::onRadiusChanged);

    // Таймер для имитации сбора данных
    connect(monitoringTimer, &QTimer::timeout, this, &MainWindow::simulateDataCollection);

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
        } else if (status == QQuickWidget::Error) {
            qDebug() << "Ошибка загрузки QML";
        }
    });
}

#include <QQuickItem>
// Упрощенная функция вызова QML методов через JavaScript
void MainWindow::callQMLFunction(const QString &function, const QVariant &arg1,
                                const QVariant &arg2, const QVariant &arg3)
{
    if (!mapWidget || !mapWidget->rootObject()) {
        qDebug() << "QML root object not available";
        return;
    }

    QString jsCode;
    if (arg3.isValid()) {
        jsCode = QString("%1(%2, %3, %4)").arg(function).arg(arg1.toString()).arg(arg2.toString()).arg(arg3.toString());
    } else if (arg2.isValid()) {
        jsCode = QString("%1(%2, %3)").arg(function).arg(arg1.toString()).arg(arg2.toString());
    } else if (arg1.isValid()) {
        jsCode = QString("%1(%2)").arg(function).arg(arg1.toString());
    } else {
        jsCode = QString("%1()").arg(function);
    }

    // Используем evaluateJavaScript для вызова функций QML
   // QVariant result = mapWidget->rootObject()->evaluateJavaScript(jsCode);
   // qDebug() << "Called QML function:" << jsCode << "Result:" << result;
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
        callQMLFunction("setCenter", lat, lng, zoom);
        statusBar()->showMessage(QString("Перелет к координатам: %1, %2").arg(lat).arg(lng));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты или масштаб");
    }
}

void MainWindow::onAddMeasurementZoneClicked()
{
    bool latOk, lngOk;
    double lat = latEdit->text().toDouble(&latOk);
    double lng = lngEdit->text().toDouble(&lngOk);

    if (latOk && lngOk) {
        double radius = radiusSpinBox->value();
        addMeasurementZone(lat, lng, radius);
        statusBar()->showMessage(QString("Добавлена зона измерения: радиус %1 км").arg(radius));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты");
    }
}

void MainWindow::addMeasurementZone(double lat, double lng, double radiusKm)
{
    callQMLFunction("addMeasurementZone", lat, lng, radiusKm);
}

void MainWindow::updateRadiationVisualization(double lat, double lng, double noiseLevel70cm, double noiseLevel2m)
{
    //callQMLFunction("updateRadiationData", lat, lng, noiseLevel70cm, noiseLevel2m);
}

void MainWindow::onStartMonitoringClicked()
{
    isMonitoring = true;
    monitoringTimer->start(2000); // Обновление каждые 2 секунды

    startMonitoringButton->setEnabled(false);
    stopMonitoringButton->setEnabled(true);
    statusLabel->setText("Статус: Мониторинг активен");
    statusBar()->showMessage("Мониторинг излучения запущен");
}

void MainWindow::onStopMonitoringClicked()
{
    isMonitoring = false;
    monitoringTimer->stop();

    startMonitoringButton->setEnabled(true);
    stopMonitoringButton->setEnabled(false);
    statusLabel->setText("Статус: Ожидание");
    statusBar()->showMessage("Мониторинг излучения остановлен");
}

void MainWindow::onClearClicked()
{
    clearVisualizations();
}

void MainWindow::simulateDataCollection()
{
    if (!isMonitoring) return;

    measurementCounter++;

    // Имитация данных с разных диапазонов
    double baseNoise70cm = -85 + (QRandomGenerator::global()->generate() % 30) - 15; // -70 до -100 дБм
    double baseNoise2m = -90 + (QRandomGenerator::global()->generate() % 25) - 12;   // -75 до -102 дБм

    // Добавляем некоторую корреляцию между диапазонами
    double correlation = (QRandomGenerator::global()->generate() % 20) / 100.0; // 0-0.2
    baseNoise2m += (baseNoise70cm + 85) * correlation;

    // Обновляем отображение
    measurement70cmLabel->setText(QString("70 см: %1 дБм").arg(baseNoise70cm, 0, 'f', 1));
    measurement2mLabel->setText(QString("2 м: %1 дБм").arg(baseNoise2m, 0, 'f', 1));

    // Получаем текущие координаты из полей ввода
    bool latOk, lngOk;
    double lat = latEdit->text().toDouble(&latOk);
    double lng = lngEdit->text().toDouble(&lngOk);

    if (latOk && lngOk) {
        updateRadiationVisualization(lat, lng, baseNoise70cm, baseNoise2m);
    }

    statusBar()->showMessage(QString("Измерение #%1: 70см=%2 дБм, 2м=%3 дБм")
                            .arg(measurementCounter)
                            .arg(baseNoise70cm, 0, 'f', 1)
                            .arg(baseNoise2m, 0, 'f', 1));
}

void MainWindow::clearVisualizations()
{
    callQMLFunction("clearAllVisualizations");
    measurementCounter = 0;
    measurement70cmLabel->setText("70 см: -- дБм");
    measurement2mLabel->setText("2 м: -- дБм");
    statusBar()->showMessage("Визуализации очищены");
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
    callQMLFunction("setZoom", value);
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

    callQMLFunction("setMapType", mapType);
}

void MainWindow::onRadiusChanged(int value)
{
    statusBar()->showMessage(QString("Радиус измерения установлен: %1 км").arg(value));
}
