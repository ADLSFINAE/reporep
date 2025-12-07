#include "simplechartwindow.h"
#include <QDebug>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QPushButton>
#include <QDir>

// ================= SimpleChartWidget =================

SimpleChartWidget::SimpleChartWidget(QWidget *parent)
    : QWidget(parent)
{
    setMinimumSize(600, 400);
}

void SimpleChartWidget::setData(const QVector<QDateTime> &times, const QVector<double> &values)
{
    m_times = times;
    m_values = values;
    update();
}

void SimpleChartWidget::setTitle(const QString &title)
{
    m_title = title;
    update();
}

void SimpleChartWidget::clearData()
{
    m_times.clear();
    m_values.clear();
    update();
}

double SimpleChartWidget::findMinValue() const
{
    if (m_values.isEmpty()) return 0.0;
    return *std::min_element(m_values.begin(), m_values.end());
}

double SimpleChartWidget::findMaxValue() const
{
    if (m_values.isEmpty()) return 0.0;
    return *std::max_element(m_values.begin(), m_values.end());
}

void SimpleChartWidget::paintEvent(QPaintEvent *event)
{
    Q_UNUSED(event);

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);

    // Задний фон
    painter.fillRect(rect(), QColor(255, 255, 255));

    if (m_times.isEmpty() || m_values.isEmpty()) {
        painter.setPen(QColor(100, 100, 100));
        painter.setFont(QFont("Arial", 14));
        painter.drawText(rect(), Qt::AlignCenter, "Нет данных для отображения");
        return;
    }

    drawTitle(painter);
    drawChart(painter);
}

void SimpleChartWidget::drawTitle(QPainter &painter)
{
    if (m_title.isEmpty()) return;

    painter.setPen(QColor(0, 0, 0));
    painter.setFont(QFont("Arial", 14, QFont::Bold));

    QRect titleRect(0, 10, width(), 30);
    painter.drawText(titleRect, Qt::AlignCenter, m_title);
}

void SimpleChartWidget::drawChart(QPainter &painter)
{
    QRect chartRect = rect().adjusted(80, 50, -40, -80);

    drawGrid(painter, chartRect);
    drawLine(painter, chartRect);
    drawPoints(painter, chartRect);
    drawAxes(painter, chartRect);
}

void SimpleChartWidget::drawGrid(QPainter &painter, const QRect &chartRect)
{
    painter.setPen(QPen(QColor(230, 230, 230), 1));

    // Вертикальные линии
    int xSteps = 10;
    for (int i = 0; i <= xSteps; i++) {
        int x = chartRect.left() + (chartRect.width() * i) / xSteps;
        painter.drawLine(x, chartRect.top(), x, chartRect.bottom());
    }

    // Горизонтальные линии
    int ySteps = 8;
    for (int i = 0; i <= ySteps; i++) {
        int y = chartRect.top() + (chartRect.height() * i) / ySteps;
        painter.drawLine(chartRect.left(), y, chartRect.right(), y);
    }
}

void SimpleChartWidget::drawLine(QPainter &painter, const QRect &chartRect)
{
    if (m_times.size() < 2) return;

    double minValue = findMinValue();
    double maxValue = findMaxValue();
    double valueRange = maxValue - minValue;
    if (valueRange == 0) valueRange = 1;

    // Подготавливаем перо для линии
    QPen linePen(QColor(0, 120, 215), 2);
    painter.setPen(linePen);

    // Рисуем линию
    qint64 minTime = m_times.first().toMSecsSinceEpoch();
    qint64 maxTime = m_times.last().toMSecsSinceEpoch();
    qint64 timeRange = maxTime - minTime;
    if (timeRange == 0) timeRange = 1;

    for (int i = 0; i < m_times.size() - 1; i++) {
        int x1 = chartRect.left() + chartRect.width() *
                 (m_times[i].toMSecsSinceEpoch() - minTime) / timeRange;
        int x2 = chartRect.left() + chartRect.width() *
                 (m_times[i+1].toMSecsSinceEpoch() - minTime) / timeRange;

        // Нормализуем Y (значения) - инвертируем ось Y (большие значения внизу)
        int y1 = chartRect.bottom() - chartRect.height() *
                 (m_values[i] - minValue) / valueRange;
        int y2 = chartRect.bottom() - chartRect.height() *
                 (m_values[i+1] - minValue) / valueRange;

        painter.drawLine(x1, y1, x2, y2);
    }
}

void SimpleChartWidget::drawPoints(QPainter &painter, const QRect &chartRect)
{
    if (m_times.isEmpty()) return;

    double minValue = findMinValue();
    double maxValue = findMaxValue();
    double valueRange = maxValue - minValue;
    if (valueRange == 0) valueRange = 1;

    qint64 minTime = m_times.first().toMSecsSinceEpoch();
    qint64 maxTime = m_times.last().toMSecsSinceEpoch();
    qint64 timeRange = maxTime - minTime;
    if (timeRange == 0) timeRange = 1;

    painter.setBrush(QColor(255, 50, 50));
    painter.setPen(QPen(QColor(200, 0, 0), 1));

    for (int i = 0; i < m_times.size(); i++) {
        int x = chartRect.left() + chartRect.width() *
                (m_times[i].toMSecsSinceEpoch() - minTime) / timeRange;
        int y = chartRect.bottom() - chartRect.height() *
                (m_values[i] - minValue) / valueRange;

        // Рисуем точку с обводкой
        painter.drawEllipse(QPoint(x, y), 5, 5);

        // Подписи значений для некоторых точек (каждой 5-й)
        if (i % 5 == 0) {
            painter.save();
            painter.setPen(QColor(0, 0, 0));
            painter.setFont(QFont("Arial", 8));

            QString valueText = QString::number(m_values[i], 'f', 1);
            QRect textRect(x - 25, y - 25, 50, 20);
            painter.drawText(textRect, Qt::AlignCenter, valueText);
            painter.restore();
        }
    }
}

void SimpleChartWidget::drawAxes(QPainter &painter, const QRect &chartRect)
{
    painter.setPen(QPen(Qt::black, 2));

    // Ось X
    painter.drawLine(chartRect.left(), chartRect.bottom(),
                     chartRect.right(), chartRect.bottom());

    // Ось Y
    painter.drawLine(chartRect.left(), chartRect.top(),
                     chartRect.left(), chartRect.bottom());

    // Подписи оси Y
    painter.setPen(QColor(100, 100, 100));
    painter.setFont(QFont("Arial", 9));

    double minValue = findMinValue();
    double maxValue = findMaxValue();
    double valueRange = maxValue - minValue;

    // Рисуем 5 делений на оси Y
    for (int i = 0; i <= 5; i++) {
        double value = minValue + (maxValue - minValue) * i / 5;
        int y = chartRect.bottom() - chartRect.height() * i / 5;

        // Горизонтальная черточка на оси
        painter.setPen(QPen(Qt::black, 1));
        painter.drawLine(chartRect.left() - 5, y, chartRect.left(), y);

        // Подпись значения
        painter.setPen(QColor(100, 100, 100));
        QString label = QString::number(value, 'f', 1);
        QRect labelRect(chartRect.left() - 75, y - 10, 65, 20);
        painter.drawText(labelRect, Qt::AlignRight | Qt::AlignVCenter, label);
    }

    // Название оси Y
    painter.save();
    painter.translate(30, chartRect.top() + chartRect.height() / 2);
    painter.rotate(-90);
    painter.setPen(QColor(0, 0, 0));
    painter.setFont(QFont("Arial", 10, QFont::Bold));
    painter.drawText(QRect(-200, 0, 400, 20), Qt::AlignCenter, "Уровень излучения (дБм)");
    painter.restore();

    // Подписи оси X (время)
    if (!m_times.isEmpty()) {
        // Рисуем 5 делений на оси X
        for (int i = 0; i <= 5; i++) {
            int idx = m_times.size() * i / 5;
            if (idx >= m_times.size()) idx = m_times.size() - 1;

            qint64 minTime = m_times.first().toMSecsSinceEpoch();
            qint64 maxTime = m_times.last().toMSecsSinceEpoch();
            qint64 timeRange = maxTime - minTime;

            int x = chartRect.left() + chartRect.width() *
                    (m_times[idx].toMSecsSinceEpoch() - minTime) / timeRange;

            // Вертикальная черточка на оси
            painter.setPen(QPen(Qt::black, 1));
            painter.drawLine(x, chartRect.bottom(), x, chartRect.bottom() + 5);

            // Подпись времени
            painter.setPen(QColor(100, 100, 100));
            QString label = m_times[idx].toString("dd.MM.yy\nHH:mm");
            QRect labelRect(x - 40, chartRect.bottom() + 10, 80, 40);
            painter.drawText(labelRect, Qt::AlignCenter, label);
        }

        // Название оси X
        painter.setPen(QColor(0, 0, 0));
        painter.setFont(QFont("Arial", 10, QFont::Bold));
        painter.drawText(QRect(chartRect.left(), chartRect.bottom() + 60,
                              chartRect.width(), 20),
                        Qt::AlignCenter, "Время");
    }
}

// ================= SimpleChartWindow =================

SimpleChartWindow::SimpleChartWindow(DataStorage *dataStorage, QWidget *parent)
    : QMainWindow(parent)
    , m_dataStorage(dataStorage)
    , m_chartWidget(nullptr)
{
    setWindowTitle("Аналитика измерений спутников");
    setMinimumSize(1000, 700);
    resize(1200, 800);

    setupUI();
    loadSatelliteList();
}

SimpleChartWindow::~SimpleChartWindow()
{
}

void SimpleChartWindow::setupUI()
{
    QWidget *centralWidget = new QWidget(this);
    setCentralWidget(centralWidget);

    QVBoxLayout *mainLayout = new QVBoxLayout(centralWidget);

    // Панель управления
    QHBoxLayout *controlLayout = new QHBoxLayout();

    QLabel *titleLabel = new QLabel("Выберите спутник для анализа:", this);

    QPushButton *exportImageBtn = new QPushButton("Экспорт графика", this);
    QPushButton *exportDataBtn = new QPushButton("Экспорт данных", this);

    connect(exportImageBtn, &QPushButton::clicked, this, &SimpleChartWindow::onExportImageClicked);
    connect(exportDataBtn, &QPushButton::clicked, this, &SimpleChartWindow::onExportDataClicked);
    connect(m_dataStorage, &DataStorage::dataAdded, this, &SimpleChartWindow::dataAdded);

    controlLayout->addWidget(titleLabel);
    controlLayout->addStretch();
    controlLayout->addWidget(exportImageBtn);
    controlLayout->addWidget(exportDataBtn);

    mainLayout->addLayout(controlLayout);

    // Основной разделитель
    QSplitter *mainSplitter = new QSplitter(Qt::Horizontal, this);

    // Левая панель - список спутников
    QWidget *leftPanel = new QWidget(this);
    QVBoxLayout *leftLayout = new QVBoxLayout(leftPanel);

    m_satelliteList = new QListWidget(this);
    m_satelliteList->setMaximumWidth(250);
    connect(m_satelliteList, &QListWidget::itemClicked,
            this, &SimpleChartWindow::onSatelliteSelected);

    leftLayout->addWidget(new QLabel("Список спутников:", this));
    leftLayout->addWidget(m_satelliteList);

    // Правая панель - график и статистика
    QWidget *rightPanel = new QWidget(this);
    QVBoxLayout *rightLayout = new QVBoxLayout(rightPanel);

    m_chartWidget = new SimpleChartWidget(this);
    rightLayout->addWidget(new QLabel("График зависимости излучения от времени:", this));
    rightLayout->addWidget(m_chartWidget);

    // Таблица статистики
    m_statsTable = new QTableWidget(this);
    m_statsTable->setRowCount(8);
    m_statsTable->setColumnCount(2);
    m_statsTable->setHorizontalHeaderLabels({"Параметр", "Значение"});
    m_statsTable->horizontalHeader()->setStretchLastSection(true);
    m_statsTable->verticalHeader()->setVisible(false);
    m_statsTable->setMaximumHeight(200);

    rightLayout->addWidget(new QLabel("Статистика измерений:", this));
    rightLayout->addWidget(m_statsTable);

    // Добавляем панели в разделитель
    mainSplitter->addWidget(leftPanel);
    mainSplitter->addWidget(rightPanel);
    mainSplitter->setSizes({250, 950});

    mainLayout->addWidget(mainSplitter);
}

void SimpleChartWindow::loadSatelliteList()
{
    if (!m_dataStorage) {
        qDebug() << "DataStorage не доступен";
        return;
    }

    QStringList satellites = m_dataStorage->getAllSatelliteNames();
    m_satelliteList->clear();

    qDebug() << "Загружаются спутники:" << satellites;

    foreach (const QString &satellite, satellites) {
        int count = m_dataStorage->getMeasurementCount(satellite);
        QListWidgetItem *item = new QListWidgetItem(
            QString("%1 (%2 измерений)").arg(satellite).arg(count)
        );
        item->setData(Qt::UserRole, satellite);
        m_satelliteList->addItem(item);
    }
}

void SimpleChartWindow::onSatelliteSelected(QListWidgetItem *item)
{
    if (!item) return;

    QString satelliteName = item->data(Qt::UserRole).toString();

    if (satelliteName.isEmpty()) {
        qDebug() << "Пустое имя спутника";
        return;
    }

    qDebug() << "Выбран спутник:" << satelliteName;

    updateChart(satelliteName);
    updateStatistics(satelliteName);
}

void SimpleChartWindow::updateChart(const QString &satelliteName)
{
    if (!m_dataStorage) {
        qDebug() << "DataStorage не доступен";
        return;
    }

    QVariantList measurements = m_dataStorage->getMeasurementsBySatellite(satelliteName);
    qDebug() << "Получено измерений для" << satelliteName << ":" << measurements.size();

    if (measurements.isEmpty()) {
        m_chartWidget->setTitle("Нет данных для отображения");
        m_chartWidget->clearData();
        return;
    }

    QVector<QDateTime> times;
    QVector<double> values;

    foreach (const QVariant &item, measurements) {
        QVariantMap map = item.toMap();
        times.append(QDateTime::fromString(map["time"].toString(), "yyyy-MM-dd HH:mm:ss"));
        values.append(map["radiation"].toDouble());
    }

    // Сортируем по времени
    QVector<int> indices(times.size());
    std::iota(indices.begin(), indices.end(), 0);
    std::sort(indices.begin(), indices.end(),
              [&times](int a, int b) { return times[a] < times[b]; });

    QVector<QDateTime> sortedTimes;
    QVector<double> sortedValues;

    for (int idx : indices) {
        sortedTimes.append(times[idx]);
        sortedValues.append(values[idx]);
    }

    m_chartWidget->setTitle(QString("Спутник: %1").arg(satelliteName));
    m_chartWidget->setData(sortedTimes, sortedValues);
}

void SimpleChartWindow::updateStatistics(const QString &satelliteName)
{
    if (!m_dataStorage) {
        return;
    }

    QVariantList measurements = m_dataStorage->getMeasurementsBySatellite(satelliteName);

    if (measurements.isEmpty()) {
        m_statsTable->clearContents();
        return;
    }

    // Собираем статистику
    QVector<double> values;
    QDateTime firstTime, lastTime;

    foreach (const QVariant &item, measurements) {
        QVariantMap map = item.toMap();
        double value = map["radiation"].toDouble();
        QDateTime time = QDateTime::fromString(map["time"].toString(), "yyyy-MM-dd HH:mm:ss");

        values.append(value);

        if (firstTime.isNull() || time < firstTime) firstTime = time;
        if (lastTime.isNull() || time > lastTime) lastTime = time;
    }

    // Вычисляем статистику
    m_currentStats.count = values.size();
    m_currentStats.min = *std::min_element(values.begin(), values.end());
    m_currentStats.max = *std::max_element(values.begin(), values.end());

    double sum = std::accumulate(values.begin(), values.end(), 0.0);
    m_currentStats.mean = sum / values.size();

    // Медиана
    std::sort(values.begin(), values.end());
    if (values.size() % 2 == 0) {
        m_currentStats.median = (values[values.size()/2 - 1] + values[values.size()/2]) / 2.0;
    } else {
        m_currentStats.median = values[values.size()/2];
    }

    m_currentStats.firstMeasurement = firstTime;
    m_currentStats.lastMeasurement = lastTime;

    // Обновляем таблицу
    m_statsTable->clearContents();

    QStringList statsData = {
        QString("Количество измерений: %1").arg(m_currentStats.count),
        QString("Временной диапазон: %1 - %2")
            .arg(m_currentStats.firstMeasurement.toString("dd.MM.yyyy HH:mm"))
            .arg(m_currentStats.lastMeasurement.toString("dd.MM.yyyy HH:mm")),
        QString("Минимальное значение: %1 дБм").arg(m_currentStats.min, 0, 'f', 1),
        QString("Максимальное значение: %1 дБм").arg(m_currentStats.max, 0, 'f', 1),
        QString("Среднее значение: %1 дБм").arg(m_currentStats.mean, 0, 'f', 1),
        QString("Медиана: %1 дБм").arg(m_currentStats.median, 0, 'f', 1),
        QString("Размах значений: %1 дБм").arg(m_currentStats.max - m_currentStats.min, 0, 'f', 1),
        QString("Всего дней измерений: %1").arg(m_currentStats.firstMeasurement.daysTo(m_currentStats.lastMeasurement))
    };

    for (int i = 0; i < statsData.size() && i < m_statsTable->rowCount(); ++i) {
        QStringList parts = statsData[i].split(": ");
        m_statsTable->setItem(i, 0, new QTableWidgetItem(parts[0] + ":"));
        if (parts.size() > 1) {
            m_statsTable->setItem(i, 1, new QTableWidgetItem(parts[1]));
        }
    }
}

void SimpleChartWindow::onExportImageClicked()
{
    QString fileName = QFileDialog::getSaveFileName(
        this,
        "Экспорт графика",
        QDir::homePath() + "/chart_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"),
        "PNG Images (*.png);;JPEG Images (*.jpg);;BMP Images (*.bmp)"
    );

    if (!fileName.isEmpty()) {
        QPixmap pixmap(m_chartWidget->size());
        m_chartWidget->render(&pixmap);

        if (pixmap.save(fileName)) {
            QMessageBox::information(this, "Успех",
                QString("График успешно экспортирован в файл:\n%1").arg(fileName));
        } else {
            QMessageBox::warning(this, "Ошибка", "Не удалось сохранить изображение");
        }
    }
}

void SimpleChartWindow::dataAdded(const QString &satelliteName, int totalCount)
{
    loadSatelliteList();
}

void SimpleChartWindow::onExportDataClicked()
{
    if (!m_dataStorage) {
        QMessageBox::warning(this, "Ошибка", "DataStorage не доступен");
        return;
    }

    QString fileName = QFileDialog::getSaveFileName(
        this,
        "Экспорт данных",
        QDir::homePath() + "/satellite_data_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"),
        "CSV Files (*.csv)"
    );

    if (!fileName.isEmpty()) {
        if (m_dataStorage->exportToCSV(fileName)) {
            QMessageBox::information(this, "Успех",
                QString("Данные успешно экспортированы в файл:\n%1").arg(fileName));
        } else {
            QMessageBox::warning(this, "Ошибка", "Не удалось экспортировать данные");
        }
    }
}
