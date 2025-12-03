import QtQuick 2.12
import QtLocation 5.12
import QtPositioning 5.12
import QtQml 2.12

MapQuickItem {
    id: staticSatelliteItem

    property double latitude: 55.7558
    property double longitude: 37.6173
    property double altitude: 35786 // Геостационарная орбита
    property string satelliteName: "Статичный спутник"
    property color satelliteColor: "#FF00FF"
    property var mapReference: null
    property real measurementInterval: 5 // Часто измерений (секунд)
    property int measurementCounter: 0

    // НОВЫЕ СВОЙСТВА: Информация о городе
    property string cityId: "" // ID города из JSON
    property string cityName: "" // Название города (например, "Москва")
    property string cityFullTitle: "" // Полное название (например, "Москва - Очень высокий")
    property double baseNoiseLevel: -58 // Базовый уровень шума для города

    // Измерения
    property var measurements: []
    property int maxMeasurements: 50

    coordinate: QtPositioning.coordinate(latitude, longitude)

    anchorPoint.x: satelliteIcon.width / 2
    anchorPoint.y: satelliteIcon.height / 2

    sourceItem: Column {
        spacing: 2

        Rectangle {
            id: satelliteIcon
            width: 18
            height: 18
            radius: 9
            color: satelliteColor
            border.width: 3
            border.color: "white"

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: parent.radius + 4
                color: "transparent"
                border.width: 2
                border.color: satelliteColor
                opacity: 0.5
                z: -1
            }

            // Анимация пульсации
            SequentialAnimation on scale {
                running: true
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.2; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.2; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {
            width: nameLabel.contentWidth + 10
            height: nameLabel.contentHeight + 6
            color: "#E0FFFFFF"
            border.width: 1
            border.color: "gray"
            radius: 4
            opacity: 0.9
            visible: map.zoomLevel > 5

            Text {
                id: nameLabel
                anchors.centerIn: parent
                text: satelliteName + "\n" + Math.round(altitude) + " км"
                font.pixelSize: 9
                font.bold: true
                color: "black"
            }
        }
    }

    Timer {
        id: measurementTimer
        interval: 1000 // Обновление каждую секунду
        running: true
        repeat: true
        onTriggered: {
            measurementCounter++;
            if (measurementCounter >= measurementInterval) {
                measurementCounter = 0;
                takeCityMeasurement();
            }
        }
    }

    signal measurementTaken(var measurement)

    function takeCityMeasurement() {
        if (!mapReference) return;

        var measurement = Qt.createQmlObject('
            import QtQuick 2.12;
            SatelliteMeasurement {}
        ', this);

        measurement.satelliteName = satelliteName;
        measurement.latitude = latitude;
        measurement.longitude = longitude;
        measurement.altitude = altitude;
        measurement.measurementTime = new Date();

        // Получаем влияние небесных тел
        var celestialInfluence = mapReference.celestialInfluence || 1.0;
        var timeFactor = calculateTimeFactor();
        measurement.influenceFactor = celestialInfluence * timeFactor;

        // Используем данные города из свойств
        if (cityFullTitle && cityFullTitle !== "") {
            measurement.cityName = cityFullTitle;
        } else if (cityName && cityName !== "") {
            measurement.cityName = cityName;
        } else {
            // Если данные о городе не установлены, используем координаты
            measurement.cityName = "Координаты: " + latitude.toFixed(4) + ", " + longitude.toFixed(4);
        }

        measurement.distanceToCity = 0; // Спутник прямо над городом

        // Базовый уровень шума с вариациями
        var timeOfDayVariation = calculateTimeOfDayVariation();
        var randomVariation = (Math.random() * 4) - 2; // ±2 дБм случайная вариация

        measurement.noiseLevel = baseNoiseLevel + timeOfDayVariation + randomVariation;

        // Учитываем влияние небесных тел
        measurement.noiseLevel *= measurement.influenceFactor;

        measurements.unshift(measurement); // Добавляем в начало

        // Ограничиваем количество сохраненных измерений
        if (measurements.length > maxMeasurements) {
            measurements.pop().destroy();
        }

        // Сигнализируем о новом измерении
        measurementTaken(measurement);

        // Обновляем кружок города в реальном времени
        updateCityNoiseCircle(measurement.noiseLevel);

        console.log("📡 Статичный спутник:", satelliteName,
                    measurement.cityName, measurement.noiseLevel.toFixed(1) + "дБм");
    }

    function calculateTimeFactor() {
        if (!mapReference) return 1.0;
        var h = mapReference.currentTime || 6.0;
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

    function calculateTimeOfDayVariation() {
        if (!mapReference) return 0;
        var h = mapReference.currentTime || 6.0;

        // Вариация в зависимости от времени суток
        if (h >= 7 && h < 9) {
            return 3; // Утро - повышенный уровень
        } else if (h >= 17 && h < 20) {
            return 2; // Вечер - повышенный уровень
        } else if (h >= 22 || h < 5) {
            return -4; // Ночь - пониженный уровень
        } else {
            return 0; // Остальное время - базовый уровень
        }
    }

    function updateCityNoiseCircle(noiseLevel) {
        if (!mapReference || !mapReference.noiseCircles) return;

        // Находим кружок города и обновляем его уровень шума
        for (var i = 0; i < mapReference.noiseCircles.length; i++) {
            var circle = mapReference.noiseCircles[i];
            if (circle) {
                // Проверяем по ID города или названию
                var isCurrentCity = false;

                if (cityId && circle.circleId === cityId) {
                    isCurrentCity = true;
                } else if (cityName && circle.title && circle.title.indexOf(cityName) !== -1) {
                    isCurrentCity = true;
                } else if (cityFullTitle && circle.title === cityFullTitle) {
                    isCurrentCity = true;
                }

                if (isCurrentCity) {
                    // Обновляем уровень шума
                    circle.noiseLevel = noiseLevel;

                    // Обновляем цвет в зависимости от уровня шума
                    updateCircleColor(circle, noiseLevel);
                    break;
                }
            }
        }
    }

    function updateCircleColor(circle, noiseLevel) {
        if (!circle) return;

        if (noiseLevel > -60) {
            circle.color = "#FFFF0000"; // Очень красный
        } else if (noiseLevel > -65) {
            circle.color = "#FFFF4400"; // Красно-оранжевый
        } else if (noiseLevel > -70) {
            circle.color = "#FFFF8800"; // Оранжевый
        } else if (noiseLevel > -75) {
            circle.color = "#FFFFCC00"; // Желто-оранжевый
        } else if (noiseLevel > -80) {
            circle.color = "#FFFFFF00"; // Желтый
        } else if (noiseLevel > -85) {
            circle.color = "#FFAAFF00"; // Желто-зеленый
        } else if (noiseLevel > -90) {
            circle.color = "#FF00FF00"; // Зеленый
        } else {
            circle.color = "#FF00AAFF"; // Синий
        }

        // Анимация изменения цвета
        circle.opacity = 0.8;
    }

    function getMeasurements() {
        return measurements;
    }

    function clearMeasurements() {
        for (var i = 0; i < measurements.length; i++) {
            measurements[i].destroy();
        }
        measurements = [];
    }

    // Функция для установки данных города
    function setCityData(cityData) {
        if (cityData) {
            cityId = cityData.id || "";
            cityName = extractCityNameFromTitle(cityData.title || "");
            cityFullTitle = cityData.title || "";
            baseNoiseLevel = cityData.baseNoiseLevel || -58;

            // Обновляем название спутника
            if (cityName && cityName !== "") {
                satelliteName = cityName + " Монитор";
            }
        }
    }

    function extractCityNameFromTitle(title) {
        // Разделяем название на части до " - "
        var parts = title.split(" - ");
        if (parts.length > 0) {
            return parts[0].trim();
        }
        return title;
    }

    Component.onDestruction: {
        clearMeasurements();
    }
}
