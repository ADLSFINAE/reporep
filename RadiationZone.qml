import QtQuick 2.12
import QtLocation 5.12

MapCircle {
    id: radiationCircle
    property double noiseLevel: -90
    property string band: "70cm"

    radius: 5000 // 5 км радиус по умолчанию
    color: getColorForNoise(noiseLevel)
    opacity: 0.4
    border.width: 2
    border.color: getBorderColor(noiseLevel)

    // Таймер для автоматического удаления
    property Timer autoRemoveTimer: Timer {
        interval: 10000 // 10 секунд
        onTriggered: {
            if (radiationCircle.parent) {
                radiationCircle.parent.removeMapItem(radiationCircle);
                radiationCircle.destroy();
            }
        }
    }

    // Информация об излучении
    MapQuickItem {
        anchorPoint.x: infoText.width / 2
        anchorPoint.y: infoText.height / 2
        coordinate: radiationCircle.center

        sourceItem: Rectangle {
            id: infoText
            width: textItem.width + 15
            height: textItem.height + 10
            color: getColorForNoise(radiationCircle.noiseLevel)
            border.width: 1
            border.color: "white"
            radius: 3

            Text {
                id: textItem
                anchors.centerIn: parent
                text: radiationCircle.band + "\n" + radiationCircle.noiseLevel.toFixed(1) + " дБм"
                color: "white"
                font.bold: true
                font.pixelSize: 9
            }
        }
    }

    function getColorForNoise(level) {
        if (level > -70) return "#ff0000";      // Красный - очень высокий
        if (level > -80) return "#ff6600";      // Оранжевый - высокий
        if (level > -90) return "#ffff00";      // Желтый - средний
        if (level > -100) return "#00ff00";     // Зеленый - низкий
        return "#0000ff";                       // Синий - очень низкий
    }

    function getBorderColor(level) {
        if (level > -70) return "#cc0000";
        if (level > -80) return "#cc5500";
        if (level > -90) return "#cccc00";
        if (level > -100) return "#00cc00";
        return "#0000cc";
    }
}
