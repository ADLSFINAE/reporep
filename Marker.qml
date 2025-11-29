import QtQuick 2.12
import QtLocation 5.12

MapQuickItem {
    id: mapMarker
    anchorPoint.x: marker.width / 2
    anchorPoint.y: marker.height

    property string title: ""
    property double noiseLevel: 0

    sourceItem: Rectangle {
        id: marker
        width: 35
        height: 35
        radius: width / 2
        color: getColor(noiseLevel)
        border.width: 3
        border.color: "white"

        Text {
            anchors.centerIn: parent
            color: "white"
            font.bold: true
            font.pixelSize: 12
            text: title
        }
    }

    function getColor(level) {
        if (level > -70) return "#FF0000";
        if (level > -80) return "#FF8800";
        if (level > -90) return "#FFFF00";
        if (level > -100) return "#00FF00";
        return "#0000FF";
    }
}

