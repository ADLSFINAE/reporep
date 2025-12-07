import QtQuick 2.12
import QtQuick.Window 2.12
import QtLocation 5.12
import QtPositioning 5.12
import QtQml 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

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

    // Свойство для хранения данных radiation.json
    property var radiationData: null

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
    property real satelliteTimeFactor: 1.0

    // Свойства для измерений - ТЕПЕРЬ ХРАНИМ ПО СПУТНИКАМ
    property var measurementsBySatellite: ({}) // Объект: {satelliteName: [measurements]}
    property var allMeasurements: [] // Все измерения (для статистики)
    property bool showMeasurementsPanel: false
    property int selectedSatelliteIndex: -1
    property string selectedSatelliteName: ""

    // Связь с DataStorage из C++
    property var dataStorage: null

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
                        radiationData = config; // Сохраняем данные для спутников
                        processJsonConfiguration(config);
                        console.log("JSON успешно загружен из файла");

                        // После загрузки конфигурации можно добавить спутники
                        if (autoAddSatellitesCheckbox.checked) {
                            addStaticSatellitesForAllCities();
                        }
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
                updateConfigInfo("Файл: " + configFilePath + " | Зон: " + noiseCircles.length + " | Версия: " + (config.version || "1.0"));
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
                text: "Спутников: " + satellites.length + " | Измерений: " + allMeasurements.length
                font.pixelSize: 9
                color: "red"
                font.bold: true
            }

            Text {
                text: "Данные в C++: " + (dataStorage ? dataStorage.getAllMeasurements().length : 0) + " записей"
                font.pixelSize: 9
                color: "darkblue"
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

    // Функция для обновления скорости спутников
    function updateSatellitesSpeed() {
        var h = currentTime;
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

        satelliteTimeFactor = timeFactor;

        // Обновляем все спутники
        for (var i = 0; i < satellites.length; i++) {
            var satellite = satellites[i];
            if (satellite && typeof satellite.setGlobalTime === 'function') {
                satellite.setGlobalTime(currentTime);
            }
        }
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

        // ОБНОВЛЯЕМ СКОРОСТЬ СПУТНИКОВ
        updateSatellitesSpeed();

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

            // Устанавливаем ссылку на карту
            satellite.mapReference = this;

            // Устанавливаем начальное время
            satellite.setGlobalTime(currentTime);

            // Подключаем сигнал измерения
            satellite.measurementTaken.connect(function(measurement) {
                // Добавляем имя спутника в измерение
                measurement.satelliteName = name;
                addMeasurement(measurement, name);
            });

            satellite.visible = showSatellites;
            satellites.push(satellite);
            map.addMapItem(satellite);

            // Инициализируем хранилище для измерений этого спутника
            if (!measurementsBySatellite[name]) {
                measurementsBySatellite[name] = [];
            }

            // Обновляем селектор спутников
            updateSatelliteSelector();

            console.log("Добавлен спутник:", name, "высота:", altitude, "км");
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
        measurementsBySatellite = {};
        allMeasurements = [];

        // Очищаем данные в C++ хранилище
        if (dataStorage) {
            dataStorage.clearAllData();
        }

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
        var name = "Случайный-" + (satellites.length + 1);
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

        // Добавляем статичные спутники
        if (autoAddSatellitesCheckbox.checked && radiationData) {
            addStaticSatellitesForAllCities();
        } else {
            // Старый код для демо
            addStaticMoscowSatellite();
            addStaticSPBSatellite();
        }

        // Обновляем селектор спутников
        updateSatelliteSelector();
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

        var name = names[Math.floor(Math.random() * names.length)] + "-" + (satellites.length + 1);
        addSatellite(
            trajectory,
            700 + Math.random() * 800,
            1.0,
            name,
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

        var name = names[Math.floor(Math.random() * names.length)] + "-" + (satellites.length + 1);
        addSatellite(
            trajectory,
            1000 + Math.random() * 30000,
            0.7 + Math.random() * 0.6,
            name,
            colors[Math.floor(Math.random() * colors.length)]
        );
    }

    // Панель управления спутниками
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: 260
        height: 180
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

                // Кнопка для добавления спутников для всех городов
                Rectangle {
                    width: 80
                    height: 28
                    color: "#FF00FF"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "88 городов"
                        font.pixelSize: 9
                        font.bold: true
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: addStaticSatellitesForAllCities()
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

            // Чекбокс для автоматического добавления спутников
            Row {
                spacing: 5
                Rectangle {
                    width: 16
                    height: 16
                    color: autoAddSatellitesCheckbox.checked ? "green" : "lightgray"
                    border.width: 1
                    border.color: "gray"
                    radius: 3

                    MouseArea {
                        anchors.fill: parent
                        onClicked: autoAddSatellitesCheckbox.checked = !autoAddSatellitesCheckbox.checked
                    }
                }

                Text {
                    id: autoAddSatellitesCheckbox
                    property bool checked: true
                    text: "Автоматически добавлять спутники для городов"
                    font.pixelSize: 9
                    color: "darkblue"
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

    // Панель измерений спутников
    Rectangle {
        id: measurementsPanel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 330
        width: 500
        height: 460  // Увеличена высота панели до 460
        color: "#E0FFFFFF"
        opacity: 0.95
        border.width: 1
        border.color: "gray"
        radius: 5
        visible: showMeasurementsPanel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "📊 Измерения спутников"
                    font.bold: true
                    font.pixelSize: 14
                    color: "black"
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "transparent"
                }

                Text {
                    text: "✕"
                    font.pixelSize: 16
                    color: "red"
                    font.bold: true

                    MouseArea {
                        anchors.fill: parent
                        onClicked: showMeasurementsPanel = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "gray"
            }

            // Селектор спутника
            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "Спутник:"
                    font.pixelSize: 11
                    color: "black"
                }

                ComboBox {
                    id: satelliteSelector
                    Layout.fillWidth: true
                    model: satellites.map(function(sat) {
                        return sat ? sat.satelliteName : "";
                    }).filter(function(name) { return name; })
                    onCurrentIndexChanged: {
                        selectedSatelliteIndex = currentIndex;
                        if (currentIndex >= 0 && currentIndex < satellites.length) {
                            selectedSatelliteName = satellites[currentIndex].satelliteName;
                        }
                        updateMeasurementsView();
                    }
                }

                Text {
                    text: "Измерений: " + (selectedSatelliteName ?
                        (measurementsBySatellite[selectedSatelliteName] ?
                         measurementsBySatellite[selectedSatelliteName].length : 0) : 0)
                    font.pixelSize: 10
                    color: "darkblue"
                }
            }

            // Таблица измерений
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#F8F8F8"
                border.width: 1
                border.color: "#CCCCCC"
                radius: 3

                ListView {
                    id: measurementsList
                    anchors.fill: parent
                    anchors.margins: 2
                    clip: true
                    model: ListModel { id: measurementsModel }

                    delegate: Rectangle {
                        width: measurementsList.width
                        height: 115  // УВЕЛИЧЕНО до 115 пикселей (было 110)
                        color: index % 2 === 0 ? "#F0F8FF" : "#FFFFFF"
                        border.width: 0.5
                        border.color: "#E0E0E0"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 3  // Увеличены отступы до 12px
                            spacing: 3

                            Column {
                                width: parent.width * 0.7
                                spacing: 5  // Увеличен интервал между строками до 5px

                                Text {
                                    text: model.city
                                    font.bold: true
                                    font.pixelSize: 18
                                    color: getNoiseColor(model.noiseLevel)
                                    elide: Text.ElideRight
                                    width: parent.width
                                    style: Text.Outline
                                    styleColor: "#80000000"
                                    height: 25  // Увеличена высота до 25px
                                }

                                Text {
                                    text: "Спутник: " + model.satellite
                                    font.pixelSize: 12
                                    color: "darkblue"
                                    height: 19  // Увеличена высота до 19px
                                }

                                Text {
                                    text: "Координаты: " + model.lat.toFixed(4) + ", " + model.lng.toFixed(4)
                                    font.pixelSize: 11
                                    color: "gray"
                                    height: 17  // Увеличена высота до 17px
                                }

                                Text {
                                    text: "Уровень: " + model.noiseLevel.toFixed(1) + " дБм | Высота: " + model.altitude.toFixed(0) + " км"
                                    font.pixelSize: 11
                                    color: "darkblue"
                                    height: 17  // Увеличена высота до 17px
                                }

                                Text {
                                    text: "Время: " + model.time + " | Расстояние: " + (model.distance/1000).toFixed(1) + " км"
                                    font.pixelSize: 10
                                    color: "darkgreen"
                                    height: 16  // Увеличена высота до 16px
                                }
                            }

                            Column {
                                width: parent.width * 0.3
                                spacing: 6

                                Rectangle {
                                    width: 75
                                    height: 30  // Увеличена высота до 30px
                                    color: getNoiseColor(model.noiseLevel)
                                    radius: 4
                                    border.width: 1
                                    border.color: "white"

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.noiseLevel.toFixed(1)
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "white"
                                    }
                                }

                                Text {
                                    text: "Влияние: " + model.influence.toFixed(2) + "x"
                                    font.pixelSize: 11
                                    color: "purple"
                                    height: 18  // Увеличена высота до 18px
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Центрируем карту на точке измерения
                                map.center = QtPositioning.coordinate(model.lat, model.lng);
                                map.zoomLevel = 12;
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOn
                        width: 12
                    }
                }
            }

            // Панель управления измерениями
            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    width: 100
                    height: 32
                    color: "lightcoral"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: "Очистить все"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: clearAllMeasurements()
                    }
                }

                Rectangle {
                    width: 100
                    height: 32
                    color: "#4CAF50"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: "Экспорт CSV"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: exportAllMeasurements()
                    }
                }

                Rectangle {
                    width: 100
                    height: 32
                    color: "orange"
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: "Обновить"
                        font.pixelSize: 11
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: updateMeasurementsView()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Всего: " + allMeasurements.length + " измерений"
                    font.pixelSize: 12
                    color: "darkblue"
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Статистика
            Rectangle {
                Layout.fillWidth: true
                height: 50  // Увеличена высота до 50px
                color: "#F0F0F0"
                radius: 3
                border.width: 1
                border.color: "#DDDDDD"

                Row {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 15

                    Text {
                        text: "🏙️ Городов: " + getUniqueCitiesCount()
                        font.pixelSize: 11
                        color: "darkgreen"
                    }

                    Text {
                        text: "🛰️ Спутников: " + satellites.length
                        font.pixelSize: 11
                        color: "darkred"
                    }

                    Text {
                        text: "📈 Макс: " + getMaxNoise().toFixed(1)
                        font.pixelSize: 11
                        color: "#FF0000"
                    }

                    Text {
                        text: "📉 Мин: " + getMinNoise().toFixed(1)
                        font.pixelSize: 11
                        color: "#0000FF"
                    }
                }
            }
        }
    }

    // Кнопка для показа/скрытия панели измерений
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 330
        width: 50
        height: 50
        color: showMeasurementsPanel ? "#FF4444" : "#44AA44"
        radius: 25
        opacity: 0.9

        Text {
            anchors.centerIn: parent
            text: showMeasurementsPanel ? "✕" : "📊"
            font.pixelSize: 22
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                showMeasurementsPanel = !showMeasurementsPanel;
                if (showMeasurementsPanel) {
                    updateMeasurementsView();
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

    // Функция для добавления измерения в таблицу
    function addMeasurement(measurement, satelliteName) {
        if (!satelliteName) {
            satelliteName = measurement.satelliteName || "Неизвестный спутник";
        }

        var measurementTime = measurement.measurementTime;
        var timeStr = measurementTime.toISOString();

        // Сохраняем в QML для отображения
        var measurementData = {
            satellite: satelliteName,
            city: measurement.cityName,
            lat: measurement.latitude,
            lng: measurement.longitude,
            noiseLevel: measurement.noiseLevel,
            time: timeStr,
            distance: measurement.distanceToCity || 0,
            altitude: measurement.altitude || 0,
            influence: measurement.influenceFactor || 1.0
        };

        // Добавляем в глобальный список
        allMeasurements.push(measurementData);

        // Инициализируем массив для спутника, если его нет
        if (!measurementsBySatellite[satelliteName]) {
            measurementsBySatellite[satelliteName] = [];
        }

        // Добавляем измерение в массив спутника
        measurementsBySatellite[satelliteName].push(measurementData);

        // Ограничиваем количество записей для спутника
        if (measurementsBySatellite[satelliteName].length > 100) {
            measurementsBySatellite[satelliteName].shift();
        }

        // ПЕРЕДАЕМ ДАННЫЕ В C++ DataStorage
        if (dataStorage) {
            dataStorage.addMeasurement(
                satelliteName,
                timeStr,
                measurement.latitude,
                measurement.longitude,
                measurement.noiseLevel,
                measurement.cityName,
                measurement.altitude || 0,
                measurement.distanceToCity || 0,
                measurement.influenceFactor || 1.0
            );
        }

        // Если панель видна и выбран этот спутник, обновляем отображение
        if (showMeasurementsPanel && selectedSatelliteName === satelliteName) {
            updateMeasurementsView();
        }

        console.log("📡 Измерение от " + satelliteName + ":",
                    measurement.cityName, measurement.noiseLevel.toFixed(1) + "дБм");
    }

    // Функция для обновления представления измерений
    function updateMeasurementsView() {
        measurementsModel.clear();

        if (selectedSatelliteName && measurementsBySatellite[selectedSatelliteName]) {
            var satMeasurements = measurementsBySatellite[selectedSatelliteName];

            // Показываем последние 50 измерений в обратном порядке (последние сверху)
            var startIndex = Math.max(0, satMeasurements.length - 50);
            for (var i = satMeasurements.length - 1; i >= startIndex; i--) {
                var m = satMeasurements[i];
                measurementsModel.append(m);
            }
        } else {
            // Показываем все измерения (последние 50)
            var startIndex = Math.max(0, allMeasurements.length - 50);
            for (var j = allMeasurements.length - 1; j >= startIndex; j--) {
                var m2 = allMeasurements[j];
                var time = new Date(m2.time);
                var timeStr2 = time.getHours().toString().padStart(2, '0') + ":" +
                              time.getMinutes().toString().padStart(2, '0') + ":" +
                              time.getSeconds().toString().padStart(2, '0');

                measurementsModel.append({
                    satellite: m2.satellite,
                    city: m2.city,
                    lat: m2.lat,
                    lng: m2.lng,
                    noiseLevel: m2.noiseLevel,
                    time: timeStr2,
                    distance: m2.distance || 0,
                    altitude: m2.altitude || 0,
                    influence: m2.influence || 1.0
                });
            }
        }
    }

    // Функция для очистки всех измерений
    function clearAllMeasurements() {
        measurementsModel.clear();
        allMeasurements = [];
        measurementsBySatellite = {};

        // Очищаем данные в C++ хранилище
        if (dataStorage) {
            dataStorage.clearAllData();
        }

        // Также очищаем измерения у всех спутников
        for (var i = 0; i < satellites.length; i++) {
            if (satellites[i] && typeof satellites[i].clearMeasurements === 'function') {
                satellites[i].clearMeasurements();
            }
        }

        updateStatsDisplay();
        console.log("Все измерения очищены");
    }

    // Функция для экспорта всех измерений через C++
    function exportAllMeasurements() {
        if (allMeasurements.length === 0) {
            console.log("Нет данных для экспорта");
            return;
        }

        if (dataStorage) {
            var filename = "satellite_measurements_" +
                          new Date().toISOString().slice(0,10).replace(/-/g, '') + "_" +
                          allMeasurements.length + "_records.csv";

            if (dataStorage.exportToCSV(filename)) {
                console.log("📤 Экспортировано через C++:", allMeasurements.length, "измерений");
            } else {
                console.log("Ошибка экспорта через C++");
            }
        } else {
            console.log("DataStorage не доступен");
            // Резервный экспорт через JavaScript
            exportAllMeasurementsJS();
        }
    }

    // Резервная функция экспорта через JavaScript
    function exportAllMeasurementsJS() {
        if (allMeasurements.length === 0) {
            console.log("Нет данных для экспорта");
            return;
        }

        var csvContent = "data:text/csv;charset=utf-8,\uFEFF"; // BOM для UTF-8
        csvContent += "Спутник;Время;Широта;Долгота;Уровень излучения (дБм);Город;Высота (км);Расстояние до города (м);Фактор влияния\n";

        for (var i = 0; i < allMeasurements.length; i++) {
            var m = allMeasurements[i];
            var time = new Date(m.time);
            var timeStr = time.toISOString().replace('T', ' ').substr(0, 19);

            csvContent += '"' + m.satellite + '";"' +
                         timeStr + '";' +
                         m.lat + ';' + m.lng + ';' +
                         m.noiseLevel.toFixed(1) + ';"' +
                         m.city + '";' +
                         (m.altitude || 0).toFixed(1) + ';' +
                         (m.distance || 0).toFixed(1) + ';' +
                         (m.influence || 1.0).toFixed(3) + '\n';
        }

        var encodedUri = encodeURI(csvContent);
        var link = document.createElement("a");
        link.setAttribute("href", encodedUri);
        link.setAttribute("download", "satellite_measurements_" +
                         new Date().toISOString().slice(0,10) + "_" +
                         allMeasurements.length + "_records.csv");
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        console.log("📤 Экспортировано измерений (JS):", allMeasurements.length);
    }

    // Функция для получения цвета по уровню шума
    function getNoiseColor(noiseLevel) {
        if (noiseLevel > -70) return "#FF0000";
        if (noiseLevel > -80) return "#FF8800";
        if (noiseLevel > -90) return "#FFFF00";
        if (noiseLevel > -100) return "#00FF00";
        return "#0000FF";
    }

    // Функция для подсчета уникальных городов
    function getUniqueCitiesCount() {
        var cities = new Set();
        for (var i = 0; i < allMeasurements.length; i++) {
            if (allMeasurements[i].city !== "Открытая местность") {
                cities.add(allMeasurements[i].city);
            }
        }
        return cities.size;
    }

    // Функция для получения максимального уровня шума
    function getMaxNoise() {
        if (allMeasurements.length === 0) return -100;
        var max = -200;
        for (var i = 0; i < allMeasurements.length; i++) {
            if (allMeasurements[i].noiseLevel > max) {
                max = allMeasurements[i].noiseLevel;
            }
        }
        return max;
    }

    // Функция для получения минимального уровня шума
    function getMinNoise() {
        if (allMeasurements.length === 0) return -100;
        var min = 0;
        for (var i = 0; i < allMeasurements.length; i++) {
            if (allMeasurements[i].noiseLevel < min) {
                min = allMeasurements[i].noiseLevel;
            }
        }
        return min;
    }

    // Функция для обновления селектора спутников
    function updateSatelliteSelector() {
        var names = satellites.map(function(sat) {
            return sat ? sat.satelliteName : "";
        }).filter(function(name) { return name; });

        satelliteSelector.model = names;

        if (names.length > 0) {
            if (selectedSatelliteIndex === -1 || selectedSatelliteIndex >= names.length) {
                selectedSatelliteIndex = 0;
                satelliteSelector.currentIndex = 0;
            }
            if (selectedSatelliteIndex < satellites.length) {
                selectedSatelliteName = satellites[selectedSatelliteIndex].satelliteName;
            }
        } else {
            selectedSatelliteIndex = -1;
            selectedSatelliteName = "";
        }
    }

    // ============================================================================
    // УНИВЕРСАЛЬНЫЕ ФУНКЦИИ ДЛЯ ДОБАВЛЕНИЯ СТАТИЧНЫХ СПУТНИКОВ
    // ============================================================================

    // Функция для добавления статичных спутников для всех городов из radiation.json
    function addStaticSatellitesForAllCities() {
        if (!radiationData || !radiationData.circles) {
            console.log("Ошибка: Данные radiation.json не загружены");
            loadConfigurationFromJson();
            return;
        }

        var cities = radiationData.circles;
        var satellitesAdded = 0;
        var skippedCities = [];

        console.log("Добавление статичных спутников для " + cities.length + " городов...");

        // Проходим по всем городам
        for (var i = 0; i < cities.length; i++) {
            var city = cities[i];

            // Пропускаем выключенные города
            if (!city.enabled) {
                skippedCities.push(city.id + " (выключен)");
                continue;
            }

            // Добавляем спутник для каждого города
            var satellite = addStaticSatelliteForCity(city);
            if (satellite) {
                satellitesAdded++;
            } else {
                skippedCities.push(city.id + " (ошибка создания)");
            }
        }

        // Обновляем селектор спутников
        updateSatelliteSelector();

        console.log("✅ Добавлено статичных спутников: " + satellitesAdded +
                   " из " + cities.length + " городов");

        if (skippedCities.length > 0) {
            console.log("Пропущенные города:", skippedCities.join(", "));
        }

        // Обновляем статистику
        updateStatsDisplay();

        return satellitesAdded;
    }

    // Функция для получения DataStorage - чтобы спутники могли получить доступ
    function getDataStorage() {
        return dataStorage;
    }

    // Функция для передачи DataStorage спутникам
    function passDataStorageToSatellites() {
        console.log("🔄 Передача DataStorage всем спутникам...");
        console.log("   Всего спутников:", satellites.length);
        console.log("   dataStorage доступен:", dataStorage !== null);

        var successCount = 0;
        var failCount = 0;

        for (var i = 0; i < satellites.length; i++) {
            var satellite = satellites[i];
            if (satellite && dataStorage) {
                if (typeof satellite.setDataStorage === 'function') {
                    satellite.setDataStorage(dataStorage);
                    successCount++;
                    console.log("   ✅ DataStorage передан спутнику:", satellite.satelliteName);
                } else {
                    failCount++;
                    console.log("   ❌ Спутник не имеет метода setDataStorage:", satellite.satelliteName);
                }
            } else {
                failCount++;
                console.log("   ❌ Спутник или dataStorage недоступны:",
                           satellite ? satellite.satelliteName : "null",
                           dataStorage ? "dataStorage OK" : "dataStorage null");
            }
        }

        console.log("📊 Итог передачи DataStorage:");
        console.log("   Успешно:", successCount);
        console.log("   Неудачно:", failCount);
    }

    // Функция для добавления статичного спутника для конкретного города
    function addStaticSatelliteForCity(cityData) {
        var component = Qt.createComponent("qrc:/Map/Items/StaticSatellite.qml");

        if (component.status !== Component.Ready) {
            console.log("Ошибка создания компонента спутника:", component.errorString());
            return null;
        }

        // Создаем спутник
        var satellite = component.createObject(map);

        // Устанавливаем параметры из данных города
        satellite.latitude = cityData.latitude;
        satellite.longitude = cityData.longitude;
        satellite.altitude = 35786; // Геостационарная орбита

        // Извлекаем название города из полного заголовка
        var titleParts = cityData.title.split(" - ");
        var cityName = titleParts[0];
        var satelliteName = cityName + " Монитор";
        satellite.satelliteName = satelliteName;

        // ПЕРЕДАЕМ ДАННЫЕ ГОРОДА СПУТНИКУ
        satellite.setCityData(cityData);

        // Устанавливаем цвет в зависимости от уровня излучения
        satellite.satelliteColor = getSatelliteColorForNoiseLevel(cityData.baseNoiseLevel);
        satellite.mapReference = this;

        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Передаем dataStorage прямо в спутник
        console.log("🔄 Передача DataStorage спутнику:", satelliteName);
        console.log("   dataStorage доступен:", dataStorage !== null);

        if (dataStorage && typeof satellite.setDataStorage === 'function') {
            satellite.setDataStorage(dataStorage);
            console.log("✅ DataStorage передан статичному спутнику:", satelliteName);

            // Тестируем соединение
            try {
                if (typeof dataStorage.testConnection === 'function') {
                    dataStorage.testConnection();
                }
            } catch (e) {
                console.log("⚠️ Ошибка тестирования DataStorage:", e);
            }
        } else {
            console.log("❌ Не удалось передать DataStorage спутнику:", satelliteName);
            console.log("   dataStorage:", dataStorage ? "доступен" : "null");
            console.log("   setDataStorage метод:", typeof satellite.setDataStorage === 'function' ? "доступен" : "недоступен");
        }

        // Подключаем сигнал измерения
        satellite.measurementTaken.connect(function(measurement) {
            // Убедимся, что имя спутника передано
            measurement.satelliteName = satelliteName;
            addMeasurement(measurement, satelliteName);
        });

        satellite.visible = showSatellites;
        satellites.push(satellite);
        map.addMapItem(satellite);

        // Инициализируем хранилище для измерений этого спутника
        if (!measurementsBySatellite[satelliteName]) {
            measurementsBySatellite[satelliteName] = [];
        }

        console.log("✅ Добавлен спутник над " + cityName + " (ID: " + cityData.id + ")");
        return satellite;
    }

    // Вспомогательная функция для определения цвета спутника по уровню шума
    function getSatelliteColorForNoiseLevel(noiseLevel) {
        if (noiseLevel >= -60) return "#FF0000";     // Очень высокий - красный
        if (noiseLevel >= -70) return "#FF4400";     // Высокий - оранжевый
        if (noiseLevel >= -80) return "#FF8800";     // Средний - желто-оранжевый
        return "#FFCC00";                            // Низкий - желтый
    }

    // Функция для добавления спутника для конкретного города по ID
    function addStaticSatelliteById(cityId) {
        if (!radiationData || !radiationData.circles) {
            console.log("Ошибка: Данные radiation.json не загружены");
            return null;
        }

        for (var i = 0; i < radiationData.circles.length; i++) {
            var city = radiationData.circles[i];
            if (city.id === cityId) {
                return addStaticSatelliteForCity(city);
            }
        }

        console.log("Город с ID " + cityId + " не найден");
        return null;
    }

    // ============================================================================
    // СТАРЫЕ ФУНКЦИИ (ОСТАВЛЕНЫ ДЛЯ ОБРАТНОЙ СОВМЕСТИМОСТИ)
    // ============================================================================

    // Функция для добавления статичного спутника над Москвой
    function addStaticMoscowSatellite() {
        return addStaticSatelliteById("moscow");
    }

    // Функция для добавления статичного спутника над Санкт-Петербургом
    function addStaticSPBSatellite() {
        return addStaticSatelliteById("saint_petersburg");
    }

    // Функция для обновления статистики
    function updateStatsDisplay() {
        // Можно добавить дополнительную логику обновления статистики
        if (dataStorage) {
            var stats = dataStorage.getStatistics();
            console.log("Статистика данных в C++:", JSON.stringify(stats));
        }
    }

    Component.onCompleted: {
        console.log("Инициализация с загрузкой из radiation.json...");

        // Проверяем доступность DataStorage при запуске
        console.log("dataStorage доступен из QML:", dataStorage !== null);

        if (dataStorage) {
            console.log("✅ DataStorage доступен из QML");
            console.log("Данных в хранилище:", dataStorage.getAllMeasurements().length);

            // Тестируем методы
            try {
                if (typeof dataStorage.testConnection === 'function') {
                    dataStorage.testConnection();
                }
                console.log("getAllSatelliteNames доступен:", typeof dataStorage.getAllSatelliteNames === 'function');
                console.log("getTotalMeasurementCount доступен:", typeof dataStorage.getTotalMeasurementCount === 'function');
            } catch (e) {
                console.log("⚠️ Ошибка тестирования методов:", e);
            }
        } else {
            console.log("❌ DataStorage НЕ доступен из QML - проверьте передачу из C++");
        }

        loadConfigurationFromJson();
        updateDayNightCycle();

        // Автоматически создаем демо-спутники при загрузке
        initializeDemoSatellites();

        // После добавления спутников передаем им DataStorage
        Qt.callLater(function() {
            passDataStorageToSatellites();
        });
    }
}
