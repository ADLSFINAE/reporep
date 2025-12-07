#ifndef SIMPLECHARTWINDOW_H
#define SIMPLECHARTWINDOW_H

#include <QMainWindow>
#include <QWidget>
#include <QPainter>
#include <QVector>
#include <QListWidget>
#include <QTableWidget>
#include <QScrollArea>
#include <QBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QSplitter>
#include <QFileDialog>
#include <QMessageBox>
#include <QDateTime>
#include <algorithm>
#include <numeric>

#include "data_storage.h"

class SimpleChartWidget : public QWidget
{
    Q_OBJECT
public:
    explicit SimpleChartWidget(QWidget *parent = nullptr);

    void setData(const QVector<QDateTime> &times, const QVector<double> &values);
    void setTitle(const QString &title);
    void clearData();

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    QVector<QDateTime> m_times;
    QVector<double> m_values;
    QString m_title;

    void drawChart(QPainter &painter);
    void drawGrid(QPainter &painter, const QRect &chartRect);
    void drawLine(QPainter &painter, const QRect &chartRect);
    void drawPoints(QPainter &painter, const QRect &chartRect);
    void drawAxes(QPainter &painter, const QRect &chartRect);
    void drawTitle(QPainter &painter);

    double findMinValue() const;
    double findMaxValue() const;
};

class SimpleChartWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit SimpleChartWindow(DataStorage *dataStorage, QWidget *parent = nullptr);
    ~SimpleChartWindow();

private slots:
    void onSatelliteSelected(QListWidgetItem *item);
    void onExportDataClicked();
    void onExportImageClicked();
    void dataAdded(const QString &satelliteName, int totalCount);

private:
    void setupUI();
    void loadSatelliteList();
    void updateChart(const QString &satelliteName);
    void updateStatistics(const QString &satelliteName);

private:
    DataStorage *m_dataStorage;
    QListWidget *m_satelliteList;
    SimpleChartWidget *m_chartWidget;
    QTableWidget *m_statsTable;

    // Статистика
    struct Statistics {
        int count;
        double min;
        double max;
        double mean;
        double median;
        QDateTime firstMeasurement;
        QDateTime lastMeasurement;
    };

    Statistics m_currentStats;
};

#endif // SIMPLECHARTWINDOW_H
