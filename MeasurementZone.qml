import QtQuick 2.12
import QtLocation 5.12

MapCircle {
    id: zoneCircle
    color: "transparent"
    border.color: "#2196F3"
    border.width: 3
    opacity: 0.7

    // Текст с информацией о зоне
    MapQuickItem {
        anchorPoint.x: zoneText.width / 2
        anchorPoint.y: zoneText.height / 2
        coordinate: zoneCircle.center

        sourceItem: Rectangle {
            id: zoneText
            width: textMetrics.width + 20
            height: textMetrics.height + 10
            color: "#2196F3"
            opacity: 0.9
            radius: 5

            Text {
                id: textMetrics
                anchors.centerIn: parent
                text: "Зона измерения\n" + (zoneCircle.radius / 1000).toFixed(1) + " км"
                color: "white"
                font.bold: true
                font.pixelSize: 10
            }
        }
    }
}
