import QtQuick 2.12
import QtQuick.Window 2.12
import QtLocation 5.12
import QtPositioning 5.12
import QtQml 2.12

Item {
    visible: true
    width: 1200
    height: 800

    property var markers: []
    property var noiseCircles: []
    property double currentRadius: 1000
    property real currentTime: 6.0
    property real targetTime: 6.0
    property int timeSpeed: 1
    property var speedMultipliers: [1, 2, 5, 10, 60, 2400]
    property var speedLabels: ["x1", "x2", "x5", "x10", "x60", "x2400"]
    property string configFilePath: "qrc:/radiation.json"

    // Новые свойства для влияния небесных тел и подсчета дней
    property double celestialInfluence: 1.0
    property double totalInfluence: 1.0
    property date startDate: new Date(2025, 0, 1) // 1 января 2025
    property real daysFromStart: 0
    property real totalDays: 0
    property int fullDaysPassed: 0
    property real currentDayProgress: 0.0
    property real totalTimePassed: 0.0 // Общее время в часах с начала

    // Свойства для спутников
    property var satellites: []
    property bool showSatellites: true
    property real dayNightFactor: 1.0

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

            // Добавляем к общему времени
            totalTimePassed += minutesToAdd / 60;

            // Если прошли полные сутки, увеличиваем счетчик дней
            if (targetTime >= 24) {
                targetTime -= 24;
                fullDaysPassed += 1;
            }
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
        PluginParameter {
            name: "osm.mapping.custom.host"
            value: "https://tile.openstreetmap.org/"
        }
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

        // Спутники будут добавляться динамически здесь
    }

    // Функция для загрузки конфигурации из JSON файла
    function loadConfigurationFromJson() {
        console.log("Загрузка конфигурации из файла:", configFilePath);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", configFilePath);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var config = JSON.parse(xhr.responseText);
                        processJsonConfiguration(config);
                        console.log("JSON успешно загружен из файла");
                    } catch (e) {
                        console.log("Ошибка парсинга JSON:", e.toString());
                        loadDemoConfiguration();
                    }
                } else {
                    console.log("Ошибка загрузки файла:", xhr.status, xhr.statusText);
                    loadDemoConfiguration();
                }
            }
        };
        xhr.send();
    }

    // Обработка загруженной JSON конфигурации
    function processJsonConfiguration(config) {
        console.log("Обработка JSON конфигурации...");

        // Очищаем старые круги
        clearNoiseCircles();

        try {
            if (config && config.circles) {
                console.log("Загружено зон из конфигурации:", config.circles.length);

                // Создаем круги из конфигурации
                for (var i = 0; i < config.circles.length; i++) {
                    var circleConfig = config.circles[i];
                    if (circleConfig.enabled) {
                        createNoiseCircleFromConfig(circleConfig);
                    }
                }

                console.log("Успешно создано кругов:", noiseCircles.length);
                updateConfigInfo("Файл: " + configFilePath + " | Зон: " + noiseCircles.length);
            } else {
                console.log("Неверный формат JSON конфигурации");
                loadDemoConfiguration();
            }
        } catch (error) {
            console.log("Ошибка обработки JSON:", error);
            loadDemoConfiguration();
        }
    }

    // Загрузка демо-конфигурации при ошибке
    function loadDemoConfiguration() {
        console.log("Загрузка демо-конфигурации...");
        clearNoiseCircles();

        // Простая демо-конфигурация
        var demoCircles = [
            { lat: 55.7558, lng: 37.6173, radius: 500, level: -60, color: "#FFFF0000", title: "Центр Москвы" },
            { lat: 55.7558, lng: 37.6173, radius: 1000, level: -70, color: "#CCFF4400", title: "Центральный округ" },
            { lat: 55.7558, lng: 37.6173, radius: 1500, level: -75, color: "#99FF8800", title: "Пригород" }
        ];

        for (var i = 0; i < demoCircles.length; i++) {
            var circle = demoCircles[i];
            createNoiseCircle(circle.lat, circle.lng, circle.radius, circle.color, circle.level, circle.title);
        }

        updateConfigInfo("Демо-конфигурация | Зон: " + noiseCircles.length);
    }

    // Создание круга из конфигурации
    function createNoiseCircleFromConfig(config) {
        var component = Qt.createComponent("qrc:/Map/Items/NoiseCircle.qml");
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

    // Обновление информации о конфигурации
    function updateConfigInfo(info) {
        configInfoText.text = info;
    }

    // Панель информации о времени
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        width: 320
        height: 200
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            Text {
                text: "Время суток:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            Text {
                id: timeText
                text: "6:00 (Утро) | День: 0"
                font.pixelSize: 14
                font.bold: true
                color: getTimeColor()
            }

            Text {
                text: "Множитель времени: " + dayNightFactor.toFixed(3) + "x"
                font.pixelSize: 10
                color: "black"
            }

            Text {
                text: "Влияние небесных тел: " + (celestialInfluence * 100).toFixed(1) + "%"
                font.pixelSize: 10
                color: celestialInfluence > 1 ? "#FF4444" : "#44FF44"
            }

            Text {
                text: "Общий множитель: " + totalInfluence.toFixed(3) + "x"
                font.pixelSize: 10
                color: "purple"
                font.bold: true
            }

            Text {
                id: speedText
                text: "Скорость: " + speedLabels[getSpeedIndex()] + " (1 сек = " + timeSpeed + " мин)"
                font.pixelSize: 9
                color: getSpeedColor()
            }

            Text {
                id: configInfoText
                text: "Загрузка конфигурации..."
                font.pixelSize: 8
                color: "darkgreen"
            }

            Text {
                text: "Спутников: " + satellites.length
                font.pixelSize: 9
                color: "red"
                font.bold: true
            }
        }
    }

    // Цветовая легенда для уровней радиоизлучения
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 220
        height: 300
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 8
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
                    height: 22

                    Rectangle {
                        width: 20
                        height: 16
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
                text: "Файл: radiation.json"
                font.pixelSize: 8
                color: "darkblue"
            }
        }
    }

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
            case 2400: return "#FF00FF";
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
        updateTotalInfluence();

        // Обновляем подсчет дней на основе общего времени
        updateDaysCounter();

        timeText.text = formatTime(currentTime) + " (" + getTimeOfDay() + ")" + " | День: " + Math.floor(daysFromStart);
        timeText.color = getTimeColor();
        speedText.text = "Скорость: " + speedLabels[getSpeedIndex()] + " (1 сек = " + timeSpeed + " мин)";
        speedText.color = getSpeedColor();

        updateCirclesAppearance();

        if (markers.length > 0) {
            var lastMarker = markers[markers.length - 1];
            showAreaAnalysis(lastMarker.coordinate.latitude, lastMarker.coordinate.longitude, currentRadius);
        }
    }

    // Функция для установки влияния небесных тел
    function setCelestialInfluence(influence) {
        celestialInfluence = influence;
        updateTotalInfluence();
    }

    function updateTotalInfluence() {
        totalInfluence = dayNightFactor * celestialInfluence;
        updateCirclesAppearance();
    }

    // Функция подсчета дней на основе общего прошедшего времени
    function updateDaysCounter() {
        // Общее время в часах с начала симуляции
        // Каждые 24 часа реального времени = 1 день в симуляции
        // Но с учетом ускорения времени

        // Преобразуем общее время в дни
        daysFromStart = totalTimePassed / 24;
        totalDays = daysFromStart;

        // Отладочная информация
        // console.log("Time update - Total hours:", totalTimePassed.toFixed(3),
        //             "Days:", daysFromStart.toFixed(3));
    }

    // Упрощенная функция обновления внешнего вида кругов
    function updateCirclesAppearance() {
        var h = currentTime;
        var baseOpacity;

        if (h >= 6 && h < 20) {
            // Днем более непрозрачные
            baseOpacity = 0.6;
        } else {
            // Ночью более прозрачные
            baseOpacity = 0.3;
        }

        for (var i = 0; i < noiseCircles.length; i++) {
            var circle = noiseCircles[i];
            if (circle) {
                // Внутренние круги более непрозрачные
                var circleOpacity = baseOpacity * (1 - i / noiseCircles.length * 0.6);
                circle.opacity = Math.max(0.1, Math.min(0.8, circleOpacity));

                // Обновляем уровень шума с учетом общего влияния
                circle.noiseLevel = circle.baseNoiseLevel * totalInfluence;
            }
        }
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

    function calculateAverageNoise(centerLat, centerLng, radius) {
        var centerCoord = QtPositioning.coordinate(centerLat, centerLng);
        var totalWeightedNoise = 0;
        var totalArea = 0;

        for (var i = 0; i < noiseCircles.length; i++) {
            var circle = noiseCircles[i];
            if (!circle) continue;

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
            return -100 * totalInfluence;
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
            return "#FFAA00"; // Рассвет - золотой
        }
        else if (h >= 7 && h < 17) {
            return "#FF6600"; // День - оранжевый
        }
        else if (h >= 17 && h < 20) {
            return "#FF3300"; // Вечер - красно-оранжевый
        }
        else {
            return "#3366FF"; // Ночь - синий
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

    function setCenter(lat, lng, zoom) {
        map.center = QtPositioning.coordinate(lat, lng);
        if (zoom !== undefined) map.zoomLevel = zoom;
    }

    function setZoom(zoom) {
        map.zoomLevel = zoom;
    }

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
        var component = Qt.createComponent("qrc:/Map/Items/Marker.qml");
        if (component.status === Component.Ready) {
            var marker = component.createObject(map);
            marker.coordinate = QtPositioning.coordinate(markerData.lat, markerData.lng);
            marker.title = markerData.title;
            marker.noiseLevel = markerData.noiseLevel;
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

    // Методы для получения времени и дней
    function getCurrentTime() {
        return currentTime;
    }

    function getDaysFromStart() {
        return daysFromStart;
    }

    function getTotalTime() {
        return {
            currentTime: currentTime,
            daysFromStart: daysFromStart,
            totalDays: totalDays,
            totalTimePassed: totalTimePassed
        };
    }

    // Функции для управления спутниками
    function addSatellite(trajectory, altitude, speed, name, color) {
        var component = Qt.createComponent("qrc:/Map/Items/Satellite.qml");
        if (component.status === Component.Ready) {
            var satellite = component.createObject(map);
            satellite.setTrajectory(trajectory);
            if (altitude) satellite.setAltitude(altitude);
            if (speed) satellite.speed = speed;
            if (name) satellite.satelliteName = name;
            if (color) satellite.satelliteColor = color;
            satellite.visible = showSatellites;
            satellites.push(satellite);
            map.addMapItem(satellite);
            console.log("Добавлен спутник:", name, "с траекторией из", trajectory.length, "точек");
            return satellite;
        } else {
            console.log("Ошибка создания спутника:", component.errorString());
        }
        return null;
    }

    function clearSatellites() {
        for (var i = 0; i < satellites.length; i++) {
            map.removeMapItem(satellites[i]);
            satellites[i].destroy();
        }
        satellites = [];
        console.log("Все спутники очищены");
    }

    function setSatellitesVisible(visible) {
        showSatellites = visible;
        for (var i = 0; i < satellites.length; i++) {
            if (satellites[i]) {
                satellites[i].visible = visible;
            }
        }
    }

    function toggleSatellitesVisibility() {
        setSatellitesVisible(!showSatellites);
        return showSatellites;
    }

    // Генерация полярной орбиты (проходит через полюса)
    function generatePolarOrbit(centerLng, inclination, altitude, points) {
        var trajectory = [];

        for (var i = 0; i < points; i++) {
            var angle = (i / points) * 2 * Math.PI;

            // Полярная орбита - от 90° до -90° широты
            var lat = 90 * Math.cos(angle); // От +90 до -90
            var lng = centerLng + 180 * Math.sin(angle) * Math.sin(inclination);

            // Нормализация долготы
            while (lng > 180) lng -= 360;
            while (lng < -180) lng += 360;

            trajectory.push(QtPositioning.coordinate(lat, lng));
        }

        return trajectory;
    }

    // Генерация наклонной орбиты
    function generateInclinedOrbit(inclination, startLng, altitude, points) {
        var trajectory = [];

        for (var i = 0; i < points; i++) {
            var angle = (i / points) * 2 * Math.PI;

            var lat = Math.asin(Math.sin(angle) * Math.sin(inclination)) * (180 / Math.PI);
            var lng = startLng + Math.atan2(Math.tan(angle), Math.cos(inclination)) * (180 / Math.PI);

            // Нормализация долготы
            while (lng > 180) lng -= 360;
            while (lng < -180) lng += 360;

            trajectory.push(QtPositioning.coordinate(lat, lng));
        }

        return trajectory;
    }

    // Генерация экваториальной орбиты
    function generateEquatorialOrbit(startLat, altitude, points) {
        var trajectory = [];

        for (var i = 0; i < points; i++) {
            var angle = (i / points) * 2 * Math.PI;

            var lat = startLat;
            var lng = (angle * (180 / Math.PI)) % 360 - 180;

            trajectory.push(QtPositioning.coordinate(lat, lng));
        }

        return trajectory;
    }

    // Генерация орбиты Молния (высокоэллиптическая)
    function generateMolniyaOrbit(inclination, startLng, points) {
        var trajectory = [];
        var eccentricity = 0.74; // Высокий эксцентриситет

        for (var i = 0; i < points; i++) {
            var angle = (i / points) * 2 * Math.PI;

            // Эллиптическая орбита
            var trueAnomaly = angle;
            var lat = Math.asin(Math.sin(trueAnomaly) * Math.sin(inclination)) * (180 / Math.PI);
            var lng = startLng + Math.atan2(Math.tan(trueAnomaly), Math.cos(inclination)) * (180 / Math.PI);

            // Нормализация
            while (lng > 180) lng -= 360;
            while (lng < -180) lng += 360;

            trajectory.push(QtPositioning.coordinate(lat, lng));
        }

        return trajectory;
    }

    function addRandomSatellite() {
        var orbitTypes = ["polar", "inclined", "equatorial", "molniya"];
        var orbitType = orbitTypes[Math.floor(Math.random() * orbitTypes.length)];

        var names = ["Спутник-1", "Метеор-М", "Ресурс-П", "Электро-Л", "Арктика-М", "Глонасс", "Канопус-В"];
        var colors = ["red", "blue", "green", "purple", "orange", "cyan", "magenta"];

        var trajectory;
        var altitude;
        var name = names[Math.floor(Math.random() * names.length)];
        var color = colors[Math.floor(Math.random() * colors.length)];

        switch(orbitType) {
            case "polar":
                trajectory = generatePolarOrbit(
                    Math.random() * 360 - 180, // случайная долгота
                    Math.PI / 2, // строго полярная
                    800 + Math.random() * 1000, // 800-1800 км
                    200
                );
                altitude = 800 + Math.random() * 1000;
                break;

            case "inclined":
                trajectory = generateInclinedOrbit(
                    Math.PI / 4 + Math.random() * Math.PI / 4, // наклон 45-90°
                    Math.random() * 360 - 180,
                    1500 + Math.random() * 10000,
                    150
                );
                altitude = 1500 + Math.random() * 10000;
                break;

            case "equatorial":
                trajectory = generateEquatorialOrbit(
                    Math.random() * 30 - 15, // около экватора
                    35786, // геостационарная высота
                    100
                );
                altitude = 35786;
                break;

            case "molniya":
                trajectory = generateMolniyaOrbit(
                    Math.PI / 3, // наклон 60°
                    Math.random() * 360 - 180,
                    120
                );
                altitude = 40000; // высокая эллиптическая
                break;
        }

        addSatellite(trajectory, altitude, 1.0, name, color);
    }

    // Инициализация демо-спутников при загрузке
    function initializeDemoSatellites() {
        // Очищаем существующие спутники
        clearSatellites();

        // Полярные спутники (проходят через полюса)
        var polarOrbit1 = generatePolarOrbit(30, Math.PI/2, 850, 200);
        addSatellite(polarOrbit1, 850, 1.0, "Метеор-М1", "blue");

        var polarOrbit2 = generatePolarOrbit(-60, Math.PI/2, 900, 200);
        addSatellite(polarOrbit2, 900, 1.2, "Канопус-В", "green");

        var polarOrbit3 = generatePolarOrbit(120, Math.PI/2, 800, 200);
        addSatellite(polarOrbit3, 800, 0.8, "Ресурс-П", "orange");

        // Наклонные орбиты
        var inclinedOrbit1 = generateInclinedOrbit(Math.PI/3, 0, 20000, 150);
        addSatellite(inclinedOrbit1, 20000, 0.5, "Глонасс-М", "purple");

        var inclinedOrbit2 = generateInclinedOrbit(Math.PI/4, 90, 1000, 150);
        addSatellite(inclinedOrbit2, 1000, 1.5, "Ионосфера-М", "cyan");

        // Экваториальная орбита (геостационарная)
        var equatorialOrbit = generateEquatorialOrbit(0, 35786, 100);
        addSatellite(equatorialOrbit, 35786, 0.2, "Электро-Л", "red");

        // Орбита Молния (высокоэллиптическая)
        var molniyaOrbit = generateMolniyaOrbit(Math.PI/3, -90, 120);
        addSatellite(molniyaOrbit, 40000, 0.3, "Арктика-М", "magenta");

        console.log("Инициализировано демо-спутников:", satellites.length);
    }

    // Функция для добавления конкретного типа орбиты
    function addPolarSatellite() {
        var names = ["Полярный-1", "Метеор", "NOAA", "METOP"];
        var colors = ["blue", "cyan", "lightblue", "darkblue"];

        var trajectory = generatePolarOrbit(
            Math.random() * 360 - 180,
            Math.PI / 2,
            700 + Math.random() * 800,
            200
        );

        addSatellite(
            trajectory,
            700 + Math.random() * 800,
            1.0,
            names[Math.floor(Math.random() * names.length)],
            colors[Math.floor(Math.random() * colors.length)]
        );
    }

    function addInclinedSatellite() {
        var names = ["Наклонный-1", "Глонасс", "GPS", "Галилео"];
        var colors = ["purple", "magenta", "darkviolet", "indigo"];

        var trajectory = generateInclinedOrbit(
            Math.PI/6 + Math.random() * Math.PI/3, // 30-90°
            Math.random() * 360 - 180,
            1000 + Math.random() * 30000,
            150
        );

        addSatellite(
            trajectory,
            1000 + Math.random() * 30000,
            0.7 + Math.random() * 0.6,
            names[Math.floor(Math.random() * names.length)],
            colors[Math.floor(Math.random() * colors.length)]
        );
    }

    // Панель управления спутниками
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: 220
        height: 150
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "Управление спутниками:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            Row {
                spacing: 4
                Rectangle {
                    width: 80
                    height: 28
                    color: showSatellites ? "lightgreen" : "lightgray"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: showSatellites ? "Скрыть" : "Показать"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: setSatellitesVisible(!showSatellites)
                    }
                }

                Rectangle {
                    width: 80
                    height: 28
                    color: "lightblue"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Случайный"
                        font.pixelSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: addRandomSatellite()
                    }
                }
            }

            Row {
                spacing: 4
                Rectangle {
                    width: 100
                    height: 28
                    color: "#ADD8E6"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Полярный"
                        font.pixelSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: addPolarSatellite()
                    }
                }

                Rectangle {
                    width: 100
                    height: 28
                    color: "#D8BFD8"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Наклонный"
                        font.pixelSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: addInclinedSatellite()
                    }
                }
            }

            Row {
                spacing: 4
                Rectangle {
                    width: 80
                    height: 28
                    color: "orange"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Демо"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: initializeDemoSatellites()
                    }
                }

                Rectangle {
                    width: 80
                    height: 28
                    color: "lightcoral"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Очистить"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: clearSatellites()
                    }
                }
            }

            Text {
                text: "Активно: " + satellites.length + " спутников"
                font.pixelSize: 10
                color: "darkblue"
                font.bold: true
            }
        }
    }

    // Элементы управления с кнопкой перезагрузки конфигурации
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10
        width: 350
        height: 190
        color: "#E0FFFFFF"
        opacity: 0.9
        border.width: 1
        border.color: "gray"
        radius: 5

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                text: "Управление системой:"
                font.bold: true
                font.pixelSize: 12
                color: "black"
            }

            // Кнопки управления скоростью
            Row {
                spacing: 4
                Repeater {
                    model: speedMultipliers
                    Rectangle {
                        width: 45
                        height: 28
                        color: timeSpeed === modelData ? getSpeedButtonColor(modelData) : "lightgray"
                        radius: 4
                        border.width: timeSpeed === modelData ? 2 : 1
                        border.color: timeSpeed === modelData ? "darkblue" : "gray"

                        Text {
                            anchors.centerIn: parent
                            text: "x" + modelData
                            font.pixelSize: 11
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
                spacing: 6
                Rectangle {
                    width: 90
                    height: 28
                    color: realTimeTimer.running ? "lightgreen" : "lightgray"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: realTimeTimer.running ? "Пауза" : "Старт"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: realTimeTimer.running = !realTimeTimer.running
                    }
                }

                Rectangle {
                    width: 110
                    height: 28
                    color: "lightblue"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "+1 час"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: targetTime = (targetTime + 1) % 24
                    }
                }

                Rectangle {
                    width: 130
                    height: 28
                    color: "lightcoral"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "Обновить JSON"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: loadConfigurationFromJson()
                    }
                }
            }

            // Информация о системе
            Column {
                spacing: 2
                Text {
                    text: "Скорость: " + speedLabels[getSpeedIndex()] + " | Зон: " + noiseCircles.length
                    font.pixelSize: 10
                    color: getSpeedColor()
                    font.bold: true
                }

                Text {
                    text: "1 секунда = " + timeSpeed + " минут"
                    font.pixelSize: 9
                    color: "darkgray"
                }

                Text {
                    text: "Конфигурация: radiation.json"
                    font.pixelSize: 9
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
            case 2400: return "#FF00FF";
            default: return "lightblue";
        }
    }

    Component.onCompleted: {
        console.log("Инициализация с загрузкой из radiation.json...");
        loadConfigurationFromJson();
        updateDayNightCycle();

        // Автоматически создаем демо-спутники при загрузке
        initializeDemoSatellites();
    }
}
