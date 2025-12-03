import QtQuick 2.12
import QtLocation 5.12
import QtPositioning 5.12

MapQuickItem {
    id: measurementIndicator

    property color measurementColor: "white"
    property string satelliteName: ""

    anchorPoint.x: indicator.width / 2
    anchorPoint.y: indicator.height

    sourceItem: Rectangle {
        id: indicator
        width: 80
        height: 40
        color: "#E0000000"
        border.width: 2
        border.color: measurementColor
        radius: 5

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "📡"
                font.pixelSize: 16
                color: measurementColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: satelliteName.substring(0, 8)
                font.pixelSize: 8
                font.bold: true
                color: "white"
            }
        }

        SequentialAnimation on opacity {
            running: true
            loops: 3
            NumberAnimation { from: 0; to: 1; duration: 300 }
            PauseAnimation { duration: 200 }
            NumberAnimation { from: 1; to: 0; duration: 300 }
        }

        ScaleAnimator {
            target: indicator
            from: 0.5
            to: 1.0
            duration: 600
            running: true
        }
    }
}
