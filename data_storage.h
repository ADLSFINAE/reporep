#ifndef DATA_STORAGE_H
#define DATA_STORAGE_H

#include <QObject>
#include <QMap>
#include <QVector>
#include <QString>
#include <QPair>
#include <QDateTime>
#include <QVariant>
#include <QVariantMap>
#include <QVariantList>
#include <QDebug>

struct SatelliteMeasurementData {
    QDateTime measurementTime;
    QPair<double, double> coordinate; // широта, долгота
    double radiationValue; // уровень излучения в дБм
    QString cityName;
    double altitude; // высота в км
    double distanceToCity; // расстояние до города в метрах
    double influenceFactor; // фактор влияния

    SatelliteMeasurementData()
        : radiationValue(0), altitude(0), distanceToCity(0), influenceFactor(1.0) {}
};

class DataStorage : public QObject {
    Q_OBJECT

public:
    explicit DataStorage(QObject *parent = nullptr);
    ~DataStorage();

    // Добавление данных измерения
    Q_INVOKABLE void addMeasurement(const QString &satelliteName,
                                   const QString &dateTime,
                                   double latitude,
                                   double longitude,
                                   double radiationValue,
                                   const QString &cityName = "",
                                   double altitude = 0,
                                   double distanceToCity = 0,
                                   double influenceFactor = 1.0);

    // Получение всех измерений по спутнику
    Q_INVOKABLE QVariantList getMeasurementsBySatellite(const QString &satelliteName);

    // Получение всех данных
    Q_INVOKABLE QVariantList getAllMeasurements();

    // Очистка данных по спутнику
    Q_INVOKABLE void clearSatelliteData(const QString &satelliteName);

    // Очистка всех данных
    Q_INVOKABLE void clearAllData();

    // Получение статистики
    Q_INVOKABLE QVariantMap getStatistics();

    // Экспорт в CSV
    Q_INVOKABLE bool exportToCSV(const QString &filename);

    // Получение количества измерений по спутнику
    Q_INVOKABLE int getMeasurementCount(const QString &satelliteName);

    // Получение списка всех спутников
    Q_INVOKABLE QStringList getAllSatelliteNames();

    // В публичную секцию класса DataStorage добавьте:
    public:
        Q_INVOKABLE void testConnection() {
            qDebug() << "✅ DataStorage тест соединения: Работает! Доступно записей:" << measurementsMap.size();
        }

        Q_INVOKABLE int getTotalMeasurementCount();

signals:
    void dataAdded(const QString &satelliteName, int totalCount);
    void dataCleared();
    void statisticsUpdated(const QVariantMap &stats);

private:
    QMap<QString, QVector<SatelliteMeasurementData>> measurementsMap;
};

#endif // DATA_STORAGE_H
