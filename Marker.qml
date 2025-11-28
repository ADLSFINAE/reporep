import QtQuick 2.12
import QtLocation 5.12

MapQuickItem {
    anchorPoint.x: marker.width / 2
    anchorPoint.y: marker.height

    property string title: ""
    property double noiseLevel: 0

    sourceItem: Rectangle {
        id: marker
        width: 25
        height: 25
        radius: width / 2
        color: getColor(noiseLevel)
        border.width: 2
        border.color: "white"

        Text {
            anchors.centerIn: parent
            color: "white"
            font.bold: true
            font.pixelSize: 10
            text: title.split(' ')[1] // Показываем только номер маркера
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("Marker clicked:", title, "Noise:", noiseLevel)
            }
        }
    }

    function getColor(level) {
        if (level > -80) return "red"
        if (level > -90) return "orange"
        return "green"
    }
}

