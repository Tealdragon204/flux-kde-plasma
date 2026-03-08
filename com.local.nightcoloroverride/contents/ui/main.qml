import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── State ────────────────────────────────────────────────────────────────
    property bool active: false
    property int  daemonPid: -1
    property int  chosenTemp: 4200
    property int  chosenDuration: 45      // minutes; 0 = indefinite
    property int  secondsRemaining: 0
    property int  liveKwinTemp: 6500

    // Resolve path to bundled daemon script
    property string scriptPath: Qt.resolvedUrl("../scripts/nightcolor-mode.py")
                                    .toString().replace(/^file:\/\//, "")

    // ── Tooltip ──────────────────────────────────────────────────────────────
    Plasmoid.toolTipMainText: "Night Color Override"
    Plasmoid.toolTipSubText: active
        ? liveKwinTemp + " K — " + formatRemaining(secondsRemaining, chosenDuration)
        : "Inactive — " + liveKwinTemp + " K"

    // ── Compact representation (tray icon) ───────────────────────────────────
    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: 2
            source: active ? "redshift-status-on" : "redshift-status-off"
            // Fallback handled by icon theme; ultimate fallback set via isMask trick below
            fallback: "weather-clear-night"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full representation (popup) ──────────────────────────────────────────
    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing * 2
        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: implicitChildrenHeight + Kirigami.Units.gridUnit

        // Header
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                width:  Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                source: "redshift-status-on"
                fallback: "weather-clear-night"
            }
            Controls.Label {
                text: "Night Color Override"
                font.bold: true
                Layout.fillWidth: true
            }
            Controls.Label {
                text: liveKwinTemp + " K"
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Temperature slider
        Controls.Label {
            text: "Temperature"
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: "1500" ; color: Kirigami.Theme.disabledTextColor }
            Controls.Slider {
                id: tempSlider
                Layout.fillWidth: true
                from: 1500; to: 6500; stepSize: 100
                value: root.chosenTemp
                onMoved: {
                    root.chosenTemp = value
                    // Best-effort live preview while dragging (cosmetic only)
                    if (root.active) {
                        exec("qdbus6 org.kde.KWin /org/kde/KWin/NightLight " +
                             "org.kde.KWin.NightLight.preview " + Math.round(value))
                    }
                }
            }
            Controls.Label { text: "6500" ; color: Kirigami.Theme.disabledTextColor }
        }
        Controls.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.chosenTemp + " K"
            font.bold: true
        }

        // Duration slider
        Controls.Label {
            text: "Duration"
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: "∞" ; color: Kirigami.Theme.disabledTextColor }
            Controls.Slider {
                id: durationSlider
                Layout.fillWidth: true
                from: 0; to: 240; stepSize: 5
                value: root.chosenDuration
                onMoved: root.chosenDuration = value
            }
            Controls.Label { text: "4 h" ; color: Kirigami.Theme.disabledTextColor }
        }
        Controls.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.chosenDuration === 0 ? "∞  (hold until cancelled)" : root.chosenDuration + " m"
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Apply button
        Controls.Button {
            Layout.fillWidth: true
            text: "Apply Override"
            icon.name: "media-playback-start"
            onClicked: applyOverride()
        }

        // Status row (only when active)
        Controls.Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.active
            text: "Active: " + root.liveKwinTemp + " K — " +
                  formatRemaining(root.secondsRemaining, root.chosenDuration)
            color: Kirigami.Theme.positiveTextColor
        }

        // Cancel button (only when active)
        Controls.Button {
            Layout.fillWidth: true
            visible: root.active
            text: "Cancel"
            icon.name: "media-playback-stop"
            onClicked: cancelOverride()
        }
    }

    // ── Executable DataSource ────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            executable.disconnectSource(sourceName)

            // PID capture: daemon launch command contains "nightcolor-mode.py"
            if (sourceName.indexOf("nightcolor-mode.py") !== -1 &&
                sourceName.indexOf("echo $!") !== -1)
            {
                var pid = parseInt(stdout, 10)
                if (!isNaN(pid) && pid > 0) {
                    root.daemonPid = pid
                    root.active = true
                    root.secondsRemaining = root.chosenDuration * 60
                    countdownTimer.restart()
                }
                return
            }

            // currentTemperature poll
            if (sourceName.indexOf("currentTemperature") !== -1) {
                var k = parseInt(stdout, 10)
                if (!isNaN(k) && k > 0) root.liveKwinTemp = k
                return
            }
        }
    }

    function exec(cmd) {
        executable.connectSource(cmd)
    }

    // ── Actions ──────────────────────────────────────────────────────────────
    function applyOverride() {
        // If already active, kill existing daemon first
        if (root.active && root.daemonPid > 0) {
            exec("kill " + root.daemonPid)
            root.active = false
            root.daemonPid = -1
            countdownTimer.stop()
        }

        var durArg = root.chosenDuration > 0 ? " --duration " + root.chosenDuration : ""
        var cmd = "bash -c 'python3 " + root.scriptPath +
                  " --temp " + root.chosenTemp + durArg +
                  " </dev/null >/dev/null 2>&1 & echo $!'"
        exec(cmd)
    }

    function cancelOverride() {
        if (root.daemonPid > 0) {
            exec("kill " + root.daemonPid)
        }
        root.active = false
        root.daemonPid = -1
        root.secondsRemaining = 0
        countdownTimer.stop()
    }

    // ── Timers ───────────────────────────────────────────────────────────────

    // 1-second countdown
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (!root.active) {
                stop()
                return
            }
            if (root.chosenDuration === 0) return   // indefinite — no countdown

            root.secondsRemaining = Math.max(0, root.secondsRemaining - 1)
            if (root.secondsRemaining <= 0) {
                // Daemon will self-exit; just update UI state
                root.active = false
                root.daemonPid = -1
                stop()
            }
        }
    }

    // 5-second temperature poll
    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            exec("qdbus6 org.kde.KWin /org/kde/KWin/NightLight " +
                 "org.kde.KWin.NightLight.currentTemperature")
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    function formatRemaining(secs, durationMins) {
        if (durationMins === 0) return "∞"
        if (secs <= 0) return "0m"
        var m = Math.floor(secs / 60)
        var h = Math.floor(m / 60)
        var rm = m % 60
        if (h > 0) return h + "h " + rm + "m"
        return m + "m"
    }
}
