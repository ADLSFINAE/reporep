import QtQuick 2.12
import QtQml 2.12

QtObject {
    id: jsonLoader

    property string source: ""
    property var data: null
    property string errorString: ""

    signal error(string errorString)
    signal dataChanged

    function load() {
        console.log("Загрузка JSON из:", source);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", source);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        data = JSON.parse(xhr.responseText);
                        errorString = "";
                        dataChanged();
                        console.log("JSON успешно загружен");
                    } catch (e) {
                        errorString = "Ошибка парсинга JSON: " + e.toString();
                        console.log(errorString);
                        error(errorString);
                    }
                } else {
                    errorString = "Ошибка загрузки файла: " + xhr.status + " " + xhr.statusText;
                    console.log(errorString);
                    error(errorString);
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        if (source) {
            load();
        }
    }
}
