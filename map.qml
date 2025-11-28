import QtQuick 2.12
import QtQuick.Window 2.12
import QtLocation 5.12
import QtPositioning 5.12

Item {
    visible: true
    width: 800
    height: 600
    //title: "Карта мониторинга"

    property var markers: []

    Plugin {
        id: mapPlugin
        name: "osm"
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
        map.center = QtPositioning.coordinate(lat, lng);
        if (zoom !== undefined) {
            map.zoomLevel = zoom;
        }
    }

    function setZoom(zoom) {
        map.zoomLevel = zoom;
    }

    function setMapType(type) {
        for (var i = 0; i < map.supportedMapTypes.length; i++) {
            var mapTypeName = map.supportedMapTypes[i].name.toLowerCase();
            if (mapTypeName.indexOf(type) !== -1) {
                map.activeMapType = map.supportedMapTypes[i];
                break;
            }
        }
    }

    function addMarker(lat, lng, title) {
        var component = Qt.createComponent("Marker.qml");
        if (component.status === Component.Ready) {
            var marker = component.createObject(map);
            marker.coordinate = QtPositioning.coordinate(lat, lng);
            marker.title = title;
            markers.push(marker);
            map.addMapItem(marker);
        }
    }

    function clearMarkers() {
        for (var i = 0; i < markers.length; i++) {
            map.removeMapItem(markers[i]);
            markers[i].destroy();
        }
        markers = [];
    }
}
