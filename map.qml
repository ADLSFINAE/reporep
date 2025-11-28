import QtQuick 2.12
import QtLocation 5.12
import QtPositioning 5.12

Item {
    id: root
    width: 800
    height: 600

    property var measurementZones: []
    property var radiationData: ({})

    Plugin {
        id: mapPlugin
        name: "osm"

        PluginParameter {
            name: "osm.mapping.custom.host"
            value: "https://tile.openstreetmap.org/"
        }
    }

    Map {
        id: map
        anchors.fill: parent
        plugin: mapPlugin
        center: QtPositioning.coordinate(55.7558, 37.6173)
        zoomLevel: 10
        activeMapType: supportedMapTypes[0]

        gesture.enabled: true
    }

    // Функции для вызова из C++
    function setCenter(lat, lng, zoom) {
        console.log("Setting center to:", lat, lng, zoom);
        map.center = QtPositioning.coordinate(lat, lng);
        if (zoom !== undefined) {
            map.zoomLevel = zoom;
        }
    }

    function setZoom(zoom) {
        console.log("Setting zoom to:", zoom);
        map.zoomLevel = zoom;
    }

    function setMapType(type) {
        console.log("Setting map type to:", type);
        for (var i = 0; i < map.supportedMapTypes.length; i++) {
            var mapTypeName = map.supportedMapTypes[i].name.toLowerCase();
            if (mapTypeName.indexOf(type) !== -1) {
                map.activeMapType = map.supportedMapTypes[i];
                break;
            }
        }
    }

    function addMeasurementZone(lat, lng, radiusKm) {
        console.log("Adding measurement zone:", lat, lng, radiusKm);

        // Создаем зону измерения
        var zoneComponent = Qt.createComponent("MeasurementZone.qml");
        if (zoneComponent.status === Component.Ready) {
            var zone = zoneComponent.createObject(map, {
                "center": QtPositioning.coordinate(lat, lng),
                "radius": radiusKm * 1000 // Конвертируем в метры
            });
            measurementZones.push(zone);
            map.addMapItem(zone);
        } else {
            console.log("Error creating zone component:", zoneComponent.errorString());
        }
    }

    function updateRadiationData(lat, lng, noise70cm, noise2m) {
        console.log("Updating radiation data:", lat, lng, noise70cm, noise2m);

        var coordKey = lat.toFixed(4) + "," + lng.toFixed(4);
        radiationData[coordKey] = {
            "coordinate": QtPositioning.coordinate(lat, lng),
            "noise70cm": noise70cm,
            "noise2m": noise2m,
            "timestamp": new Date()
        };

        // Создаем/обновляем визуализацию излучения
        createRadiationVisualization(lat, lng, noise70cm, noise2m);
    }

    function createRadiationVisualization(lat, lng, noise70cm, noise2m) {
        // Создаем градиентную зону излучения для 70см
        var radiationComponent = Qt.createComponent("RadiationZone.qml");
        if (radiationComponent.status === Component.Ready) {
            var radiation = radiationComponent.createObject(map, {
                "center": QtPositioning.coordinate(lat, lng),
                "noiseLevel": noise70cm,
                "band": "70cm"
            });
            map.addMapItem(radiation);

            // Автоматическое удаление через 10 секунд для анимации
            radiation.autoRemoveTimer.start();
        }

        // Также создаем для 2м (можно сделать разными цветами)
        if (radiationComponent.status === Component.Ready) {
            var radiation2m = radiationComponent.createObject(map, {
                "center": QtPositioning.coordinate(lat, lng),
                "noiseLevel": noise2m,
                "band": "2m"
            });
            map.addMapItem(radiation2m);
            radiation2m.autoRemoveTimer.start();
        }
    }

    function clearAllVisualizations() {
        console.log("Clearing all visualizations");

        // Удаляем зоны измерения
        for (var i = 0; i < measurementZones.length; i++) {
            map.removeMapItem(measurementZones[i]);
            measurementZones[i].destroy();
        }
        measurementZones = [];

        // Очищаем данные излучения
        radiationData = {};

        // Удаляем все RadiationZone элементы
        var items = map.mapItems;
        for (var j = items.length - 1; j >= 0; j--) {
            if (items[j].toString().indexOf("RadiationZone") !== -1) {
                map.removeMapItem(items[j]);
                items[j].destroy();
            }
        }
    }
}
