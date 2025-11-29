import QtQuick 2.12
import QtQuick.Window 2.12
import QtLocation 5.12
import QtPositioning 5.12
import QtQml 2.12

Item {
    visible: true
    width: 800
    height: 600

    property var markers: []
    property var noiseCircles: []
    property double currentRadius: 1000
    property real currentTime: 6.0
    property real dayNightFactor: 1.0
    property real targetTime: 6.0
    property int timeSpeed: 1
    property var speedMultipliers: [1, 2, 5, 10, 60]
    property var speedLabels: ["x1", "x2", "x5", "x10", "x60"]

    // Цветовая схема для уровней радиоизлучения
    property var noiseLevels: [
        { range: "≥ -60 дБм", color: "#FF0000", description: "Очень высокий", level: -55 },
        { range: "-60 до -70", color: "#FF4400", description: "Высокий", level: -65 },
        { range: "-70 до -75", color: "#FF8800", description: "Повышенный", level: -72.5 },
        { range: "-75 до -80", color: "#FFCC00", description: "Средний", level: -77.5 },
        { range: "-80 до -85", color: "#FFFF00", description: "Низкий", level: -82.5 },
        { range: "-85 до -90", color: "#AAFF00", description: "Очень низкий", level: -87.5 },
        { range: "-90 до -95", color: "#00FF00", description: "Минимальный", level: -92.5 },
        { range: "< -95 дБм", color: "#00AAFF", description: "Фоновый", level: -100 }
    ]

    // Таймер для плавного суточного цикла
    Timer {
        id: realTimeTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var minutesToAdd = timeSpeed;
            targetTime += minutesToAdd / 60;
            if (targetTime >= 24) targetTime -= 24;
        }
    }

    // Таймер для плавной анимации (60 FPS)
    Timer {
        id: animationTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: updateSmoothTransition()
    }

    Plugin {
        id: mapPlugin
        name: "osm"
    }

    Map {
        id: map
        anchors.fill: parent
        plugin: mapPlugin
        center: QtPositioning.coordinate(55.7558, 37.6173)
        zoomLevel: 10
        activeMapType: supportedMapTypes[0]
        gesture.enabled: true

        // Круг для отображения радиуса анализа
        MapCircle {
            id: analysisCircle
            center: QtPositioning.coordinate(0, 0)
            radius: currentRadius
            color: "transparent"
            border.width: 3
            border.color: "blue"
            opacity: 0.8
            visible: false
        }

        // Текст для отображения среднего значения
        MapQuickItem {
            id: averageTextItem
            anchorPoint.x: averageText.width / 2
            anchorPoint.y: averageText.height
            coordinate: QtPositioning.coordinate(0, 0)
            visible: false
            z: 1000

            sourceItem: Rectangle {
                id: averageText
                width: textItem.contentWidth + 20
                height: textItem.contentHeight + 15
                color: "#FFFFFF"
                border.width: 2
                border.color: "blue"
                opacity: 0.95
                radius: 8

                Text {
                    id: textItem
                    anchors.centerIn: parent
                    text: "Среднее: - дБм"
                    font.bold: true
                    font.pixelSize: 14
                    color: "black"
                }
            }
        }
    }

    // Функция для загрузки конфигурации из JSON
    function loadConfigurationFromJson() {
        console.log("Загрузка конфигурации из JSON...");

        // Очищаем старые круги
        clearNoiseCircles();

        // В реальном приложении здесь будет загрузка из файла
        // Для демонстрации используем встроенный JSON
        var configJson = getDefaultConfiguration();

        try {
            var config = JSON.parse(configJson);
            console.log("Загружено зон из конфигурации:", config.circles.length);

            // Создаем круги из конфигурации
            for (var i = 0; i < config.circles.length; i++) {
                var circleConfig = config.circles[i];
                if (circleConfig.enabled) {
                    createNoiseCircleFromConfig(circleConfig);
                }
            }

            console.log("Успешно создано кругов:", noiseCircles.length);
            return true;

        } catch (error) {
            console.log("Ошибка загрузки конфигурации:", error);
            // В случае ошибки загружаем демо-конфигурацию
            loadDemoConfiguration();
            return false;
        }
    }

    // Демо-конфигурация (в реальном приложении загружается из файла)
    function getDefaultConfiguration() {
        return `{
            "version": "1.0",
            "description": "Конфигурация зон радиоизлучения Москвы",
            "circles": [
                {
                    "id": "center_high",
                    "latitude": 55.7558,
                    "longitude": 37.6173,
                    "radius": 500,
                    "baseNoiseLevel": -60,
                    "color": "#FFFF0000",
                    "title": "Кремль - Очень высокий",
                    "enabled": true
                },
                {
                    "id": "center_medium",
                    "latitude": 55.7558,
                    "longitude": 37.6173,
                    "radius": 1000,
                    "baseNoiseLevel": -70,
                    "color": "#CCFF4400",
                    "title": "Центр - Высокий",
                    "enabled": true
                },
                {
                    "id": "center_low",
                    "latitude": 55.7558,
                    "longitude": 37.6173,
                    "radius": 1500,
                    "baseNoiseLevel": -75,
                    "color": "#99FF8800",
                    "title": "Окраины центра - Повышенный",
                    "enabled": true
                },
                {
                    "id": "north_zone",
                    "latitude": 55.8500,
                    "longitude": 37.6000,
                    "radius": 800,
                    "baseNoiseLevel": -80,
                    "color": "#66FFCC00",
                    "title": "Северный округ",
                    "enabled": true
                },
                {
                    "id": "south_zone",
                    "latitude": 55.6500,
                    "longitude": 37.6000,
                    "radius": 1200,
                    "baseNoiseLevel": -85,
                    "color": "#33FFFF00",
                    "title": "Южный округ",
                    "enabled": true
                },
                {
                    "id": "east_zone",
                    "latitude": 55.7500,
                    "longitude": 37.8000,
                    "radius": 1000,
                    "baseNoiseLevel": -82,
                    "color": "#44FFFF00",
                    "title": "Восточный округ",
                    "enabled": true
                },
                {
                    "id": "west_zone",
                    "latitude": 55.7500,
                    "longitude": 37.4000,
                    "radius": 900,
                    "baseNoiseLevel": -78,
                    "color": "#77FFAA00",
                    "title": "Западный округ",
                    "enabled": true
                },
                {
                    "id": "airport_svo",
                    "latitude": 55.9728,
                    "longitude": 37.4146,
                    "radius": 2000,
                    "baseNoiseLevel": -65,
                    "color": "#FFFF4444",
                    "title": "Шереметьево - Высокий",
                    "enabled": true
                },
                {
                    "id": "airport_dme",
                    "latitude": 55.4086,
                    "longitude": 37.9063,
                    "radius": 1800,
                    "baseNoiseLevel": -68,
                    "color": "#FFFF6644",
                    "title": "Домодедово - Высокий",
                    "enabled": true
                },
                {
                    "id": "business_center",
                    "latitude": 55.7470,
                    "longitude": 37.5394,
                    "radius": 600,
                    "baseNoiseLevel": -58,
                    "color": "#FFFF0000",
                    "title": "Москва-Сити - Максимальный",
                    "enabled": true
                },
                {
                    "id": "university",
                    "latitude": 55.7030,
                    "longitude": 37.5300,
                    "radius": 400,
                    "baseNoiseLevel": -75,
                    "color": "#99FF8800",
                    "title": "МГУ - Средний",
                    "enabled": true
                }
            ]
        }`;
    }

    // Загрузка демо-конфигурации при ошибке
    function loadDemoConfiguration() {
        console.log("Загрузка демо-конфигурации...");
        clearNoiseCircles();

        // Простая демо-конфигурация
        var demoCircles = [
            { lat: 55.7558, lng: 37.6173, radius: 500, level: -60, color: "#FFFF0000", title: "Центр" },
            { lat: 55.7558, lng: 37.6173, radius: 1000, level: -70, color: "#CCFF4400", title: "Центр" },
            { lat: 55.7558, lng: 37.6173, radius: 1500, level: -75, color: "#99FF8800", title: "Центр" }
        ];

        for (var i = 0; i < demoCircles.length; i++) {
            var circle = demoCircles[i];
            createNoiseCircle(circle.lat, circle.lng, circle.radius, circle.color, circle.level, circle.title);
        }
    }

    // Создание круга из конфигурации
    function createNoiseCircleFromConfig(config) {
        var component = Qt.createComponent("NoiseCircle.qml");
        if (component.status === Component.Ready) {
            var circle = component.createObject(map);
            circle.center = QtPositioning.coordinate(config.latitude, config.longitude);
            circle.radius = config.radius;
            circle.color = config.color;
            circle.baseNoiseLevel = config.baseNoiseLevel;
            circle.noiseLevel = config.baseNoiseLevel;
            circle.title = config.title;
            circle.circleId = config.id;
            noiseCircles.push(circle);
            map.addMapItem(circle);
            console.log("Создан круг: " + config.title + " (ID: " + config.id + ")");
            return circle;
        } else {
            console.log("Ошибка создания круга из конфигурации:", component.errorString());
        }
        return null;
    }

    // Панель информации о времени
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        width: 260
        height: 130
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2

            Text {
                text: "Время суток:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            Text {
                id: timeText
                text: "6:00 (Утро)"
                font.pixelSize: 14
                font.bold: true
                color: getTimeColor()
            }

            Text {
                text: "Множитель шума: " + dayNightFactor.toFixed(3) + "x"
                font.pixelSize: 10
                color: "black"
            }

            Text {
                id: speedText
                text: "Скорость: " + speedLabels[getSpeedIndex()] + " (1 сек = " + timeSpeed + " мин)"
                font.pixelSize: 9
                color: getSpeedColor()
            }

            Text {
                text: "Зон загружено: " + noiseCircles.length
                font.pixelSize: 8
                color: "darkgray"
            }

            Text {
                text: "Следующий час: " + (60 - Math.floor((currentTime % 1) * 60)) + " мин"
                font.pixelSize: 8
                color: "darkgray"
            }
        }
    }

    // Цветовая легенда для уровней радиоизлучения
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 200
        height: 280
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2

            Text {
                text: "Уровни радиоизлучения:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            Repeater {
                model: noiseLevels

                Row {
                    spacing: 5
                    height: 20

                    Rectangle {
                        width: 20
                        height: 15
                        color: modelData.color
                        border.width: 1
                        border.color: "gray"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: modelData.range
                            font.pixelSize: 9
                            font.bold: true
                            color: "black"
                        }
                        Text {
                            text: modelData.description
                            font.pixelSize: 8
                            color: "darkgray"
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "gray"
                opacity: 0.5
            }

            Text {
                text: "💡 Конфигурация из JSON"
                font.pixelSize: 8
                color: "darkblue"
                font.italic: true
            }

            Text {
                text: "Зон: " + noiseCircles.length
                font.pixelSize: 8
                color: "darkblue"
            }
        }
    }

    // Остальные функции остаются без изменений...
    function getSpeedIndex() {
        for (var i = 0; i < speedMultipliers.length; i++) {
            if (speedMultipliers[i] === timeSpeed) return i;
        }
        return 0;
    }

    function getSpeedColor() {
        switch(timeSpeed) {
            case 1: return "green";
            case 2: return "blue";
            case 5: return "orange";
            case 10: return "#FF6600";
            case 60: return "red";
            default: return "black";
        }
    }

    function setTimeSpeed(speed) {
        if (speedMultipliers.indexOf(speed) !== -1) {
            timeSpeed = speed;
        }
    }

    function updateSmoothTransition() {
        var diff = targetTime - currentTime;
        if (diff > 12) diff -= 24;
        if (diff < -12) diff += 24;

        var smoothFactor = Math.max(0.02, 0.05 / Math.sqrt(timeSpeed));
        currentTime += diff * smoothFactor;

        if (currentTime >= 24) currentTime -= 24;
        if (currentTime < 0) currentTime += 24;

        updateDayNightCycle();
    }

    // Остальные функции (getTimeColor, getTimeOfDay, formatTime, updateDayNightCycle, etc.)
    // остаются без изменений из предыдущего кода...

    function updateDayNightCycle() {
        var h = currentTime;
        var newFactor;

        if (h >= 23 || h < 6) {
            if (h >= 23) {
                newFactor = 0.3 + (1.0 - 0.3) * ((24 - h) / 1);
            } else if (h < 3) {
                newFactor = 0.3 + (0.2 - 0.3) * (h / 3);
            } else {
                newFactor = 0.2 + (0.5 - 0.2) * ((h - 3) / 3);
            }
        }
        else if (h >= 6 && h < 20) {
            if (h < 14) {
                newFactor = 0.5 + (1.5 - 0.5) * ((h - 6) / 8);
            } else {
                newFactor = 1.5 + (1.0 - 1.5) * ((h - 14) / 6);
            }
        }
        else {
            newFactor = 1.0 + (0.3 - 1.0) * ((h - 20) / 3);
        }

        dayNightFactor += (newFactor - dayNightFactor) * 0.02;

        timeText.text = formatTime(currentTime) + " (" + getTimeOfDay() + ")";
        timeText.color = getTimeColor();
        speedText.text = "Скорость: " + speedLabels[getSpeedIndex()] + " (1 сек = " + timeSpeed + " мин)";
        speedText.color = getSpeedColor();

        updateCirclesAppearance();

        if (markers.length > 0) {
            var lastMarker = markers[markers.length - 1];
            showAreaAnalysis(lastMarker.coordinate.latitude, lastMarker.coordinate.longitude, currentRadius);
        }
    }

    function updateCirclesAppearance() {
        var h = currentTime;
        var baseOpacity;

        if (h >= 6 && h < 20) {
            var dayProgress = (h - 6) / 14;
            baseOpacity = 0.3 + 0.5 * (0.5 + 0.5 * Math.sin(dayProgress * Math.PI));
        } else {
            var nightProgress = h < 6 ? (h + 4) / 10 : (h - 20) / 4;
            baseOpacity = 0.2 + 0.3 * (0.5 - 0.5 * Math.cos(nightProgress * Math.PI * 2));
        }

        for (var i = 0; i < noiseCircles.length; i++) {
            var circle = noiseCircles[i];
            if (circle) {
                var circleOpacity = baseOpacity * (1 - i / noiseCircles.length * 0.6);
                circle.opacity = Math.max(0.05, Math.min(0.85, circleOpacity));
                updateCircleColor(circle, i);
            }
        }
    }

    function updateCircleColor(circle, index) {
        var baseColor = circle.color;
        var h = currentTime;

        var colorFactor;
        if (h >= 6 && h < 18) {
            var warmProgress = (h - 6) / 12;
            colorFactor = 0.8 + 0.2 * Math.sin(warmProgress * Math.PI);
        } else {
            var coolProgress = h < 6 ? (h + 6) / 12 : (h - 18) / 6;
            colorFactor = 0.3 + 0.5 * (1 - Math.abs(coolProgress - 0.5) * 2);
        }

        var r = Math.min(255, parseInt(baseColor.substr(3, 2), 16) * colorFactor);
        var g = Math.min(255, parseInt(baseColor.substr(5, 2), 16) * colorFactor);
        var b = Math.min(255, parseInt(baseColor.substr(7, 2), 16) +
                         (255 - parseInt(baseColor.substr(7, 2), 16)) * (1 - colorFactor));
        var a = baseColor.substr(1, 2);

        circle.color = "#" + a +
                     Math.floor(r).toString(16).padStart(2, '0') +
                     Math.floor(g).toString(16).padStart(2, '0') +
                     Math.floor(b).toString(16).padStart(2, '0');
    }

    function clearNoiseCircles() {
        for (var i = 0; i < noiseCircles.length; i++) {
            map.removeMapItem(noiseCircles[i]);
            noiseCircles[i].destroy();
        }
        noiseCircles = [];
    }

    function createNoiseCircle(lat, lng, radius, color, baseNoiseLevel, title) {
        var component = Qt.createComponent("NoiseCircle.qml");
        if (component.status === Component.Ready) {
            var circle = component.createObject(map);
            circle.center = QtPositioning.coordinate(lat, lng);
            circle.radius = radius;
            circle.color = color;
            circle.baseNoiseLevel = baseNoiseLevel;
            circle.noiseLevel = baseNoiseLevel;
            circle.title = title;
            noiseCircles.push(circle);
            map.addMapItem(circle);
            return circle;
        }
        return null;
    }

    // Остальные функции (calculateAverageNoise, showAreaAnalysis, etc.)...
    function calculateAverageNoise(centerLat, centerLng, radius) {
        var centerCoord = QtPositioning.coordinate(centerLat, centerLng);
        var totalWeightedNoise = 0;
        var totalArea = 0;

        for (var i = 0; i < noiseCircles.length; i++) {
            var circle = noiseCircles[i];
            if (!circle) continue;

            circle.noiseLevel = circle.baseNoiseLevel * dayNightFactor;

            var distance = centerCoord.distanceTo(circle.center);
            var circleRadius = circle.radius;

            if (distance + radius <= circleRadius) {
                var area = Math.PI * radius * radius;
                totalWeightedNoise += circle.noiseLevel * area;
                totalArea += area;
            }
            else if (distance < circleRadius + radius) {
                var intersectionArea = calculateCircleIntersectionArea(radius, circleRadius, distance);
                totalWeightedNoise += circle.noiseLevel * intersectionArea;
                totalArea += intersectionArea;
            }
        }

        if (totalArea > 0) {
            var average = totalWeightedNoise / totalArea;
            var avgDescription = getNoiseLevelDescription(average);
            console.log("Средний шум: " + average.toFixed(1) + " дБм (" + avgDescription + ")");
            return average;
        } else {
            return -100 * dayNightFactor;
        }
    }

    function calculateCircleIntersectionArea(r1, r2, d) {
        if (d >= r1 + r2) return 0;
        if (d <= Math.abs(r1 - r2)) {
            var minR = Math.min(r1, r2);
            return Math.PI * minR * minR;
        }

        var part1 = r1 * r1 * Math.acos((d * d + r1 * r1 - r2 * r2) / (2 * d * r1));
        var part2 = r2 * r2 * Math.acos((d * d + r2 * r2 - r1 * r1) / (2 * d * r2));
        var part3 = 0.5 * Math.sqrt((-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2));

        return part1 + part2 - part3;
    }

    function showAreaAnalysis(lat, lng, radius) {
        currentRadius = radius;
        analysisCircle.center = QtPositioning.coordinate(lat, lng);
        analysisCircle.radius = radius;
        analysisCircle.visible = true;

        var averageNoise = calculateAverageNoise(lat, lng, radius);
        averageTextItem.coordinate = QtPositioning.coordinate(lat, lng);

        var avgDescription = getNoiseLevelDescription(averageNoise);
        averageTextItem.sourceItem.children[0].text = "Среднее: " + averageNoise.toFixed(1) + " дБм\n(" + avgDescription + ")";
        averageTextItem.visible = true;
    }

    function getColorForNoiseLevel(noiseLevel) {
        for (var i = 0; i < noiseLevels.length; i++) {
            var level = noiseLevels[i];
            if (i === 0 && noiseLevel >= level.level) return level.color;
            if (i === noiseLevels.length - 1 && noiseLevel < level.level) return level.color;

            var nextLevel = i < noiseLevels.length - 1 ? noiseLevels[i + 1] : null;
            if (nextLevel && noiseLevel >= level.level && noiseLevel < nextLevel.level) {
                return level.color;
            }
        }
        return "#00AAFF";
    }

    function getNoiseLevelDescription(noiseLevel) {
        for (var i = 0; i < noiseLevels.length; i++) {
            var level = noiseLevels[i];
            if (i === 0 && noiseLevel >= level.level) return level.description;
            if (i === noiseLevels.length - 1 && noiseLevel < level.level) return level.description;

            var nextLevel = i < noiseLevels.length - 1 ? noiseLevels[i + 1] : null;
            if (nextLevel && noiseLevel >= level.level && noiseLevel < nextLevel.level) {
                return level.description;
            }
        }
        return "Фоновый";
    }

    function getTimeColor() {
        var h = currentTime;
        if (h >= 5 && h < 7) {
            var dawnProgress = (h - 5) / 2;
            return Qt.rgba(0.2 + 0.8 * dawnProgress, 0.4 + 0.4 * dawnProgress, 1.0 - 0.6 * dawnProgress, 1);
        }
        else if (h >= 7 && h < 17) {
            var dayProgress = (h - 7) / 10;
            return Qt.rgba(1.0, 0.6 - 0.2 * dayProgress, 0.0 + 0.2 * dayProgress, 1);
        }
        else if (h >= 17 && h < 20) {
            var sunsetProgress = (h - 17) / 3;
            return Qt.rgba(1.0 - 0.3 * sunsetProgress, 0.4 - 0.4 * sunsetProgress, 0.2 + 0.3 * sunsetProgress, 1);
        }
        else {
            var nightProgress = h < 5 ? (h + 4) / 9 : (h - 20) / 9;
            return Qt.rgba(0.7 - 0.5 * nightProgress, 0.0 + 0.2 * nightProgress, 0.5 + 0.5 * nightProgress, 1);
        }
    }

    function getTimeOfDay() {
        var h = currentTime;
        if (h >= 4 && h < 8) return "Рассвет";
        if (h >= 8 && h < 12) return "Утро";
        if (h >= 12 && h < 16) return "День";
        if (h >= 16 && h < 20) return "Вечер";
        if (h >= 20 && h < 23) return "Поздний вечер";
        return "Ночь";
    }

    function formatTime(time) {
        var hours = Math.floor(time);
        var minutes = Math.round((time % 1) * 60);
        return hours.toString().padStart(2, '0') + ":" + minutes.toString().padStart(2, '0');
    }

    // Остальные функции управления...
    function setCenter(lat, lng, zoom) {
        map.center = QtPositioning.coordinate(lat, lng);
        if (zoom !== undefined) map.zoomLevel = zoom;
    }

    function setZoom(zoom) { map.zoomLevel = zoom; }

    function setMapType(type) {
        for (var i = 0; i < map.supportedMapTypes.length; i++) {
            var mapTypeName = map.supportedMapTypes[i].name.toLowerCase();
            if (mapTypeName.indexOf(type) !== -1) {
                map.activeMapType = map.supportedMapTypes[i];
                break;
            }
        }
    }

    function addMarkerWithData(markerData) {
        var component = Qt.createComponent("Marker.qml");
        if (component.status === Component.Ready) {
            var marker = component.createObject(map);
            marker.coordinate = QtPositioning.coordinate(markerData.lat, markerData.lng);
            marker.title = markerData.title;
            marker.noiseLevel = markerData.noiseLevel * dayNightFactor;
            markers.push(marker);
            map.addMapItem(marker);
            showAreaAnalysis(markerData.lat, markerData.lng, currentRadius);
        }
    }

    function clearMarkers() {
        analysisCircle.visible = false;
        averageTextItem.visible = false;
        for (var i = 0; i < markers.length; i++) {
            map.removeMapItem(markers[i]);
            markers[i].destroy();
        }
        markers = [];
    }

    function setAnalysisRadius(radius) {
        currentRadius = radius;
        if (markers.length > 0) {
            var lastMarker = markers[markers.length - 1];
            showAreaAnalysis(lastMarker.coordinate.latitude, lastMarker.coordinate.longitude, radius);
        }
    }

    Component.onCompleted: {
        console.log("Инициализация с JSON конфигурацией...");
        loadConfigurationFromJson();
        updateDayNightCycle();
    }

    // Элементы управления с кнопкой перезагрузки конфигурации
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10
        width: 300
        height: 160
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 3

            Text {
                text: "Управление системой:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            // Кнопки управления скоростью
            Row {
                spacing: 3
                Repeater {
                    model: speedMultipliers
                    Rectangle {
                        width: 40
                        height: 25
                        color: timeSpeed === modelData ? getSpeedButtonColor(modelData) : "lightgray"
                        radius: 3
                        border.width: timeSpeed === modelData ? 2 : 1
                        border.color: timeSpeed === modelData ? "darkblue" : "gray"

                        Text {
                            anchors.centerIn: parent
                            text: "x" + modelData
                            font.pixelSize: 10
                            font.bold: true
                            color: timeSpeed === modelData ? "white" : "black"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: setTimeSpeed(modelData)
                        }
                    }
                }
            }

            // Кнопки управления временем и конфигурацией
            Row {
                spacing: 5
                Rectangle {
                    width: 80
                    height: 25
                    color: realTimeTimer.running ? "lightgreen" : "lightgray"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: realTimeTimer.running ? "Пауза" : "Старт"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: realTimeTimer.running = !realTimeTimer.running
                    }
                }

                Rectangle {
                    width: 100
                    height: 25
                    color: "lightblue"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: "+1 час"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: targetTime = (targetTime + 1) % 24
                    }
                }

                Rectangle {
                    width: 100
                    height: 25
                    color: "lightcoral"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: "Перезагрузить"
                        font.pixelSize: 9
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: loadConfigurationFromJson()
                    }
                }
            }

            // Информация о системе
            Column {
                spacing: 1
                Text {
                    text: "Скорость: " + speedLabels[getSpeedIndex()] + " | Зон: " + noiseCircles.length
                    font.pixelSize: 9
                    color: getSpeedColor()
                    font.bold: true
                }

                Text {
                    text: "1 секунда = " + timeSpeed + " минут"
                    font.pixelSize: 8
                    color: "darkgray"
                }

                Text {
                    text: "Конфигурация: JSON"
                    font.pixelSize: 8
                    color: "darkgreen"
                }
            }
        }
    }

    function getSpeedButtonColor(speed) {
        switch(speed) {
            case 1: return "green";
            case 2: return "blue";
            case 5: return "orange";
            case 10: return "#FF6600";
            case 60: return "red";
            default: return "lightblue";
        }
    }
}
