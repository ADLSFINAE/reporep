import QtQuick 2.12
import QtLocation 5.12

MapRectangle {
    property double noiseLevel: -100
    property string title: "Область"

    color: "#80FF0000"
    opacity: 0.7
    border.width: 2
    border.color: Qt.darker(color, 1.3)
}
