// Items/SatelliteMeasurement.qml
import QtQuick 2.12

Item {
    property string satelliteName: ""
    property double latitude: 0
    property double longitude: 0
    property double altitude: 0
    property date measurementTime: new Date()
    property double noiseLevel: -100
    property string cityName: ""
    property double distanceToCity: 0
    property double influenceFactor: 1.0

    function toString() {
        return cityName ?
            `${satelliteName}: ${cityName} (${noiseLevel.toFixed(1)} дБм)` :
            `${satelliteName}: ${latitude.toFixed(4)}, ${longitude.toFixed(4)} (${noiseLevel.toFixed(1)} дБм)`;
    }

    function toCSV() {
        return `"${satelliteName}","${cityName}",${latitude},${longitude},${noiseLevel.toFixed(1)},${distanceToCity.toFixed(1)},${altitude.toFixed(1)},"${measurementTime.toISOString()}",${influenceFactor.toFixed(3)}`;
    }
}
