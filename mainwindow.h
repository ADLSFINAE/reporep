#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLineEdit>
#include <QLabel>
#include <QSlider>
#include <QComboBox>
#include <QStatusBar>
#include <QMessageBox>
#include <QGroupBox>
#include <QSpinBox>
#include <QTimer>

#include <QQuickWidget>
#include <QQmlContext>

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onZoomInClicked();
    void onZoomOutClicked();
    void onFlyToClicked();
    void onAddMeasurementZoneClicked();
    void onMapTypeChanged(int index);
    void onZoomSliderChanged(int value);
    void onRadiusChanged(int value);
    void onStartMonitoringClicked();
    void onStopMonitoringClicked();
    void onClearClicked();

    void onMapLoaded();

private:
    void setupUI();
    void setupMap();
    void addMeasurementZone(double lat, double lng, double radiusKm);
    void updateRadiationVisualization(double lat, double lng, double noiseLevel70cm, double noiseLevel2m);
    void simulateDataCollection();
    void clearVisualizations();
    void callQMLFunction(const QString &function, const QVariant &arg1 = QVariant(),
                        const QVariant &arg2 = QVariant(), const QVariant &arg3 = QVariant());

    QQuickWidget *mapWidget;

    // Элементы управления
    QLineEdit *latEdit;
    QLineEdit *lngEdit;
    QLineEdit *zoomEdit;
    QSpinBox *radiusSpinBox;
    QPushButton *flyToButton;
    QPushButton *addZoneButton;
    QPushButton *startMonitoringButton;
    QPushButton *stopMonitoringButton;
    QPushButton *clearButton;
    QPushButton *zoomInButton;
    QPushButton *zoomOutButton;
    QSlider *zoomSlider;
    QComboBox *mapTypeCombo;

    // Данные мониторинга
    QTimer *monitoringTimer;
    int measurementCounter;
    bool isMonitoring;

    // Отображение данных
    QLabel *statusLabel;
    QLabel *measurement70cmLabel;
    QLabel *measurement2mLabel;
};

#endif // MAINWINDOW_H
