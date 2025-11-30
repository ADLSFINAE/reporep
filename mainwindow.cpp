#include "mainwindow.h"
#include <QApplication>
#include <QRandomGenerator>
#include <QDebug>
#include <QDateTime>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLineEdit>
#include <QLabel>
#include <QSlider>
#include <QComboBox>
#include <QStatusBar>
#include <QMessageBox>

// Реализация SolarSystemDialog
SolarSystemDialog::SolarSystemDialog(QWidget *parent)
    : QDialog(parent), solarSystemWidget(new QQuickWidget(this))
{
    setWindowTitle("Солнечная система - Влияние на радиоизлучение");
    setMinimumSize(1200, 800);
    resize(1200, 800);

    QVBoxLayout *layout = new QVBoxLayout(this);
    layout->addWidget(solarSystemWidget);

    solarSystemWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    solarSystemWidget->setSource(QUrl("qrc:/SettingsWindow/solarsystem.qml"));

    // Устанавливаем начальную дату - 1 января 2025
    currentDateTime = QDateTime(QDate(2025, 1, 1), QTime(6, 0));

    // Устанавливаем контекст для доступа к свойствам
    solarSystemWidget->rootContext()->setContextProperty("solarSystemDialog", this);
    solarSystemWidget->rootContext()->setContextProperty("mainWindow", qobject_cast<QObject*>(parent));
}

SolarSystemDialog::~SolarSystemDialog()
{
}

void SolarSystemDialog::setDateTime(const QDateTime &dateTime)
{
    currentDateTime = dateTime;
}

void SolarSystemDialog::setCurrentTime(double hour, double days)
{
    if (solarSystemWidget->rootObject()) {
        QMetaObject::invokeMethod(solarSystemWidget->rootObject(), "setCurrentTime",
                                 Q_ARG(QVariant, hour),
                                 Q_ARG(QVariant, days));
    }
}

QDateTime SolarSystemDialog::getDateTime() const
{
    return currentDateTime;
}

double SolarSystemDialog::getSolarInfluence() const
{
    if (solarSystemWidget->rootObject()) {
        QVariant result;
        QMetaObject::invokeMethod(solarSystemWidget->rootObject(), "getSolarInfluence",
                                 Q_RETURN_ARG(QVariant, result));
        return result.toDouble();
    }
    return 1.0;
}

double SolarSystemDialog::getLunarInfluence() const
{
    if (solarSystemWidget->rootObject()) {
        QVariant result;
        QMetaObject::invokeMethod(solarSystemWidget->rootObject(), "getLunarInfluence",
                                 Q_RETURN_ARG(QVariant, result));
        return result.toDouble();
    }
    return 1.0;
}

double SolarSystemDialog::getPlanetaryInfluence() const
{
    if (solarSystemWidget->rootObject()) {
        QVariant result;
        QMetaObject::invokeMethod(solarSystemWidget->rootObject(), "getPlanetaryInfluence",
                                 Q_RETURN_ARG(QVariant, result));
        return result.toDouble();
    }
    return 1.0;
}

void SolarSystemDialog::onDateTimeChanged()
{
    emit dateTimeChanged(currentDateTime);
}

// Основной конструктор MainWindow
MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , mapWidget(new QQuickWidget(this))
    , solarSystemDialog(new SolarSystemDialog(this))
    , markerCounter(0)
    , solarInfluence(1.0)
    , lunarInfluence(1.0)
    , planetaryInfluence(1.0)
{
    setupUI();
    setupMap();

    setWindowTitle("Мониторинг зашумленности радиоэфира - Оффлайн Карта");
    setMinimumSize(1200, 900);
    resize(1400, 1000);

    connect(solarSystemDialog, &SolarSystemDialog::dateTimeChanged,
            this, &MainWindow::onDateTimeChanged);

    // Таймер для постоянной синхронизации времени с solar system
    QTimer *syncTimer = new QTimer(this);
    connect(syncTimer, &QTimer::timeout, this, &MainWindow::syncTimeWithSolarSystem);
    syncTimer->start(100); // Синхронизация каждые 100 мс
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
    latEdit->setMaximumWidth(120);

    QLabel *lngLabel = new QLabel("Долгота:", this);
    lngEdit = new QLineEdit(this);
    lngEdit->setText("37.6173");
    lngEdit->setMaximumWidth(120);

    QLabel *zoomLabel = new QLabel("Масштаб:", this);
    zoomEdit = new QLineEdit(this);
    zoomEdit->setText("10");
    zoomEdit->setMaximumWidth(60);

    // Кнопки
    flyToButton = new QPushButton("Перелететь", this);
    addMarkerButton = new QPushButton("Добавить маркер", this);
    clearMarkersButton = new QPushButton("Очистить маркеры", this);
    zoomInButton = new QPushButton("+", this);
    zoomOutButton = new QPushButton("-", this);
    solarSystemButton = new QPushButton("Солнечная система", this);

    // Новые кнопки для управления спутниками
    addSatelliteButton = new QPushButton("Добавить спутник", this);
    clearSatellitesButton = new QPushButton("Очистить спутники", this);
    toggleSatellitesButton = new QPushButton("Спутники Вкл", this);
    addPolarSatelliteButton = new QPushButton("Полярный", this);
    addInclinedSatelliteButton = new QPushButton("Наклонный", this);

    zoomInButton->setMaximumWidth(40);
    zoomOutButton->setMaximumWidth(40);
    solarSystemButton->setMaximumWidth(160);
    flyToButton->setMaximumWidth(100);
    addMarkerButton->setMaximumWidth(140);
    clearMarkersButton->setMaximumWidth(140);
    addSatelliteButton->setMaximumWidth(140);
    clearSatellitesButton->setMaximumWidth(140);
    toggleSatellitesButton->setMaximumWidth(120);
    addPolarSatelliteButton->setMaximumWidth(100);
    addInclinedSatelliteButton->setMaximumWidth(100);

    // Слайдер масштаба
    zoomSlider = new QSlider(Qt::Horizontal, this);
    zoomSlider->setRange(1, 20);
    zoomSlider->setValue(10);
    zoomSlider->setMaximumWidth(200);

    // Слайдер радиуса анализа
    QLabel *radiusLabel = new QLabel("Радиус (м):", this);
    radiusSlider = new QSlider(Qt::Horizontal, this);
    radiusSlider->setRange(100, 5000);
    radiusSlider->setValue(1000);
    radiusSlider->setMaximumWidth(200);

    QLabel *radiusValueLabel = new QLabel("1000", this);
    radiusValueLabel->setMaximumWidth(60);

    // Выбор типа карты
    QLabel *mapTypeLabel = new QLabel("Тип карты:", this);
    mapTypeCombo = new QComboBox(this);
    mapTypeCombo->addItem("Улицы");
    mapTypeCombo->addItem("Спутник");
    mapTypeCombo->addItem("Гибрид");
    mapTypeCombo->addItem("Террейн");
    mapTypeCombo->setMaximumWidth(140);

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
    controlLayout->addWidget(solarSystemButton);

    // Добавляем кнопки спутников
    controlLayout->addWidget(addSatelliteButton);
    controlLayout->addWidget(clearSatellitesButton);
    controlLayout->addWidget(toggleSatellitesButton);
    controlLayout->addWidget(addPolarSatelliteButton);
    controlLayout->addWidget(addInclinedSatelliteButton);

    controlLayout->addWidget(zoomSlider);
    controlLayout->addWidget(radiusLabel);
    controlLayout->addWidget(radiusSlider);
    controlLayout->addWidget(radiusValueLabel);
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
    connect(solarSystemButton, &QPushButton::clicked, this, &MainWindow::onSolarSystemClicked);

    // Подключение сигналов для спутников
    connect(addSatelliteButton, &QPushButton::clicked, this, &MainWindow::onAddSatelliteClicked);
    connect(clearSatellitesButton, &QPushButton::clicked, this, &MainWindow::onClearSatellitesClicked);
    connect(toggleSatellitesButton, &QPushButton::clicked, this, &MainWindow::onToggleSatellitesClicked);
    connect(addPolarSatelliteButton, &QPushButton::clicked, this, &MainWindow::onAddPolarSatelliteClicked);
    connect(addInclinedSatelliteButton, &QPushButton::clicked, this, &MainWindow::onAddInclinedSatelliteClicked);

    connect(zoomSlider, &QSlider::valueChanged, this, &MainWindow::onZoomSliderChanged);
    connect(radiusSlider, &QSlider::valueChanged, this, &MainWindow::onAnalysisRadiusChanged);
    connect(radiusSlider, &QSlider::valueChanged, radiusValueLabel, QOverload<int>::of(&QLabel::setNum));
    connect(mapTypeCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &MainWindow::onMapTypeChanged);
}

void MainWindow::setupMap()
{
    // Настройка QQuickWidget для отображения карты
    mapWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    mapWidget->setSource(QUrl("qrc:/Map/map.qml"));

    // Установка контекста для доступа к свойствам
    mapWidget->rootContext()->setContextProperty("mainWindow", this);

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

    // Синхронизируем время с солнечной системой после загрузки карты
    syncTimeWithSolarSystem();
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
        // Генерация тестового уровня шума с учетом влияния небесных тел
        double baseNoiseLevel = -85 - (QRandomGenerator::global()->generate() % 20);
        double totalInfluence = solarInfluence * lunarInfluence * planetaryInfluence;
        double influencedNoiseLevel = baseNoiseLevel * totalInfluence;
        QString title = QString("Маркер %1").arg(++markerCounter);

        addMarker(lat, lng, title, influencedNoiseLevel);
        statusBar()->showMessage(QString("Добавлен маркер: %1 (%2 дБм, влияние: %3x)")
                                .arg(title)
                                .arg(influencedNoiseLevel, 0, 'f', 1)
                                .arg(totalInfluence, 0, 'f', 2));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты");
    }
}

void MainWindow::addMarker(double lat, double lng, const QString &title, double noiseLevel)
{
    // Создаем объект с данными маркера
    QVariantMap markerData;
    markerData["lat"] = lat;
    markerData["lng"] = lng;
    markerData["title"] = title;
    markerData["noiseLevel"] = noiseLevel;

    invokeQMLMethod("addMarkerWithData", QVariant::fromValue(markerData));
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

void MainWindow::onSolarSystemClicked()
{
    solarSystemDialog->show();
    solarSystemDialog->raise();
    solarSystemDialog->activateWindow();

    // Синхронизируем время с основным окном
    syncTimeWithSolarSystem();

    statusBar()->showMessage("Открыто окно солнечной системы");
}

void MainWindow::onDateTimeChanged(const QDateTime &dateTime)
{
    // Обновляем влияние небесных тел при изменении даты/времени
    solarInfluence = solarSystemDialog->getSolarInfluence();
    lunarInfluence = solarSystemDialog->getLunarInfluence();
    planetaryInfluence = solarSystemDialog->getPlanetaryInfluence();

    updateCelestialInfluence();

    QString influenceText = QString("Обновлено влияние: Солнце: %1x, Луна: %2x, Планеты: %3x, Общее: %4x")
                            .arg(solarInfluence, 0, 'f', 2)
                            .arg(lunarInfluence, 0, 'f', 2)
                            .arg(planetaryInfluence, 0, 'f', 2)
                            .arg(solarInfluence * lunarInfluence * planetaryInfluence, 0, 'f', 2);

    statusBar()->showMessage(influenceText);

    // Обновляем все маркеры с новым влиянием
    updateAllMarkersWithInfluence();
}

void MainWindow::updateCelestialInfluence()
{
    // Передаем влияние в QML карту
    double totalInfluence = solarInfluence * lunarInfluence * planetaryInfluence;
    invokeQMLMethod("setCelestialInfluence", totalInfluence);

    qDebug() << "Обновлено влияние небесных тел:"
             << "Солнце:" << solarInfluence
             << "Луна:" << lunarInfluence
             << "Планеты:" << planetaryInfluence
             << "Общее:" << totalInfluence;
}

void MainWindow::updateAllMarkersWithInfluence()
{
    // Если есть маркеры, обновляем анализ области с новым влиянием
    if (markerCounter > 0) {
        invokeQMLMethod("updateAnalysisWithInfluence");
    }
}

void MainWindow::syncTimeWithSolarSystem()
{
    // Синхронизируем только если окно solar system открыто
    if (solarSystemDialog->isVisible() && mapWidget->rootObject() && solarSystemDialog) {
        // Получаем текущее время из карты
        QVariant currentTime;
        bool success = QMetaObject::invokeMethod(mapWidget->rootObject(), "getCurrentTime",
                                                Q_RETURN_ARG(QVariant, currentTime));

        QVariant currentDays;
        bool daysSuccess = QMetaObject::invokeMethod(mapWidget->rootObject(), "getDaysFromStart",
                                                   Q_RETURN_ARG(QVariant, currentDays));

        if (success && daysSuccess && currentTime.isValid() && currentDays.isValid()) {
            // Устанавливаем актуальное время в солнечной системе
            double actualHour = currentTime.toDouble();
            double actualDays = currentDays.toDouble();

            solarSystemDialog->setCurrentTime(actualHour, actualDays);

            // Обновляем влияние небесных тел
            solarInfluence = solarSystemDialog->getSolarInfluence();
            lunarInfluence = solarSystemDialog->getLunarInfluence();
            planetaryInfluence = solarSystemDialog->getPlanetaryInfluence();
            updateCelestialInfluence();

            static int syncCounter = 0;
            if (syncCounter++ % 100 == 0) { // Логируем каждые 10 секунд чтобы не засорять консоль
                qDebug() << "Синхронизировано время с solar system. Часы:" << actualHour << "Дни:" << actualDays;
            }
        }
    }
}

void MainWindow::syncSolarSystemTime(double hour, double days)
{
    // Этот метод вызывается из QML solar system для запроса синхронизации
    Q_UNUSED(hour);
    Q_UNUSED(days);

    // Просто вызываем синхронизацию - solar system запросил обновление
    syncTimeWithSolarSystem();
}

void MainWindow::onZoomSliderChanged(int value)
{
    zoomEdit->setText(QString::number(value));
    invokeQMLMethod("setZoom", value);
}

void MainWindow::onAnalysisRadiusChanged(int value)
{
    invokeQMLMethod("setAnalysisRadius", value);
    statusBar()->showMessage(QString("Радиус анализа установлен: %1 м").arg(value));
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

// Методы для управления спутниками
void MainWindow::onAddSatelliteClicked()
{
    invokeQMLMethod("addRandomSatellite");
    statusBar()->showMessage("Добавлен случайный спутник");
}

void MainWindow::onClearSatellitesClicked()
{
    invokeQMLMethod("clearSatellites");
    statusBar()->showMessage("Спутники очищены");
}

void MainWindow::onToggleSatellitesClicked()
{
    QVariant result;
    QMetaObject::invokeMethod(mapWidget->rootObject(), "toggleSatellitesVisibility",
                             Q_RETURN_ARG(QVariant, result));

    bool visible = result.toBool();
    statusBar()->showMessage(visible ? "Спутники показаны" : "Спутники скрыты");

    // Обновляем текст кнопки
    if (toggleSatellitesButton) {
        toggleSatellitesButton->setText(visible ? "Спутники Выкл" : "Спутники Вкл");
    }
}

void MainWindow::onAddPolarSatelliteClicked()
{
    invokeQMLMethod("addPolarSatellite");
    statusBar()->showMessage("Добавлен спутник на полярную орбиту");
}

void MainWindow::onAddInclinedSatelliteClicked()
{
    invokeQMLMethod("addInclinedSatellite");
    statusBar()->showMessage("Добавлен спутник на наклонную орбиту");
}


