#include "QmlBridge.h"
#include <QDebug>

QmlBridge::QmlBridge(QObject *parent) : QObject(parent)
{
    qDebug() << "QmlBridge создан";
}

void QmlBridge::setDataStorage(DataStorage* storage)
{
    if (m_dataStorage != storage) {
        m_dataStorage = storage;
        qDebug() << "QmlBridge: DataStorage установлен" << (storage ? "✅" : "❌ null");
        emit dataStorageChanged();
    }
}

QString QmlBridge::getStorageStatus() const
{
    if (!m_dataStorage) {
        return "❌ DataStorage не установлен";
    }
    return QString("✅ DataStorage доступен. Записей: %1")
           .arg(m_dataStorage->getAllMeasurements().size());
}
