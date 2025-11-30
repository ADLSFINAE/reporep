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
#include <QDialog>
#include <QDateTime>
#include <QTimer>

#include <QQuickWidget>
#include <QQmlContext>
#include <QQuickItem>
#include <QDateTime>

class SolarSystemDialog : public QDialog
{
    Q_OBJECT

public:
    explicit SolarSystemDialog(QWidget *parent = nullptr);
    ~SolarSystemDialog();

    void setDateTime(const QDateTime &dateTime);
    void setCurrentTime(double hour, double days);
    QDateTime getDateTime() const;
    double getSolarInfluence() const;
    double getLunarInfluence() const;
    double getPlanetaryInfluence() const;

signals:
    void dateTimeChanged(const QDateTime &dateTime);

private slots:
    void onDateTimeChanged();

private:
    QQuickWidget *solarSystemWidget;
    QDateTime currentDateTime;
};

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

public slots:
    void syncSolarSystemTime(double hour, double days);

private slots:
    void onZoomInClicked();
    void onZoomOutClicked();
    void onFlyToClicked();
    void onAddMarkerClicked();
    void onMapTypeChanged(int index);
    void onZoomSliderChanged(int value);
    void onAnalysisRadiusChanged(int value);
    void onSolarSystemClicked();
    void onDateTimeChanged(const QDateTime &dateTime);
    void syncTimeWithSolarSystem();

    // Новые слоты для управления спутниками
    void onAddSatelliteClicked();
    void onClearSatellitesClicked();
    void onToggleSatellitesClicked();
    void onAddPolarSatelliteClicked();
    void onAddInclinedSatelliteClicked();

    void onMapLoaded();

private:
    void setupUI();
    void setupMap();
    void addMarker(double lat, double lng, const QString &title, double noiseLevel);
    void clearMarkers();
    bool invokeQMLMethod(const QString &method, const QVariant &arg1 = QVariant(),
                        const QVariant &arg2 = QVariant(), const QVariant &arg3 = QVariant());
    void updateCelestialInfluence();
    void updateAllMarkersWithInfluence();

    QQuickWidget *mapWidget;
    SolarSystemDialog *solarSystemDialog;

    // Элементы управления
    QLineEdit *latEdit;
    QLineEdit *lngEdit;
    QLineEdit *zoomEdit;
    QPushButton *flyToButton;
    QPushButton *addMarkerButton;
    QPushButton *clearMarkersButton;
    QPushButton *zoomInButton;
    QPushButton *zoomOutButton;
    QPushButton *solarSystemButton;

    // Новые кнопки для управления спутниками
    QPushButton *addSatelliteButton;
    QPushButton *clearSatellitesButton;
    QPushButton *toggleSatellitesButton;
    QPushButton *addPolarSatelliteButton;
    QPushButton *addInclinedSatelliteButton;

    QSlider *zoomSlider;
    QSlider *radiusSlider;
    QComboBox *mapTypeCombo;

    // Влияние небесных тел
    double solarInfluence;
    double lunarInfluence;
    double planetaryInfluence;

    int markerCounter;
};

#endif // MAINWINDOW_H



