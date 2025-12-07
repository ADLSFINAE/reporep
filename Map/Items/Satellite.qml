import QtQuick 2.12
import QtLocation 5.12
import QtPositioning 5.12
import QtQml 2.12

MapQuickItem {
    id: satelliteItem

    property var trajectory: []
    property int currentPoint: 0
    property double altitude: 800
    property double speed: 1.0
    property bool visibleTrajectory: true
    property string satelliteName: "Спутник"
    property color satelliteColor: "red"

    // Свойства для следов
    property var trailPoints: []
    property int trailUpdateInterval: 5
    property int maxTrailPoints: 500
    property color trailColor: "black"
    property double trailSize: 2
    property int pointsCounter: 0

    // Связь с глобальным временем
    property real currentGlobalTime: 6.0
    property real timeSpeedMultiplier: 1.0

    // Измерения
    property var measurements: []
    property int maxMeasurements: 100
    property real measurementInterval: 30 // Измерение каждые 30 "виртуальных" секунд
    property int measurementCounter: 0
    property var mapReference: null

    // Основная траектория
    property MapPolyline trajectoryLine: MapPolyline {
        line.width: 3
        line.color: satelliteItem.satelliteColor
        opacity: 0.7
        path: satelliteItem.trajectory
        visible: satelliteItem.visibleTrajectory
    }

    anchorPoint.x: satelliteIcon.width / 2
    anchorPoint.y: satelliteIcon.height / 2

    sourceItem: Column {
        spacing: 2

        Rectangle {
            id: satelliteIcon
            width: 14
            height: 14
            radius: 7
            color: satelliteColor
            border.width: 2
            border.color: "white"

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 0.6; to: 1.0; duration: 1500 }
                NumberAnimation { from: 1.0; to: 0.6; duration: 1500 }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: parent.height + 6
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: "#30000000"
                z: -1
            }
        }

        Rectangle {
            width: nameLabel.contentWidth + 8
            height: nameLabel.contentHeight + 4
            color: "#E0FFFFFF"
            border.width: 1
            border.color: "gray"
            radius: 3
            opacity: 0.9
            visible: map.zoomLevel > 5

            Text {
                id: nameLabel
                anchors.centerIn: parent
                text: satelliteName + "\n" + Math.round(altitude) + " км"
                font.pixelSize: 8
                font.bold: true
                color: "black"
            }
        }
    }

    Timer {
        id: movementTimer
        interval: 50
        running: true
        repeat: true
        onTriggered: moveToNextPoint()
    }

    signal measurementTaken(var measurement)

    // Функция для расчета скорости на основе высоты
    function calculateSpeedFromAltitude() {
        // Орбитальная скорость зависит от высоты по формуле v = √(GM/r)
        // Где GM для Земли ~ 3.986×10^14 м³/с², r = R_earth + altitude

        var earthRadius = 6371000; // метров
        var GM = 3.986e14; // м³/с²

        var orbitRadius = earthRadius + (altitude * 1000); // переводим км в метры
        var orbitalSpeed = Math.sqrt(GM / orbitRadius); // м/с

        // Нормализуем скорость для анимации
        var baseSpeed;

        if (altitude > 35700) {
            // Геостационарная орбита
            baseSpeed = 0.1;
        } else if (altitude > 20000) {
            // Высокая орбита
            baseSpeed = 0.3;
        } else if (altitude > 1000) {
            // Средняя орбита
            baseSpeed = 0.7;
        } else {
            // Низкая орбита
            baseSpeed = 1.5;
        }

        // Корректируем с учетом реальной орбитальной скорости
        var referenceSpeed = 7800; // м/с для НОО
        var speedFactor = orbitalSpeed / referenceSpeed;

        return baseSpeed * speedFactor * timeSpeedMultiplier;
    }

    // Функция для обновления скорости на основе времени суток
    function updateTimeBasedSpeed() {
        var h = currentGlobalTime;
        var timeFactor;

        // В дневное время спутники могут двигаться немного быстрее
        // из-за солнечного излучения и термических эффектов
        if (h >= 6 && h < 18) {
            // День - небольшое ускорение
            timeFactor = 1.05;
        } else if (h >= 4 && h < 6) {
            // Рассвет - переходный период
            timeFactor = 1.02;
        } else if (h >= 18 && h < 20) {
            // Закат - переходный период
            timeFactor = 1.02;
        } else {
            // Ночь - базовая скорость
            timeFactor = 1.0;
        }

        timeSpeedMultiplier = timeFactor;
        updateMovementSpeed();
    }

    function moveToNextPoint() {
        if (trajectory.length === 0) return;

        // Рассчитываем шаг перемещения на основе скорости
        var effectiveSpeed = calculateSpeedFromAltitude();
        var step = Math.max(1, Math.floor(effectiveSpeed));

        currentPoint = (currentPoint + step) % trajectory.length;
        coordinate = trajectory[currentPoint];

        // Добавляем точку следа через определенные интервалы
        pointsCounter++;
        if (pointsCounter >= trailUpdateInterval) {
            pointsCounter = 0;
            addTrailPoint(coordinate);
        }

        // Измеряем радиоизлучение
        measurementCounter++;
        if (measurementCounter >= measurementInterval) {
            measurementCounter = 0;
            takeMeasurement();
        }
    }

    function addTrailPoint(coord) {
        var component = Qt.createComponent("qrc:/Map/Items/TrailPoint.qml");
        if (component.status === Component.Ready) {
            var trailPoint = component.createObject(map, {
                "coordinate": Qt.binding(function() { return coord; }),
                "trailColor": trailColor,
                "trailSize": trailSize
            });

            trailPoints.push(trailPoint);

            if (trailPoints.length > maxTrailPoints) {
                var oldPoint = trailPoints.shift();
                oldPoint.destroy();
            }
        }
    }

    function clearTrail() {
        for (var i = 0; i < trailPoints.length; i++) {
            trailPoints[i].destroy();
        }
        trailPoints = [];
        pointsCounter = 0;
    }

    function setTrajectory(newTrajectory) {
        trajectory = newTrajectory;
        if (trajectory.length > 0) {
            currentPoint = 0;
            coordinate = trajectory[0];
            clearTrail();
        }
    }

    function setAltitude(newAltitude) {
        altitude = newAltitude;
        updateMovementSpeed();
    }

    function updateMovementSpeed() {
        var effectiveSpeed = calculateSpeedFromAltitude();

        // Обновляем интервал таймера на основе скорости
        if (effectiveSpeed > 2.0) {
            movementTimer.interval = 30; // Быстрее для низких орбит
            trailUpdateInterval = 3;
            measurementInterval = 15; // Чаще измеряем на низких орбитах
        } else if (effectiveSpeed > 1.0) {
            movementTimer.interval = 50;
            trailUpdateInterval = 5;
            measurementInterval = 30;
        } else if (effectiveSpeed > 0.5) {
            movementTimer.interval = 80;
            trailUpdateInterval = 8;
            measurementInterval = 60;
        } else {
            movementTimer.interval = 120; // Медленнее для высоких орбит
            trailUpdateInterval = 12;
            measurementInterval = 120; // Реже измеряем на высоких орбитах
        }
    }

    // Функция для обновления глобального времени
    function setGlobalTime(time) {
        currentGlobalTime = time;
        updateTimeBasedSpeed();
    }

    // Функция для выполнения измерения
    function takeMeasurement() {
        if (!mapReference) {
            console.log("Ошибка: mapReference не установлен");
            return;
        }

        var measurement = Qt.createQmlObject('
            import QtQuick 2.12;
            SatelliteMeasurement {}
        ', this);

        measurement.satelliteName = satelliteName;
        measurement.latitude = coordinate.latitude;
        measurement.longitude = coordinate.longitude;
        measurement.altitude = altitude;
        measurement.measurementTime = new Date();

        // Получаем влияние небесных тел
        var celestialInfluence = mapReference.celestialInfluence || 1.0;
        var timeFactor = calculateTimeFactor();
        measurement.influenceFactor = celestialInfluence * timeFactor;

        // Находим ближайший город и измеряем уровень шума
        var nearestCity = findNearestCity(measurement.latitude, measurement.longitude);
        if (nearestCity) {
            measurement.cityName = nearestCity.title;
            measurement.distanceToCity = nearestCity.distance;
            // Базовый уровень шума уменьшается с расстоянием
            var distanceFactor = Math.max(0.1, 1 - (measurement.distanceToCity / (nearestCity.radius * 3)));
            var baseNoise = nearestCity.baseNoiseLevel;
            // Добавляем случайную вариацию ±3 дБм
            var randomVariation = (Math.random() * 6) - 3;
            measurement.noiseLevel = (baseNoise * distanceFactor * measurement.influenceFactor) + randomVariation;
        } else {
            measurement.cityName = "Открытая местность";
            measurement.distanceToCity = 0;
            // Фоновый шум для открытой местности с учетом высоты
            var heightFactor = Math.max(0.3, 1 - (altitude / 40000));
            measurement.noiseLevel = -95 * heightFactor * measurement.influenceFactor;
        }

        measurements.unshift(measurement); // Добавляем в начало

        // Ограничиваем количество сохраненных измерений
        if (measurements.length > maxMeasurements) {
            measurements.pop().destroy();
        }

        // Сигнализируем о новом измерении
        measurementTaken(measurement);

        // Визуальная индикация измерения
        showMeasurementIndicator();
    }

    // Функция для поиска ближайшего города
    function findNearestCity(lat, lng) {
        if (!mapReference || !mapReference.noiseCircles) return null;

        var minDistance = Infinity;
        var nearestCity = null;

        for (var i = 0; i < mapReference.noiseCircles.length; i++) {
            var circle = mapReference.noiseCircles[i];
            if (!circle || !circle.center) continue;

            var distance = calculateDistance(
                lat, lng,
                circle.center.latitude, circle.center.longitude
            );

            if (distance < minDistance) {
                minDistance = distance;
                nearestCity = {
                    title: circle.title,
                    baseNoiseLevel: circle.baseNoiseLevel || -100,
                    radius: circle.radius || 1000,
                    distance: distance
                };
            }
        }

        // Если расстояние слишком большое, считаем что не над городом
        if (nearestCity && nearestCity.distance > (nearestCity.radius * 3)) {
            return null;
        }

        return nearestCity;
    }

    // Функция расчета расстояния
    function calculateDistance(lat1, lon1, lat2, lon2) {
        var R = 6371000; // Радиус Земли в метрах
        var dLat = (lat2 - lat1) * Math.PI / 180;
        var dLon = (lon2 - lon1) * Math.PI / 180;
        var a =
            Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
        var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return R * c;
    }

    // Функция расчета фактора времени
    function calculateTimeFactor() {
        var h = currentGlobalTime;
        var timeFactor;

        if (h >= 6 && h < 18) {
            // День - повышенный уровень из-за активности
            timeFactor = 1.15;
        } else if (h >= 4 && h < 6) {
            // Рассвет - переходный период
            timeFactor = 1.02;
        } else if (h >= 18 && h < 20) {
            // Закат - переходный период
            timeFactor = 1.02;
        } else {
            // Ночь - базовый уровень
            timeFactor = 1.0;
        }

        return timeFactor;
    }

    // Визуальная индикация измерения
    function showMeasurementIndicator() {
        var component = Qt.createComponent("qrc:/Map/Items/MeasurementIndicator.qml");
        if (component.status === Component.Ready) {
            var indicator = component.createObject(map, {
                "coordinate": coordinate,
                "measurementColor": getNoiseColor(getLatestNoiseLevel()),
                "satelliteName": satelliteName
            });

            // Создаем таймер для автоматического удаления индикатора
            var removalTimer = Qt.createQmlObject('
                import QtQuick 2.12;
                Timer {
                    interval: 2000
                    running: true
                    repeat: false
                    onTriggered: {
                        if (indicator) {
                            indicator.destroy();
                        }
                        destroy();
                    }
                }
            ', indicator);
        }
    }

    function getNoiseColor(noiseLevel) {
        if (noiseLevel > -70) return "#FF0000";
        if (noiseLevel > -80) return "#FF8800";
        if (noiseLevel > -90) return "#FFFF00";
        if (noiseLevel > -100) return "#00FF00";
        return "#0000FF";
    }

    function getLatestNoiseLevel() {
        if (measurements.length > 0) {
            return measurements[0].noiseLevel;
        }
        return -100;
    }

    // Функция для получения всех измерений
    function getMeasurements() {
        return measurements;
    }

    // Функция для очистки измерений
    function clearMeasurements() {
        for (var i = 0; i < measurements.length; i++) {
            measurements[i].destroy();
        }
        measurements = [];
    }

    // Функция для получения последнего измерения
    function getLatestMeasurement() {
        if (measurements.length > 0) {
            return measurements[0];
        }
        return null;
    }

    // Функция для получения статистики измерений
    function getMeasurementStats() {
        if (measurements.length === 0) return null;

        var minNoise = 0;
        var maxNoise = -200;
        var sumNoise = 0;
        var cityCount = 0;

        for (var i = 0; i < measurements.length; i++) {
            var noise = measurements[i].noiseLevel;
            if (noise > maxNoise) maxNoise = noise;
            if (noise < minNoise) minNoise = noise;
            sumNoise += noise;
            if (measurements[i].cityName !== "Открытая местность") {
                cityCount++;
            }
        }

        return {
            total: measurements.length,
            cityMeasurements: cityCount,
            avgNoise: sumNoise / measurements.length,
            minNoise: minNoise,
            maxNoise: maxNoise,
            latest: getLatestMeasurement()
        };
    }

    Component.onCompleted: {
        updateMovementSpeed();
        updateTimeBasedSpeed();
    }

    Component.onDestruction: {
        clearTrail();
        clearMeasurements();
    }
}
