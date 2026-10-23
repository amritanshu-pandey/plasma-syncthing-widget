import QtQuick
import QtTest

// Compiles each QML file without running it, to catch bad imports, unknown types and syntax errors
TestCase {
    name: "Load"

    function test_compile_data() {
        return [
            { tag: "main", file: "../package/contents/ui/main.qml" },
            { tag: "configGeneral", file: "../package/contents/ui/configGeneral.qml" },
            { tag: "config", file: "../package/contents/config/config.qml" },
        ];
    }

    function test_compile(data) {
        const component = Qt.createComponent(Qt.resolvedUrl(data.file), Component.PreferSynchronous);
        tryVerify(() => component.status !== Component.Loading);
        verify(component.status === Component.Ready, component.errorString());
    }
}
