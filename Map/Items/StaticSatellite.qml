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

    // Связь с DataStorage из C++
    property var dataStorage: null

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

    // НОВЫЙ ФУНКЦИОНАЛ: Функция для установки DataStorage
    function setDataStorage(storage) {
        console.log("📡 StaticSatellite.setDataStorage вызван:",
                   storage !== null ? "✅ storage доступен" : "❌ storage null");
        dataStorage = storage;

        // Тестируем соединение
        if (dataStorage) {
            try {
                console.log("🔍 Тестируем методы dataStorage...");
                // Проверяем доступные методы
                console.log(" - addMeasurement доступен:", typeof dataStorage.addMeasurement === 'function');
                console.log(" - testConnection доступен:", typeof dataStorage.testConnection === 'function');

                if (typeof dataStorage.testConnection === 'function') {
                    dataStorage.testConnection();
                }

                console.log("✅ StaticSatellite получил DataStorage для", satelliteName);
            } catch (e) {
                console.log("⚠️ Ошибка теста DataStorage:", e);
            }
        } else {
            console.log("❌ StaticSatellite: DataStorage не установлен для", satelliteName);
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
        if (!mapReference) {
            console.log("Ошибка: mapReference не установлен");
            return;
        }

        // Создаем объект измерения
        var measurement = {
            satelliteName: satelliteName,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            measurementTime: new Date(),
            influenceFactor: 1.0,
            cityName: "",
            distanceToCity: 0,
            noiseLevel: baseNoiseLevel
        };

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
            measurement.cityName = "Координаты: " + latitude.toFixed(4) + ", " + longitude.toFixed(4);
        }

        measurement.distanceToCity = 0; // Спутник прямо над городом

        // Базовый уровень шума с вариациями
        var timeOfDayVariation = calculateTimeOfDayVariation();
        var randomVariation = (Math.random() * 4) - 2; // ±2 дБм случайная вариация

        var noiseLevel = baseNoiseLevel + timeOfDayVariation + randomVariation;

        // Учитываем влияние небесных тел
        measurement.noiseLevel = noiseLevel * measurement.influenceFactor;

        // Корректируем значение
        if (measurement.noiseLevel > -50) {
            measurement.noiseLevel = -50 + (Math.random() * 5);
        }

        // Сигнализируем о новом измерении
        measurementTaken(measurement);

        // ПЕРЕДАЕМ ДАННЫЕ В C++ DataStorage
        transferMeasurementToCpp(measurement);

        // Обновляем кружок города в реальном времени
        updateCityNoiseCircle(measurement.noiseLevel);

        console.log("📡 StaticSatellite:", satelliteName,
                    measurement.cityName, measurement.noiseLevel.toFixed(1) + "дБм",
                    "влияние:", measurement.influenceFactor.toFixed(2) + "x");
    }

    // Функция для передачи измерения в C++ DataStorage
    function transferMeasurementToCpp(measurement) {
        // Сначала используем локальное свойство dataStorage
        var storage = dataStorage;

        // Если не установлено, пробуем получить из mapReference
        if (!storage && mapReference) {
            if (typeof mapReference.getDataStorage === 'function') {
                storage = mapReference.getDataStorage();
            } else if (mapReference.dataStorage) {
                storage = mapReference.dataStorage;
            }
        }

        // Пробуем глобальный доступ
        if (!storage && typeof dataStorageManager !== 'undefined') {
            storage = dataStorageManager;
        }

        if (storage && typeof storage.addMeasurement === 'function') {
            try {
                var timeStr = measurement.measurementTime.toISOString();

                storage.addMeasurement(
                    measurement.satelliteName,
                    timeStr,
                    measurement.latitude,
                    measurement.longitude,
                    measurement.noiseLevel,
                    measurement.cityName,
                    measurement.altitude || 0,
                    measurement.distanceToCity || 0,
                    measurement.influenceFactor || 1.0
                );

                console.log("✅ Данные переданы в C++ от спутника:", measurement.satelliteName);
            } catch (e) {
                console.log("❌ Ошибка передачи в C++:", e);
            }
        } else {
            console.log("⚠️ DataStorage не доступен для статичного спутника:", satelliteName);
            console.log("   storage:", storage);
            console.log("   addMeasurement доступен:", storage ? typeof storage.addMeasurement === 'function' : "storage null");
        }
    }

    function calculateTimeFactor() {
        if (!mapReference) return 1.0;
        var h = mapReference.currentTime || 6.0;
        var timeFactor;

        if (h >= 6 && h < 18) {
            timeFactor = 1.15;
        } else if (h >= 4 && h < 6) {
            timeFactor = 1.02;
        } else if (h >= 18 && h < 20) {
            timeFactor = 1.02;
        } else {
            timeFactor = 1.0;
        }

        return timeFactor;
    }

    function calculateTimeOfDayVariation() {
        if (!mapReference) return 0;
        var h = mapReference.currentTime || 6.0;

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

        for (var i = 0; i < mapReference.noiseCircles.length; i++) {
            var circle = mapReference.noiseCircles[i];
            if (circle) {
                var isCurrentCity = false;

                if (cityId && circle.circleId === cityId) {
                    isCurrentCity = true;
                } else if (cityName && circle.title && circle.title.indexOf(cityName) !== -1) {
                    isCurrentCity = true;
                } else if (cityFullTitle && circle.title === cityFullTitle) {
                    isCurrentCity = true;
                }

                if (isCurrentCity) {
                    circle.noiseLevel = noiseLevel;
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

        circle.opacity = 0.8;
    }

    function getMeasurements() {
        return measurements;
    }

    function clearMeasurements() {
        measurements = [];
    }

    // Функция для установки данных города
    function setCityData(cityData) {
        if (cityData) {
            cityId = cityData.id || "";
            cityName = extractCityNameFromTitle(cityData.title || "");
            cityFullTitle = cityData.title || "";
            baseNoiseLevel = cityData.baseNoiseLevel || -58;

            if (cityName && cityName !== "") {
                satelliteName = cityName + " Монитор";
            }

            updateSatelliteColor(baseNoiseLevel);
        }
    }

    function extractCityNameFromTitle(title) {
        var parts = title.split(" - ");
        if (parts.length > 0) {
            return parts[0].trim();
        }
        return title;
    }

    function updateSatelliteColor(noiseLevel) {
        if (noiseLevel > -60) {
            satelliteColor = "#FF0000"; // Очень высокий - красный
        } else if (noiseLevel > -70) {
            satelliteColor = "#FF4400"; // Высокий - оранжево-красный
        } else if (noiseLevel > -75) {
            satelliteColor = "#FF8800"; // Повышенный - оранжевый
        } else if (noiseLevel > -80) {
            satelliteColor = "#FFCC00"; // Средний - желто-оранжевый
        } else if (noiseLevel > -85) {
            satelliteColor = "#FFFF00"; // Низкий - желтый
        } else if (noiseLevel > -90) {
            satelliteColor = "#AAFF00"; // Очень низкий - желто-зеленый
        } else if (noiseLevel > -95) {
            satelliteColor = "#00FF00"; // Минимальный - зеленый
        } else {
            satelliteColor = "#00AAFF"; // Фоновый - синий
        }
    }

    Component.onCompleted: {
        // Пытаемся получить DataStorage из различных источников
        var storage = null;

        // 1. Из mapReference
        if (mapReference) {
            if (typeof mapReference.getDataStorage === 'function') {
                storage = mapReference.getDataStorage();
                console.log("✅ Получили DataStorage через getDataStorage() для", satelliteName);
            } else if (mapReference.dataStorage) {
                storage = mapReference.dataStorage;
                console.log("✅ Получили DataStorage через mapReference.dataStorage для", satelliteName);
            }
        }

        // 2. Из глобального контекста
        if (!storage && typeof dataStorageManager !== 'undefined') {
            storage = dataStorageManager;
            console.log("✅ Получили DataStorage из глобального контекста для", satelliteName);
        }

        // 3. Попробуем напрямую из корневого объекта
        if (!storage && mapReference && typeof mapReference.dataStorage !== 'undefined') {
            storage = mapReference.dataStorage;
            console.log("✅ Получили DataStorage напрямую для", satelliteName);
        }

        if (storage) {
            dataStorage = storage;
            console.log("✅ StaticSatellite инициализирован с DataStorage для", satelliteName);
        } else {
            console.log("⚠️ StaticSatellite не может получить доступ к DataStorage для", satelliteName);
            console.log("   Доступные источники:");
            console.log("   - mapReference:", mapReference ? "есть" : "нет");
            console.log("   - dataStorageManager:", typeof dataStorageManager !== 'undefined' ? "есть" : "нет");
        }

        updateSatelliteColor(baseNoiseLevel);
    }

    Component.onDestruction: {
        clearMeasurements();
    }
}
