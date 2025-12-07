#include "data_storage.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QFileDialog>
#include <QDir>
#include <QRandomGenerator>

DataStorage::DataStorage(QObject *parent) : QObject(parent) {
    qDebug() << "DataStorage инициализирован";

    // Добавляем тестовые данные при создании
    addTestData();
}

DataStorage::~DataStorage() {
    clearAllData();
}

// Добавление нового спутника
void DataStorage::addSatellite(const QString &satelliteName) {
    if (satelliteName.isEmpty()) {
        qDebug() << "Попытка добавить спутник с пустым именем";
        return;
    }

    if (!measurementsMap.contains(satelliteName)) {
        measurementsMap[satelliteName] = QVector<SatelliteMeasurementData>();
        qDebug() << "Добавлен новый спутник:" << satelliteName;
        emit satelliteAdded(satelliteName);

        // Обновляем статистику
        QVariantMap stats = getStatistics();
        emit statisticsUpdated(stats);
    } else {
        qDebug() << "Спутник" << satelliteName << "уже существует";
    }
}

void DataStorage::addMeasurement(const QString &satelliteName,
                                const QString &dateTime,
                                double latitude,
                                double longitude,
                                double radiationValue,
                                const QString &cityName,
                                double altitude,
                                double distanceToCity,
                                double influenceFactor) {

    // Создаем спутник, если его нет
    if (!measurementsMap.contains(satelliteName)) {
        addSatellite(satelliteName);
    }

    SatelliteMeasurementData data;
    data.measurementTime = QDateTime::fromString(dateTime, Qt::ISODate);
    data.coordinate = qMakePair(latitude, longitude);
    data.radiationValue = radiationValue;
    data.cityName = cityName;
    data.altitude = altitude;
    data.distanceToCity = distanceToCity;
    data.influenceFactor = influenceFactor;

    // Добавляем в map
    measurementsMap[satelliteName].append(data);

    qDebug() << "Добавлено измерение для спутника:" << satelliteName
             << "время:" << dateTime
             << "координаты:" << latitude << longitude
             << "значение:" << radiationValue;

    emit dataAdded(satelliteName, measurementsMap[satelliteName].size());

    for(auto& elem :  measurementsMap.keys()){
        qDebug()<<elem;
    }

    // Обновляем статистику
    QVariantMap stats = getStatistics();
    emit statisticsUpdated(stats);
}

// Добавление измерения с объектом данных
void DataStorage::addMeasurementData(const QString &satelliteName,
                                   const SatelliteMeasurementData &data) {
    // Создаем спутник, если его нет
    if (!measurementsMap.contains(satelliteName)) {
        addSatellite(satelliteName);
    }

    // Добавляем данные
    measurementsMap[satelliteName].append(data);

    qDebug() << "Добавлено измерение (объект) для спутника:" << satelliteName
             << "время:" << data.measurementTime.toString()
             << "значение:" << data.radiationValue;

    emit dataAdded(satelliteName, measurementsMap[satelliteName].size());

    // Обновляем статистику
    QVariantMap stats = getStatistics();
    emit statisticsUpdated(stats);
}

QVariantList DataStorage::getMeasurementsBySatellite(const QString &satelliteName) {
    QVariantList result;

    if (!measurementsMap.contains(satelliteName)) {
        qDebug() << "Нет данных для спутника:" << satelliteName;
        return result;
    }

    const QVector<SatelliteMeasurementData> &dataList = measurementsMap[satelliteName];
    qDebug() << "Получение" << dataList.size() << "измерений для спутника:" << satelliteName;

    for (const auto &data : dataList) {
        QVariantMap item;
        item["satellite"] = satelliteName;
        item["time"] = data.measurementTime.toString("yyyy-MM-dd HH:mm:ss");
        item["latitude"] = data.coordinate.first;
        item["longitude"] = data.coordinate.second;
        item["radiation"] = data.radiationValue;
        item["city"] = data.cityName;
        item["altitude"] = data.altitude;
        item["distance"] = data.distanceToCity;
        item["influence"] = data.influenceFactor;

        result.append(item);
    }

    return result;
}

QVariantList DataStorage::getAllMeasurements() {
    QVariantList result;
    int totalCount = 0;

    for (auto it = measurementsMap.begin(); it != measurementsMap.end(); ++it) {
        const QString &satelliteName = it.key();
        const QVector<SatelliteMeasurementData> &dataList = it.value();
        totalCount += dataList.size();

        for (const auto &data : dataList) {
            QVariantMap item;
            item["satellite"] = satelliteName;
            item["time"] = data.measurementTime.toString("yyyy-MM-dd HH:mm:ss");
            item["latitude"] = data.coordinate.first;
            item["longitude"] = data.coordinate.second;
            item["radiation"] = data.radiationValue;
            item["city"] = data.cityName;
            item["altitude"] = data.altitude;
            item["distance"] = data.distanceToCity;
            item["influence"] = data.influenceFactor;

            result.append(item);
        }
    }

    qDebug() << "Всего измерений в хранилище:" << totalCount;
    return result;
}

void DataStorage::clearSatelliteData(const QString &satelliteName) {
    if (measurementsMap.contains(satelliteName)) {
        int removedCount = measurementsMap[satelliteName].size();
        measurementsMap[satelliteName].clear();
        measurementsMap.remove(satelliteName);
        qDebug() << "Данные спутника" << satelliteName << "очищены. Удалено записей:" << removedCount;
        emit dataCleared();
    }
}

void DataStorage::clearAllData() {
    int totalRemoved = 0;
    for (auto it = measurementsMap.begin(); it != measurementsMap.end(); ++it) {
        totalRemoved += it.value().size();
    }

    measurementsMap.clear();
    qDebug() << "Все данные измерений очищены. Удалено записей:" << totalRemoved;
    emit dataCleared();
}

QVariantMap DataStorage::getStatistics() {
    QVariantMap stats;
    int totalMeasurements = 0;
    int uniqueSatellites = measurementsMap.size();
    double minRadiation = 1000;
    double maxRadiation = -1000;
    double sumRadiation = 0;
    QSet<QString> uniqueCities;

    for (const auto &dataList : measurementsMap) {
        totalMeasurements += dataList.size();

        for (const auto &data : dataList) {
            double radiation = data.radiationValue;
            sumRadiation += radiation;

            if (radiation < minRadiation) minRadiation = radiation;
            if (radiation > maxRadiation) maxRadiation = radiation;

            if (!data.cityName.isEmpty() && data.cityName != "Открытая местность") {
                uniqueCities.insert(data.cityName);
            }
        }
    }

    // Если нет данных, устанавливаем значения по умолчанию
    if (totalMeasurements == 0) {
        minRadiation = 0;
        maxRadiation = 0;
    }

    stats["totalMeasurements"] = totalMeasurements;
    stats["uniqueSatellites"] = uniqueSatellites;
    stats["uniqueCities"] = uniqueCities.size();
    stats["minRadiation"] = minRadiation;
    stats["maxRadiation"] = maxRadiation;
    stats["avgRadiation"] = totalMeasurements > 0 ? sumRadiation / totalMeasurements : 0;
    stats["lastUpdate"] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");

    return stats;
}

bool DataStorage::exportToCSV(const QString &filename) {
    QString actualFilename = filename;
    if (actualFilename.isEmpty()) {
        actualFilename = QDir::homePath() + "/satellite_measurements_" +
                         QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".csv";
    }

    QFile file(actualFilename);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Не удалось открыть файл для записи:" << actualFilename;
        return false;
    }

    QTextStream stream(&file);
    stream.setCodec("UTF-8");

    // Заголовок с BOM для правильного отображения в Excel
    stream << "\xEF\xBB\xBF";
    stream << "Спутник;Время;Широта;Долгота;Уровень излучения (дБм);Город;Высота (км);Расстояние до города (м);Фактор влияния\n";

    int exportedCount = 0;
    // Данные
    for (auto it = measurementsMap.begin(); it != measurementsMap.end(); ++it) {
        const QString &satelliteName = it.key();
        const QVector<SatelliteMeasurementData> &dataList = it.value();

        for (const auto &data : dataList) {
            stream << satelliteName << ";"
                   << data.measurementTime.toString("yyyy-MM-dd HH:mm:ss") << ";"
                   << QString::number(data.coordinate.first, 'f', 6) << ";"
                   << QString::number(data.coordinate.second, 'f', 6) << ";"
                   << QString::number(data.radiationValue, 'f', 1) << ";"
                   << data.cityName << ";"
                   << QString::number(data.altitude, 'f', 1) << ";"
                   << QString::number(data.distanceToCity, 'f', 1) << ";"
                   << QString::number(data.influenceFactor, 'f', 3) << "\n";
            exportedCount++;
        }
    }

    file.close();
    qDebug() << "Экспортировано" << exportedCount << "записей в" << actualFilename;
    return true;
}

int DataStorage::getMeasurementCount(const QString &satelliteName) {
    if (measurementsMap.contains(satelliteName)) {
        return measurementsMap[satelliteName].size();
    }
    return 0;
}

QStringList DataStorage::getAllSatelliteNames() {
    QStringList names = measurementsMap.keys();
    qDebug() << "Получение списка спутников. Всего:" << names.size();
    for (const QString &name : names) {
        qDebug() << "  -" << name << ":" << getMeasurementCount(name) << "измерений";
    }
    return names;
}

bool DataStorage::satelliteExists(const QString &satelliteName) {
    return measurementsMap.contains(satelliteName);
}

QVector<SatelliteMeasurementData> DataStorage::getSatelliteData(const QString &satelliteName) {
    if (measurementsMap.contains(satelliteName)) {
        return measurementsMap[satelliteName];
    }
    return QVector<SatelliteMeasurementData>();
}

void DataStorage::addTestData() {
    qDebug() << "=== ДОБАВЛЕНИЕ ТЕСТОВЫХ ДАННЫХ ===";

    // Создаем тестовые спутники
    QStringList satelliteNames = {
        "Спутник-1",
        "Спутник-2",
        "Спутник-3",
        "ГЛОНАСС-M",
        "GPS-III",
        "Galileo",
        "Байду",
        "Метеор-М"
    };

    QDateTime startTime = QDateTime::currentDateTime().addDays(-30);

    for (const QString &satelliteName : satelliteNames) {
        // Добавляем спутник
        addSatellite(satelliteName);

        // Добавляем тестовые измерения для каждого спутника
        int measurementsCount = 20 + QRandomGenerator::global()->bounded(30);

        for (int i = 0; i < measurementsCount; i++) {
            QDateTime measurementTime = startTime.addSecs(i * 3600 * 6); // Каждые 6 часов

            // Генерация случайных координат
            double latitude = 45.0 + (QRandomGenerator::global()->generateDouble() - 0.5) * 20;
            double longitude = 40.0 + (QRandomGenerator::global()->generateDouble() - 0.5) * 40;

            // Генерация уровня излучения
            double radiation = -80 - QRandomGenerator::global()->generateDouble() * 20;

            // Случайный город
            QStringList cities = {"Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург",
                                 "Казань", "Нижний Новгород", "Челябинск", "Омск", "Самара",
                                 "Открытая местность"};
            QString city = cities[QRandomGenerator::global()->bounded(cities.size())];

            // Создаем данные измерения
            SatelliteMeasurementData data(
                measurementTime,
                latitude,
                longitude,
                radiation,
                city,
                500 + QRandomGenerator::global()->bounded(500), // высота 500-1000 км
                city == "Открытая местность" ? 0 : 1000 + QRandomGenerator::global()->bounded(9000), // расстояние 1-10 км
                0.8 + QRandomGenerator::global()->generateDouble() * 0.4 // фактор влияния 0.8-1.2
            );

            // Добавляем измерение
            addMeasurementData(satelliteName, data);
        }

        qDebug() << "Добавлен спутник" << satelliteName << "с" << measurementsCount << "измерениями";
    }

    qDebug() << "=== ТЕСТОВЫЕ ДАННЫЕ ДОБАВЛЕНЫ ===";
    qDebug() << "Всего спутников:" << measurementsMap.size();
    qDebug() << "Всего измерений:" << getTotalMeasurementCount();

    emit testDataAdded();
}

int DataStorage::getTotalMeasurementCount() {
    int total = 0;
    for (auto it = measurementsMap.begin(); it != measurementsMap.end(); ++it) {
        total += it.value().size();
    }
    return total;
}
