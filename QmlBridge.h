#ifndef QMLBRIDGE_H
#define QMLBRIDGE_H

#include <QObject>
#include "data_storage.h"

class QmlBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(DataStorage* dataStorage READ dataStorage WRITE setDataStorage NOTIFY dataStorageChanged)

public:
    explicit QmlBridge(QObject *parent = nullptr);

    DataStorage* dataStorage() const { return m_dataStorage; }
    void setDataStorage(DataStorage* storage);

    // Метод для проверки доступности
    Q_INVOKABLE bool isDataStorageAvailable() const { return m_dataStorage != nullptr; }
    Q_INVOKABLE QString getStorageStatus() const;

signals:
    void dataStorageChanged();

private:
    DataStorage* m_dataStorage = nullptr;
};

#endif // QMLBRIDGE_H
