import QtQuick
import QtCore
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

import "logic.js" as Logic

PlasmoidItem {
    id: root

    readonly property string baseUrl: Plasmoid.configuration.url.replace(/\/+$/, "")
    property string apiKey: Plasmoid.configuration.apiKey
    readonly property string homePath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")

    property bool online: false
    property string errorText: ""
    property string myId: ""
    property var folders: []
    property var folderStatus: ({})
    property var devices: []
    property var connections: ({})

    readonly property var remoteDevices: devices.filter(d => d.deviceID !== myId)
    readonly property int connectedCount: remoteDevices.filter(d => connections[d.deviceID]?.connected).length
    readonly property bool allPaused: remoteDevices.length > 0 && remoteDevices.every(d => d.paused)

    readonly property string overallState: Logic.overallState(online, folders, folderStatus)

    function stateColor(state) {
        switch (state) {
        case "idle": return Kirigami.Theme.positiveTextColor;
        case "syncing": return Kirigami.Theme.activeTextColor;
        case "error": return Kirigami.Theme.negativeTextColor;
        default: return Kirigami.Theme.disabledTextColor;
        }
    }

    function folderStateText(folder) {
        if (folder.paused) return i18n("Paused");
        const st = folderStatus[folder.id];
        if (!st) return i18n("Unknown");
        switch (st.state) {
        case "idle": return i18n("Up to date");
        case "scanning": return i18n("Scanning");
        case "syncing": return i18n("Syncing – %1 left", KCoreAddons.Format.formatByteSize(st.needBytes));
        case "sync-preparing": return i18n("Preparing to sync");
        case "error": return i18n("Error");
        default: return st.state;
        }
    }

    function folderPercent(folder) {
        return Logic.folderPercent(folderStatus[folder.id]);
    }

    function openFolder(path) {
        Qt.openUrlExternally(Logic.fileUrl(path, homePath));
        root.expanded = false;
    }

    // Use curl so the self-signed HTTPS cert of the web UI is accepted
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})

        onNewData: (sourceName, data) => {
            const cb = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (cb) cb(data["exit code"], data["stdout"]);
        }

        function run(cmd, cb) {
            callbacks[cmd] = cb;
            connectSource(cmd);
        }
    }

    function api(path, cb, method) {
        executable.run(Logic.curlCommand(baseUrl, apiKey, path, method), (code, stdout) => {
            let json = null;
            if (code === 0) {
                try { json = JSON.parse(stdout); } catch (e) {}
            }
            cb(json, stdout);
        });
    }

    function detectApiKey() {
        const cmd = "sed -n 's:.*<apikey>\\(.*\\)</apikey>.*:\\1:p' "
            + "\"${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml\" "
            + "\"${XDG_CONFIG_HOME:-$HOME/.config}/syncthing/config.xml\" 2>/dev/null | head -n1";
        executable.run(cmd, (code, stdout) => {
            const key = stdout.trim();
            if (key) {
                apiKey = key;
                refresh();
            } else {
                online = false;
                errorText = i18n("No API key found. Set one in the widget settings.");
            }
        });
    }

    function refresh() {
        if (!apiKey) {
            detectApiKey();
            return;
        }
        api("/rest/system/status", (json, raw) => {
            if (!json || !json.myID) {
                online = false;
                errorText = Logic.isAuthError(raw)
                    ? i18n("Syncthing rejected the API key.")
                    : i18n("Cannot reach Syncthing at %1", baseUrl);
                return;
            }
            online = true;
            errorText = "";
            myId = json.myID;

            api("/rest/config/folders", fs => {
                if (!fs) return;
                folders = Logic.parseFolders(fs);
                folders.filter(f => !f.paused).forEach(f => {
                    api("/rest/db/status?folder=" + encodeURIComponent(f.id), st => {
                        if (!st) return;
                        const copy = Object.assign({}, folderStatus);
                        copy[f.id] = st;
                        folderStatus = copy;
                    });
                });
            });
            api("/rest/config/devices", ds => {
                if (ds) devices = Logic.parseDevices(ds);
            });
            api("/rest/system/connections", c => {
                if (c) connections = c.connections;
            });
        });
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.pollInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Plasmoid.configuration
        function onApiKeyChanged() { root.apiKey = Plasmoid.configuration.apiKey; root.refresh(); }
        function onUrlChanged() { root.refresh(); }
    }

    Plasmoid.icon: "syncthing"
    Plasmoid.status: overallState === "syncing" ? PlasmaCore.Types.ActiveStatus
                   : overallState === "error" ? PlasmaCore.Types.NeedsAttentionStatus
                   : PlasmaCore.Types.PassiveStatus

    toolTipMainText: i18n("Syncthing")
    toolTipSubText: {
        switch (overallState) {
        case "offline": return errorText || i18n("Not running");
        case "error": return i18n("A folder has errors");
        case "syncing": return i18n("Syncing… (%1 of %2 devices connected)", connectedCount, remoteDevices.length);
        default: return i18n("Up to date (%1 of %2 devices connected)", connectedCount, remoteDevices.length);
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Web UI")
            icon.name: "internet-web-browser"
            onTriggered: Qt.openUrlExternally(root.baseUrl)
        },
        PlasmaCore.Action {
            text: i18n("Rescan All Folders")
            icon.name: "view-refresh"
            enabled: root.online
            onTriggered: root.api("/rest/db/scan", () => root.refresh(), "POST")
        }
    ]

    compactRepresentation: MouseArea {
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) Qt.openUrlExternally(root.baseUrl);
            else root.expanded = !root.expanded;
        }

        Kirigami.Icon {
            readonly property int style: Plasmoid.configuration.iconStyle
            anchors.fill: parent
            source: style === 0 ? "syncthing" : Qt.resolvedUrl("../icons/syncthing-symbolic.svg")
            isMask: style !== 0
            color: style === 2 ? "#fcfcfc"
                 : style === 3 ? "#232629"
                 : Kirigami.Theme.textColor
            active: parent.containsMouse
            opacity: root.online ? 1 : 0.5
        }

        Rectangle {
            width: Math.max(6, Math.round(parent.width / 3.5))
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            color: root.stateColor(root.overallState)
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 36
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    level: 3
                    text: root.toolTipSubText
                    elide: Text.ElideRight
                }
                PlasmaComponents.ToolButton {
                    icon.name: root.allPaused ? "media-playback-start" : "media-playback-pause"
                    enabled: root.online && root.remoteDevices.length > 0
                    onClicked: root.api(root.allPaused ? "/rest/system/resume" : "/rest/system/pause",
                                        () => root.refresh(), "POST")
                    PlasmaComponents.ToolTip { text: root.allPaused ? i18n("Resume all devices") : i18n("Pause all devices") }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    enabled: root.online
                    onClicked: root.api("/rest/db/scan", () => root.refresh(), "POST")
                    PlasmaComponents.ToolTip { text: i18n("Rescan all folders") }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "internet-web-browser"
                    onClicked: Qt.openUrlExternally(root.baseUrl)
                    PlasmaComponents.ToolTip { text: i18n("Open Web UI") }
                }
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: !root.online
            iconName: "syncthing"
            text: i18n("Syncthing is not reachable")
            explanation: root.errorText
        }

        PlasmaComponents.ScrollView {
            anchors.fill: parent
            visible: root.online
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 4
                    text: i18n("Folders")
                    Layout.margins: Kirigami.Units.smallSpacing
                }

                Repeater {
                    model: root.folders
                    delegate: PlasmaComponents.ItemDelegate {
                        id: folderDelegate
                        required property var modelData
                        readonly property var status: root.folderStatus[modelData.id]
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        onClicked: root.openFolder(modelData.path)

                        PlasmaComponents.ToolTip { text: i18n("Open %1", Logic.expandPath(folderDelegate.modelData.path, root.homePath)) }

                        contentItem: ColumnLayout {
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Kirigami.Icon {
                                    source: "folder-sync"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: folderDelegate.modelData.label
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    text: root.folderStateText(folderDelegate.modelData)
                                    opacity: 0.7
                                    color: folderDelegate.status?.state === "error"
                                           ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                }
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                                elide: Text.ElideMiddle
                                text: folderDelegate.status
                                      ? i18nc("size · path", "%1 · %2",
                                              KCoreAddons.Format.formatByteSize(folderDelegate.status.localBytes),
                                              folderDelegate.modelData.path)
                                      : folderDelegate.modelData.path
                            }
                            PlasmaComponents.ProgressBar {
                                Layout.fillWidth: true
                                visible: !folderDelegate.modelData.paused && root.folderPercent(folderDelegate.modelData) < 100
                                from: 0
                                to: 100
                                value: root.folderPercent(folderDelegate.modelData)
                            }
                        }
                    }
                }

                Kirigami.Heading {
                    level: 4
                    text: i18n("Devices")
                    Layout.margins: Kirigami.Units.smallSpacing
                    Layout.topMargin: Kirigami.Units.largeSpacing
                }

                Repeater {
                    model: root.remoteDevices
                    delegate: RowLayout {
                        required property var modelData
                        readonly property bool connected: root.connections[modelData.deviceID]?.connected ?? false
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing

                        Rectangle {
                            Layout.preferredWidth: Kirigami.Units.smallSpacing * 2
                            Layout.preferredHeight: width
                            radius: width / 2
                            color: modelData.paused ? Kirigami.Theme.disabledTextColor
                                 : connected ? Kirigami.Theme.positiveTextColor
                                 : Kirigami.Theme.negativeTextColor
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            opacity: 0.7
                            text: modelData.paused ? i18n("Paused")
                                : connected ? i18n("Connected") : i18n("Disconnected")
                        }
                    }
                }
            }
        }
    }
}
