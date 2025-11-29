import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQml 2.12

Item {
    width: 1200
    height: 800

    property date startDate: new Date(2025, 0, 1) // 1 января 2025
    property date currentDateTime: new Date(2025, 0, 1)
    property double solarInfluence: 1.0
    property double lunarInfluence: 1.0
    property double planetaryInfluence: 1.0
    property real daysFromStart: 0
    property real currentHour: 6.0
    property string timeOfDay: "Утро"

    // Эллиптические параметры орбиты
    property real earthOrbitRadiusX: 300
    property real earthOrbitRadiusY: 200
    property real moonOrbitRadius: 50
    property real earthAngle: 0
    property real moonAngle: 0

    // Таймер для постоянного обновления позиций
    Timer {
        id: updateTimer
        interval: 100 // Обновление каждые 100 мс
        running: true
        repeat: true
        onTriggered: updatePositions()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000010"

        // Солнце в центре
        Rectangle {
            id: sun
            width: 80
            height: 80
            radius: width / 2
            color: "#FFFF00"
            border.color: "#FF6600"
            border.width: 4
            anchors.centerIn: parent

            // Солнечная корона
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.5
                height: parent.height * 1.5
                radius: width / 2
                color: "transparent"
                border.color: "#FF8800"
                border.width: 3
                opacity: 0.6
            }
        }

        // Эллиптическая орбита Земли
        Canvas {
            anchors.centerIn: parent
            width: earthOrbitRadiusX * 2
            height: earthOrbitRadiusY * 2
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = "#444477";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.ellipse(0, 0, width, height);
                ctx.stroke();
            }
        }

        // Земля
        Rectangle {
            id: earth
            width: 35
            height: 35
            radius: width / 2
            color: "#3366FF"
            border.color: "#22AA22"
            border.width: 2

            x: sun.x + earthOrbitRadiusX * Math.cos(earthAngle) - width / 2
            y: sun.y + earthOrbitRadiusY * Math.sin(earthAngle) - height / 2

            // Орбита Луны
            Rectangle {
                id: moonOrbit
                anchors.centerIn: parent
                width: moonOrbitRadius * 2
                height: moonOrbitRadius * 2
                radius: width / 2
                color: "transparent"
                border.color: "#666666"
                border.width: 1
            }

            // Луна
            Rectangle {
                id: moon
                width: 15
                height: 15
                radius: width / 2
                color: "#CCCCCC"
                border.color: "#AAAAAA"
                border.width: 1

                x: moonOrbit.width / 2 + moonOrbitRadius * Math.cos(moonAngle) - width / 2
                y: moonOrbit.height / 2 + moonOrbitRadius * Math.sin(moonAngle) - height / 2
            }
        }

        // Панель управления
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            height: 140
            color: "#E0000020"
            border.color: "#444477"
            border.width: 2
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15

                Text {
                    text: "Солнечная система - Просмотр"
                    font.bold: true
                    font.pixelSize: 16
                    color: "white"
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: "Сбросить на 01.01.2025"
                        onClicked: resetToStartDate()
                    }

                    Button {
                        text: updateTimer.running ? "Пауза" : "Продолжить"
                        onClicked: updateTimer.running = !updateTimer.running
                    }

                    Text {
                        text: "Автосинхронизация с картой"
                        color: "#88FF88"
                        font.pixelSize: 10
                        font.italic: true
                    }
                }

                // Панель влияния
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Влияние:"
                        color: "white"
                        font.bold: true
                    }

                    Text {
                        text: "Солнце: " + (solarInfluence * 100).toFixed(1) + "%"
                        color: getInfluenceColor(solarInfluence)
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Луна: " + (lunarInfluence * 100).toFixed(1) + "%"
                        color: getInfluenceColor(lunarInfluence)
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Планеты: " + (planetaryInfluence * 100).toFixed(1) + "%"
                        color: getInfluenceColor(planetaryInfluence)
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Общее: " + ((solarInfluence * lunarInfluence * planetaryInfluence - 1) * 100).toFixed(1) + "%"
                        color: getInfluenceColor(solarInfluence * lunarInfluence * planetaryInfluence)
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }

        // Информационная панель
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 350
            height: 240
            color: "#E0000020"
            border.color: "#444477"
            border.width: 2
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5

                Text {
                    text: "Параметры солнечной системы"
                    font.bold: true
                    font.pixelSize: 14
                    color: "white"
                }

                Text {
                    text: "Дата: " + getCurrentDateString()
                    color: "white"
                    font.pixelSize: 12
                }

                Text {
                    text: "Время: " + formatTime(currentHour) + " (" + timeOfDay + ")"
                    color: getTimeColor()
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    text: "Прошло дней с 01.01.2025: " + daysFromStart.toFixed(3)
                    color: "#88FF88"
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    text: "Прогресс года: " + ((daysFromStart / 365) * 100).toFixed(2) + "%"
                    color: "#FFAA00"
                    font.pixelSize: 12
                }

                Text {
                    text: "Угол Земли: " + (earthAngle * 180 / Math.PI).toFixed(1) + "°"
                    color: "white"
                    font.pixelSize: 11
                }

                Text {
                    text: "Угол Луны: " + (moonAngle * 180 / Math.PI).toFixed(1) + "°"
                    color: "white"
                    font.pixelSize: 11
                }

                Text {
                    text: "Фаза Луны: " + getMoonPhase()
                    color: "white"
                    font.pixelSize: 11
                }

                Text {
                    text: "Статус: " + (updateTimer.running ? "Активен" : "На паузе")
                    color: updateTimer.running ? "#88FF88" : "#FF8888"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    function updatePositions() {
        // Обновляем углы на основе прошедших дней
        earthAngle = (daysFromStart / 365) * 2 * Math.PI;

        // Луна: полный оборот за 27.3 дня
        var moonDays = daysFromStart % 27.3;
        moonAngle = (moonDays / 27.3) * 2 * Math.PI;

        // Обновляем влияние
        updateInfluence();

        // Обновляем время суток
        updateTimeOfDay();
    }

    function updateInfluence() {
        // Влияние Солнца
        var distance = getEarthSunDistance();
        var normalizedDistance = distance / earthOrbitRadiusX;
        solarInfluence = 1.0 / (normalizedDistance * normalizedDistance);

        // Флуктуации солнечной активности
        var solarFluctuation = 0.9 + (Math.sin(daysFromStart * 0.5) + 1) * 0.1;
        solarInfluence *= solarFluctuation;

        // Влияние Луны
        var moonPhase = Math.cos(moonAngle - earthAngle);
        var moonDistance = 1.0 + 0.2 * Math.sin(moonAngle * 4);
        lunarInfluence = 0.9 + 0.3 * moonPhase * moonDistance;

        // Влияние планет
        var planet1 = Math.sin(earthAngle * 2.5) * 0.05;
        var planet2 = Math.cos(earthAngle * 1.7) * 0.03;
        var planet3 = Math.sin(earthAngle * 3.2 + 1) * 0.02;
        planetaryInfluence = 1.0 + planet1 + planet2 + planet3;

        // Корректируем по времени суток
        var timeFactor = 1.0;
        if (timeOfDay === "Ночь") timeFactor = 0.85;
        else if (timeOfDay === "День") timeFactor = 1.15;
        else if (timeOfDay === "Рассвет" || timeOfDay === "Поздний вечер") timeFactor = 0.95;

        solarInfluence *= timeFactor;
    }

    function getInfluenceColor(influence) {
        if (influence > 1.1) return "#FF4444";
        if (influence > 1.0) return "#FFAA00";
        if (influence > 0.9) return "#44FF44";
        return "#8888FF";
    }

    function updateTimeOfDay() {
        var h = currentHour;
        if (h >= 4 && h < 8) timeOfDay = "Рассвет";
        else if (h >= 8 && h < 12) timeOfDay = "Утро";
        else if (h >= 12 && h < 16) timeOfDay = "День";
        else if (h >= 16 && h < 20) timeOfDay = "Вечер";
        else if (h >= 20 && h < 23) timeOfDay = "Поздний вечер";
        else timeOfDay = "Ночь";
    }

    function getTimeColor() {
        var h = currentHour;
        if (h >= 5 && h < 7) return "#FFAA00";
        else if (h >= 7 && h < 17) return "#FF6600";
        else if (h >= 17 && h < 20) return "#FF3300";
        else return "#3366FF";
    }

    function getEarthSunDistance() {
        var r = (earthOrbitRadiusX * earthOrbitRadiusY) /
                Math.sqrt(Math.pow(earthOrbitRadiusY * Math.cos(earthAngle), 2) +
                         Math.pow(earthOrbitRadiusX * Math.sin(earthAngle), 2));
        return r;
    }

    function getMoonPhase() {
        var phase = Math.cos(moonAngle - earthAngle);
        if (phase > 0.7) return "🌕 Полнолуние";
        if (phase > 0.3) return "🌖 Убывающая";
        if (phase > -0.3) return "🌑 Новолуние";
        if (phase > -0.7) return "🌒 Растущая";
        return "🌕 Полнолуние";
    }

    function formatTime(time) {
        var hours = Math.floor(time);
        var minutes = Math.round((time % 1) * 60);
        return hours.toString().padStart(2, '0') + ":" + minutes.toString().padStart(2, '0');
    }

    function getCurrentDateString() {
        var currentDate = new Date(startDate);
        currentDate.setDate(startDate.getDate() + Math.floor(daysFromStart));

        var hoursToAdd = (daysFromStart % 1) * 24;
        currentDate.setHours(6 + Math.floor(hoursToAdd));
        currentDate.setMinutes(Math.round((hoursToAdd % 1) * 60));

        return currentDate.toLocaleDateString(Qt.locale("ru_RU")) +
               " " + currentDate.toLocaleTimeString(Qt.locale("ru_RU"), "hh:mm");
    }

    function resetToStartDate() {
        currentDateTime = new Date(2025, 0, 1);
        currentHour = 6.0;
        daysFromStart = 0;
        updatePositions();
    }

    function setCurrentTime(hour, days) {
        currentHour = hour;
        daysFromStart = days;

        currentDateTime = new Date(startDate);
        currentDateTime.setDate(startDate.getDate() + Math.floor(daysFromStart));

        var fractionalDay = daysFromStart % 1;
        var additionalHours = fractionalDay * 24;
        currentDateTime.setHours(6 + Math.floor(additionalHours));
        currentDateTime.setMinutes(Math.round((additionalHours % 1) * 60));

        updatePositions();
    }

    // Методы для получения влияния
    function getSolarInfluence() {
        return solarInfluence;
    }

    function getLunarInfluence() {
        return lunarInfluence;
    }

    function getPlanetaryInfluence() {
        return planetaryInfluence;
    }

    function getCurrentDateTime() {
        return currentDateTime;
    }

    function getCurrentHour() {
        return currentHour;
    }

    function getTimeOfDay() {
        return timeOfDay;
    }

    function getDaysFromStart() {
        return daysFromStart;
    }

    Component.onCompleted: {
        resetToStartDate();
    }
}
