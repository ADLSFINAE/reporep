import QtQuick 2.12
import QtLocation 5.12

MapCircle {
    property double noiseLevel: -100
    property double baseNoiseLevel: -100
    property string title: "Круг"
    property string circleId: "" // ID из JSON конфигурации

    border.width: 1
    border.color: Qt.darker(color, 1.2)
}



