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

#include <QQuickWidget>
#include <QQmlContext>
#include <QQuickItem>

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
    void onAddMarkerClicked();
    void onMapTypeChanged(int index);
    void onZoomSliderChanged(int value);
    void onAnalysisRadiusChanged(int value);

    void onMapLoaded();

private:
    void setupUI();
    void setupMap();
    void addMarker(double lat, double lng, const QString &title, double noiseLevel);
    void clearMarkers();
    bool invokeQMLMethod(const QString &method, const QVariant &arg1 = QVariant(),
                        const QVariant &arg2 = QVariant(), const QVariant &arg3 = QVariant());

    QQuickWidget *mapWidget;

    // Элементы управления
    QLineEdit *latEdit;
    QLineEdit *lngEdit;
    QLineEdit *zoomEdit;
    QPushButton *flyToButton;
    QPushButton *addMarkerButton;
    QPushButton *clearMarkersButton;
    QPushButton *zoomInButton;
    QPushButton *zoomOutButton;
    QSlider *zoomSlider;
    QSlider *radiusSlider;
    QComboBox *mapTypeCombo;

    int markerCounter;
};

#endif // MAINWINDOW_H
