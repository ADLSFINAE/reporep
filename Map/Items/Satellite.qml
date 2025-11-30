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
                text: satelliteName
                font.pixelSize: 9
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

    function moveToNextPoint() {
        if (trajectory.length === 0) return;

        currentPoint = (currentPoint + 1) % trajectory.length;
        coordinate = trajectory[currentPoint];

        // Добавляем точку следа через определенные интервалы
        pointsCounter++;
        if (pointsCounter >= trailUpdateInterval) {
            pointsCounter = 0;
            addTrailPoint(coordinate);
        }
    }

    function addTrailPoint(coord) {
        // Создаем компонент для точки следа
        var component = Qt.createComponent("qrc:/Map/Items/TrailPoint.qml");
        if (component.status === Component.Ready) {
            // Создаем объект с родителем map (а не satelliteItem!)
            var trailPoint = component.createObject(map, {
                "coordinate": Qt.binding(function() { return coord; }),
                "trailColor": trailColor,
                "trailSize": trailSize
            });

            // Сохраняем ссылку
            trailPoints.push(trailPoint);

            // Ограничиваем количество точек
            if (trailPoints.length > maxTrailPoints) {
                var oldPoint = trailPoints.shift();
                oldPoint.destroy();
            }
        } else {
            console.log("Ошибка создания точки следа:", component.errorString());
        }
    }

    function clearTrail() {
        // Удаляем все точки следа
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
            // Очищаем след при смене траектории
            clearTrail();
        }
    }

    function setAltitude(newAltitude) {
        altitude = newAltitude;
        updateMovementSpeed();
    }

    function updateMovementSpeed() {
        if (altitude > 35700) {
            movementTimer.interval = 500;
            trailUpdateInterval = 3;
        } else if (altitude > 20000) {
            movementTimer.interval = 200;
            trailUpdateInterval = 5;
        } else if (altitude > 5000) {
            movementTimer.interval = 100;
            trailUpdateInterval = 8;
        } else {
            movementTimer.interval = 50;
            trailUpdateInterval = 10;
        }
    }

    Component.onCompleted: {
        updateMovementSpeed();
    }

    // Уничтожаем точки следа при удалении спутника
    Component.onDestruction: {
        clearTrail();
    }
}
