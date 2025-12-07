#include "mainwindow.h"
#include "data_storage.h"
#include "simplechartwindow.h"  // Изменено

#include <QRandomGenerator>
#include <QMetaObject>
#include <QDebug>

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

void SolarSystemDialog::setCurrentTime(double hour, double days)
{
    if (solarSystemWidget->rootObject()) {
        QMetaObject::invokeMethod(solarSystemWidget->rootObject(), "setCurrentTime",
                                 Q_ARG(QVariant, hour),
                                 Q_ARG(QVariant, days));
    }
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

// Основной конструктор MainWindow
MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , qmlBridge(new QmlBridge(this))
    , m_chartWindow(nullptr)
    , mapWidget(new QQuickWidget(this))
    , solarSystemDialog(new SolarSystemDialog(this))
    , dataStorage(new DataStorage(this))
    , solarInfluence(1.0)
    , lunarInfluence(1.0)
    , planetaryInfluence(1.0)
    , markerCounter(0)
{
    // Передаем DataStorage в мост
    qmlBridge->setDataStorage(dataStorage);

    setupUI();
    setupMap();

    setWindowTitle("RSPACER ALPHA v1");
    setMinimumSize(1200, 900);
    resize(1400, 1000);

    // Устанавливаем фильтр событий для блокировки Ctrl
    qApp->installEventFilter(this);

    connect(solarSystemDialog, &SolarSystemDialog::dateTimeChanged,
            this, &MainWindow::onDateTimeChanged);

    // Подключаем сигнал от DataStorage
    connect(dataStorage, &DataStorage::dataAdded,
            this, &MainWindow::onSatelliteDataAdded);

    // Таймер для постоянной синхронизации времени с solar system
    QTimer *syncTimer = new QTimer(this);
    connect(syncTimer, &QTimer::timeout, this, &MainWindow::syncTimeWithSolarSystem);
    syncTimer->start(100);
}

MainWindow::~MainWindow()
{
    delete dataStorage;
    if (m_chartWindow) {
        delete m_chartWindow;
    }
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
    QPushButton *flyToButton = new QPushButton("Перелететь", this);
    QPushButton *addMarkerButton = new QPushButton("Добавить маркер", this);
    QPushButton *zoomInButton = new QPushButton("+", this);
    QPushButton *zoomOutButton = new QPushButton("-", this);
    QPushButton *solarSystemButton = new QPushButton("Солнечная система", this);
    QPushButton *chartsButton = new QPushButton("Графики и аналитика", this);

    // Настройка размеров кнопок
    zoomInButton->setMaximumWidth(40);
    zoomOutButton->setMaximumWidth(40);
    solarSystemButton->setMaximumWidth(160);
    flyToButton->setMaximumWidth(100);
    addMarkerButton->setMaximumWidth(140);
    chartsButton->setMaximumWidth(150);

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
    controlLayout->addWidget(zoomInButton);
    controlLayout->addWidget(zoomOutButton);
    controlLayout->addWidget(solarSystemButton);
    controlLayout->addWidget(chartsButton);

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

    connect(solarSystemButton, &QPushButton::clicked, this, &MainWindow::onSolarSystemClicked);
    connect(chartsButton, &QPushButton::clicked, this, &MainWindow::onShowChartsClicked);

    connect(radiusSlider, &QSlider::valueChanged, this, &MainWindow::onAnalysisRadiusChanged);
    connect(radiusSlider, &QSlider::valueChanged, radiusValueLabel, QOverload<int>::of(&QLabel::setNum));
    connect(mapTypeCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &MainWindow::onMapTypeChanged);
}

void MainWindow::setupMap()
{
    qDebug() << "=== НАСТРОЙКА КАРТЫ ===";
    qDebug() << "1. DataStorage создан:" << (dataStorage != nullptr);
    qDebug() << "2. QmlBridge создан:" << (qmlBridge != nullptr);

    if (dataStorage) {
        dataStorage->testConnection();
        qDebug() << "3. DataStorage протестирован";
    }

    if (qmlBridge) {
        qDebug() << "4. QmlBridge статус:" << qmlBridge->getStorageStatus();
    }

    // Настройка QQuickWidget
    mapWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

    // Устанавливаем контекстные свойства
    QQmlContext* context = mapWidget->rootContext();

    // ОСНОВНОЙ СПОСОБ: передаем через QmlBridge
    context->setContextProperty("qmlBridge", qmlBridge);

    // АЛЬТЕРНАТИВНЫЕ СПОСОБЫ (для обратной совместимости):
    context->setContextProperty("dataStorage", dataStorage);
    context->setContextProperty("dataStorageManager", dataStorage);
    context->setContextProperty("mainWindow", this);

    qDebug() << "5. Контекстные свойства установлены";
    qDebug() << "   - qmlBridge:" << (qmlBridge ? "✅" : "❌");
    qDebug() << "   - dataStorage:" << (dataStorage ? "✅" : "❌");

    // Загружаем QML
    mapWidget->setSource(QUrl("qrc:/Map/map.qml"));

    // Подключение сигналов загрузки карты
    connect(mapWidget, &QQuickWidget::statusChanged, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Ready) {
            qDebug() << "=== КАРТА QML ЗАГРУЖЕНА ===";

            if (mapWidget->rootObject()) {
                // НЕПОСРЕДСТВЕННАЯ передача объектов в корневой объект
                mapWidget->rootObject()->setProperty("dataStorage", QVariant::fromValue(dataStorage));
                mapWidget->rootObject()->setProperty("qmlBridge", QVariant::fromValue(qmlBridge));

                qDebug() << "6. Объекты установлены в корневой объект QML";
                qDebug() << "   - dataStorage установлен:" << mapWidget->rootObject()->property("dataStorage").isValid();
                qDebug() << "   - qmlBridge установлен:" << mapWidget->rootObject()->property("qmlBridge").isValid();

                // Тестируем доступность методов
                QTimer::singleShot(100, this, [this]() {
                    qDebug() << "7. Тестирование доступности объектов в QML...";
                    QMetaObject::invokeMethod(mapWidget->rootObject(), "testDataStorageAccess");
                });
            }

            onMapLoaded();

        } else if (status == QQuickWidget::Error) {
            qDebug() << "❌ ОШИБКА ЗАГРУЗКИ QML:";
            foreach (const QQmlError &error, mapWidget->errors()) {
                qDebug() << error.toString();
            }
        }
    });

    // Дополнительная проверка через секунду
    QTimer::singleShot(1000, this, [this]() {
        qDebug() << "=== ПРОВЕРКА ЧЕРЕЗ 1 СЕКУНДУ ===";
        qDebug() << "DataStorage:" << (dataStorage ? "✅" : "❌");
        qDebug() << "QmlBridge:" << (qmlBridge ? "✅" : "❌");

        if (dataStorage) {
            dataStorage->testConnection();
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

    return success;
}

void MainWindow::onMapLoaded()
{
    statusBar()->showMessage("Карта успешно загружена");
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

        // Создаем объект с данными маркера
        QVariantMap markerData;
        markerData["lat"] = lat;
        markerData["lng"] = lng;
        markerData["title"] = title;
        markerData["noiseLevel"] = influencedNoiseLevel;

        invokeQMLMethod("addMarkerWithData", QVariant::fromValue(markerData));

        statusBar()->showMessage(QString("Добавлен маркер: %1 (%2 дБм, влияние: %3x)")
                                .arg(title)
                                .arg(influencedNoiseLevel, 0, 'f', 1)
                                .arg(totalInfluence, 0, 'f', 2));
    } else {
        QMessageBox::warning(this, "Ошибка", "Некорректные координаты");
    }
}

void MainWindow::onSolarSystemClicked()
{
    solarSystemDialog->show();
    solarSystemDialog->raise();
    solarSystemDialog->activateWindow();

    syncTimeWithSolarSystem();
    statusBar()->showMessage("Открыто окно солнечной системы");
}

void MainWindow::onShowChartsClicked()
{
    if (!m_chartWindow) {
        m_chartWindow = new SimpleChartWindow(dataStorage, this);
    }

    m_chartWindow->show();
    m_chartWindow->raise();
    m_chartWindow->activateWindow();
    statusBar()->showMessage("Открыто окно графиков и аналитики");
}

void MainWindow::onDateTimeChanged(const QDateTime &dateTime)
{
    Q_UNUSED(dateTime);

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
}

void MainWindow::updateCelestialInfluence()
{
    // Передаем влияние в QML карту
    double totalInfluence = solarInfluence * lunarInfluence * planetaryInfluence;
    invokeQMLMethod("setCelestialInfluence", totalInfluence);
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
        }
    }
}

void MainWindow::syncSolarSystemTime(double hour, double days)
{
    Q_UNUSED(hour);
    Q_UNUSED(days);
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

void MainWindow::onExportDataClicked()
{
    QString filename = QFileDialog::getSaveFileName(
        this,
        "Экспорт данных спутников",
        QDir::homePath() + "/satellite_measurements_" +
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".csv",
        "CSV Files (*.csv)"
    );

    if (!filename.isEmpty()) {
        if (dataStorage->exportToCSV(filename)) {
            QMessageBox::information(this, "Успех",
                QString("Данные успешно экспортированы в файл:\n%1").arg(filename));
        } else {
            QMessageBox::warning(this, "Ошибка", "Не удалось экспортировать данные");
        }
    }
}

void MainWindow::showDataStatistics()
{
    QVariantMap stats = dataStorage->getStatistics();

    QString message = QString(
        "Статистика измерений:\n\n"
        "Всего измерений: %1\n"
        "Уникальных спутников: %2\n"
        "Уникальных городов: %3\n"
        "Минимальное излучение: %4 дБм\n"
        "Максимальное излучение: %5 дБм\n"
        "Среднее излучение: %6 дБм\n"
        "Последнее обновление: %7"
    ).arg(stats["totalMeasurements"].toInt())
     .arg(stats["uniqueSatellites"].toInt())
     .arg(stats["uniqueCities"].toInt())
     .arg(stats["minRadiation"].toDouble(), 0, 'f', 1)
     .arg(stats["maxRadiation"].toDouble(), 0, 'f', 1)
     .arg(stats["avgRadiation"].toDouble(), 0, 'f', 1)
     .arg(stats["lastUpdate"].toString());

    QMessageBox::information(this, "Статистика данных", message);
}

void MainWindow::onSatelliteDataAdded(const QString &satelliteName, int count)
{
    statusBar()->showMessage(
        QString("Добавлено измерение от %1 (всего: %2)").arg(satelliteName).arg(count),
        3000
    );
    m_chartWindow;
}

bool MainWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease) {
        QKeyEvent *keyEvent = static_cast<QKeyEvent*>(event);

        // Блокируем левый и правый Ctrl
        if (keyEvent->key() == Qt::Key_Control ||
            keyEvent->key() == Qt::Key_Meta) { // Meta - это Command на Mac
            return true; // Блокируем событие
        }

        // Также блокируем комбинации с Ctrl
        if (keyEvent->modifiers() & Qt::ControlModifier) {
            // Разрешаем только стандартные комбинации
            switch (keyEvent->key()) {
                case Qt::Key_C: // Ctrl+C
                case Qt::Key_V: // Ctrl+V
                case Qt::Key_X: // Ctrl+X
                case Qt::Key_A: // Ctrl+A
                case Qt::Key_Z: // Ctrl+Z
                case Qt::Key_Y: // Ctrl+Y
                case Qt::Key_S: // Ctrl+S
                case Qt::Key_O: // Ctrl+O
                case Qt::Key_P: // Ctrl+P
                case Qt::Key_Q: // Ctrl+Q
                case Qt::Key_W: // Ctrl+W
                case Qt::Key_N: // Ctrl+N
                case Qt::Key_F: // Ctrl+F
                    return QMainWindow::eventFilter(obj, event); // Разрешаем
                default:
                    // Для всех других комбинаций с Ctrl возвращаем true
                    // чтобы они не доходили до QML
                    if (obj == mapWidget || mapWidget->isAncestorOf(qobject_cast<QWidget*>(obj))) {
                        return true;
                    }
            }
        }
    }

    return QMainWindow::eventFilter(obj, event);
}
