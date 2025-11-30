import QtQuick 2.12
import QtLocation 5.12
import QtPositioning 5.12

MapQuickItem {
    id: trailPoint

    property color trailColor: "black"
    property double trailSize: 2

    anchorPoint.x: trailDot.width / 2
    anchorPoint.y: trailDot.height / 2

    sourceItem: Rectangle {
        id: trailDot
        width: trailSize
        height: trailSize
        radius: trailSize / 2
        color: trailColor
        opacity: 0.8
    }
}
