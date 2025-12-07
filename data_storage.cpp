#include "data_storage.h"
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QFileDialog>
#include <QDir>

DataStorage::DataStorage(QObject *parent) : QObject(parent) {
    qDebug() << "DataStorage инициализирован";
}

DataStorage::~DataStorage() {
    clearAllData();
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

    qDebug()<<"DDDDDDDDDDDDDDDDDDDDD";
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
    double minRadiation = 0;
    double maxRadiation = -200;
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
    return measurementsMap.keys();
}

int DataStorage::getTotalMeasurementCount() {
    int total = 0;
    for (auto it = measurementsMap.begin(); it != measurementsMap.end(); ++it) {
        total += it.value().size();
    }
    return total;
}
