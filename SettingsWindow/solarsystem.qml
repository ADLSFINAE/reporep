import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQml 2.12

Item {
    width: 1280
    height: 800

    property date startDate: new Date(2025, 0, 1) // 1 января 2025
    property date currentDateTime: new Date(2025, 0, 1)
    property double solarInfluence: 1.0
    property double lunarInfluence: 1.0
    property double planetaryInfluence: 1.0
    property real daysFromStart: 0
    property real currentHour: 6.0
    property string timeOfDay: "Утро"

    // Эллиптические параметры орбиты Земли (эксцентриситет ~0.0167)
    property real earthOrbitSemiMajor: 300
    property real earthOrbitSemiMinor: 298
    property real earthOrbitFocusDistance: Math.sqrt(earthOrbitSemiMajor * earthOrbitSemiMajor - earthOrbitSemiMinor * earthOrbitSemiMinor)

    property real earthAngle: 0
    property real earthRotationAngle: 0

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

        // Фон с звездами
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.fillStyle = "#000010";
                ctx.fillRect(0, 0, width, height);

                // Рисуем звезды
                ctx.fillStyle = "white";
                for (var i = 0; i < 200; i++) {
                    var x = Math.random() * width;
                    var y = Math.random() * height;
                    var size = Math.random() * 1.5;
                    ctx.beginPath();
                    ctx.arc(x, y, size, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }

        // Эллиптическая орбита Земли
        Canvas {
            id: earthOrbitCanvas
            anchors.centerIn: parent
            width: earthOrbitSemiMajor * 2
            height: earthOrbitSemiMinor * 2
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = "#444477";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.ellipse(0, 0, width, height);
                ctx.stroke();

                // Отмечаем фокусы эллипса
                ctx.fillStyle = "#FF4444";
                ctx.beginPath();
                ctx.arc(earthOrbitFocusDistance, 0, 3, 0, Math.PI * 2);
                ctx.fill();

                ctx.beginPath();
                ctx.arc(-earthOrbitFocusDistance, 0, 3, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        // Солнце в одном из фокусов эллипса (PNG изображение)
        Image {
            id: sun
            width: 70
            height: 70
            source: "qrc:/Images/sun.png"

            x: earthOrbitCanvas.x + earthOrbitCanvas.width / 2 + earthOrbitFocusDistance - width / 2
            y: earthOrbitCanvas.y + earthOrbitCanvas.height / 2 - height / 2

            // Масштабирование изображения
            fillMode: Image.PreserveAspectFit

            // Сглаживание изображения
            smooth: true
            mipmap: true
            antialiasing: true

            // Свечение вокруг солнца
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.5
                height: parent.height * 1.5
                radius: width / 2
                color: "transparent"
                border.color: "#FF8800"
                border.width: 3
                opacity: 0.6

                // Сглаживание для свечения
                antialiasing: true
            }

            // Дополнительный эффект сглаживания через слой
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2) // Увеличиваем текстуру для лучшего качества
        }

        // Земля (PNG изображение)
        Item {
            id: earthContainer
            width: 35
            height: 35

            // Позиция Земли на эллиптической орбите
            x: earthOrbitCanvas.x + earthOrbitCanvas.width / 2 + earthOrbitSemiMajor * Math.cos(earthAngle) - width / 2
            y: earthOrbitCanvas.y + earthOrbitCanvas.height / 2 + earthOrbitSemiMinor * Math.sin(earthAngle) - height / 2

            // Вращение Земли вокруг своей оси
            RotationAnimation on rotation {
                id: earthRotation
                from: 0
                to: 360
                duration: 1000 // 1 секунда для полного оборота (для наглядности)
                loops: Animation.Infinite
                running: updateTimer.running
            }

            // Земля с PNG текстурой
            Image {
                id: earth
                anchors.centerIn: parent
                width: 35
                height: 35
                source: "qrc:/Images/earth.png"
                fillMode: Image.PreserveAspectFit

                // Вращение текстуры земли
                rotation: -parent.rotation // Компенсируем вращение контейнера для реалистичного вида

                // Сглаживание изображения
                smooth: true
                mipmap: true
                antialiasing: true

                // Дополнительный эффект сглаживания через слой
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2) // Увеличиваем текстуру для лучшего качества
            }

            // Атмосфера
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.1
                height: parent.height * 1.1
                radius: width / 2
                color: "transparent"
                border.color: "#88CCFF"
                border.width: 2
                opacity: 0.3

                // Сглаживание для атмосферы
                antialiasing: true
            }

            // Дополнительный эффект сглаживания для всего контейнера земли
            layer.enabled: true
            layer.smooth: true
        }

        // Панель управления
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            height: 100
            color: "#E0000020"
            border.color: "#444477"
            border.width: 2
            radius: 10

            // Сглаживание для панели управления
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15

                Text {
                    text: "Солнечная система - Реалистичная модель"
                    font.bold: true
                    font.pixelSize: 16
                    color: "white"

                    // Сглаживание текста
                    renderType: Text.NativeRendering
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Управление временем в основном окне"
                        color: "#88FF88"
                        font.pixelSize: 12
                        font.italic: true

                        // Сглаживание текста
                        renderType: Text.NativeRendering
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
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Солнце: " + (solarInfluence * 100).toFixed(1) + "%"
                        color: getInfluenceColor(solarInfluence)
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Планеты: " + (planetaryInfluence * 100).toFixed(1) + "%"
                        color: getInfluenceColor(planetaryInfluence)
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: "Общее: " + ((solarInfluence * lunarInfluence * planetaryInfluence - 1) * 100).toFixed(1) + "%"
                        color: getInfluenceColor(solarInfluence * lunarInfluence * planetaryInfluence)
                        font.pixelSize: 11
                        font.bold: true
                        renderType: Text.NativeRendering
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

            // Сглаживание для информационной панели
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5

                Text {
                    text: "Параметры солнечной системы"
                    font.bold: true
                    font.pixelSize: 14
                    color: "white"
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Дата: " + getCurrentDateString()
                    color: "white"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Время: " + formatTime(currentHour) + " (" + timeOfDay + ")"
                    color: getTimeColor()
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Прошло дней с 01.01.2025: " + daysFromStart.toFixed(3)
                    color: "#88FF88"
                    font.pixelSize: 12
                    font.bold: true
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Прогресс года: " + ((daysFromStart / 365) * 100).toFixed(2) + "%"
                    color: "#FFAA00"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Угол вращения Земли: 23.5°"
                    color: "white"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Вращение Земли: " + (earthRotationAngle * 180 / Math.PI).toFixed(1) + "°"
                    color: "white"
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Статус: " + (updateTimer.running ? "Активен" : "На паузе")
                    color: updateTimer.running ? "#88FF88" : "#FF8888"
                    font.pixelSize: 11
                    font.bold: true
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    function updatePositions() {
        // Обновляем углы на основе прошедших дней
        // Время теперь управляется извне через daysFromStart и currentHour

        // Земля: полный оборот вокруг Солнца за 365.25 дней
        earthAngle = (daysFromStart / 365.25) * 2 * Math.PI;

        // Вращение Земли вокруг своей оси (1 оборот за 1 день)
        earthRotationAngle = (daysFromStart % 1) * 2 * Math.PI;

        // Обновляем влияние
        updateInfluence();

        // Обновляем время суток
        updateTimeOfDay();
    }

    function updateInfluence() {
        // Влияние Солнца (зависит от расстояния по закону обратных квадратов)
        var distance = getEarthSunDistance();
        var averageDistance = (earthOrbitSemiMajor + earthOrbitSemiMinor) / 2;
        var normalizedDistance = distance / averageDistance;
        solarInfluence = 1.0 / (normalizedDistance * normalizedDistance);

        // Флуктуации солнечной активности
        var solarFluctuation = 0.95 + (Math.sin(daysFromStart * 0.3) + 1) * 0.05;
        solarInfluence *= solarFluctuation;

        // Влияние Луны (фиксированное значение, так как Луны нет)
        lunarInfluence = 1.0;

        // Влияние планет (резонансы и гравитационные возмущения)
        var planet1 = Math.sin(earthAngle * 2.5) * 0.04;
        var planet2 = Math.cos(earthAngle * 1.7 + 0.5) * 0.03;
        var planet3 = Math.sin(earthAngle * 3.2 + 1.2) * 0.02;
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
        // Обновляем текущий час на основе вращения Земли
        currentHour = (earthRotationAngle / (2 * Math.PI)) * 24;

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
        // Расстояние от Земли до Солнца в эллиптической орбите
        var r = (earthOrbitSemiMajor * (1 - (earthOrbitFocusDistance/earthOrbitSemiMajor)*(earthOrbitFocusDistance/earthOrbitSemiMajor))) /
                (1 + (earthOrbitFocusDistance/earthOrbitSemiMajor) * Math.cos(earthAngle));
        return r;
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
        earthRotationAngle = 0;
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


