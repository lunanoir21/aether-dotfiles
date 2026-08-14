// Standalone bottom dock for the qs-master shell.
// Not wired into Shell.qml / autostart on purpose — run it by hand to test:
//   quickshell -p ~/.config/hypr/scripts/quickshell/Dock.qml
//
// It lives at the top level (next to TopBar.qml/Main.qml) rather than in
// dock/ because Quickshell refuses "../" imports that reach outside the
// directory of the file passed to `-p`, and this needs Caching/MatugenColors
// from this folder to run standalone. Its config + app list script still
// live in dock/ (dock/dock_config.json, dock/app_fetcher.py).
//
// Once you're happy with it, add it to Shell.qml (e.g. `Dock {}` next to
// `TopBar {}`) or give it its own `exec-once = quickshell -p .../Dock.qml`
// line in config/autostart.conf. The `qsdock` layer-namespace window rule
// already exists in config/rules.conf, so it'll pick up `no_anim` for free.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: dockWindow

    Caching { id: paths }
    MatugenColors { id: mocha }

    WlrLayershell.namespace: "qsdock"
    WlrLayershell.layer: WlrLayer.Top

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors { bottom: true; left: true; right: true }
    implicitHeight: revealStrip + dockAreaHeight + panelBottomGap

    // =====================================================================
    // CONFIG (persisted to dock_config.json next to this file)
    // =====================================================================
    readonly property string configPath: paths.home + "/.config/hypr/scripts/quickshell/dock/dock_config.json"

    property var pinnedApps: []      // [{name, exec, icon, wmclass}]
    property int iconSize: 48
    property bool autohide: true
    property string dockPosition: "center" // "left" | "center" | "right"
    property real bgOpacity: 0.75
    property bool showRunning: true

    property bool configLoaded: false

    function loadConfig() {
        configReader.running = true
    }

    Process {
        id: configReader
        command: ["bash", "-c", "cat '" + dockWindow.configPath + "' 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim()
                    let parsed = (txt.length > 0) ? JSON.parse(txt) : {}
                    if (Array.isArray(parsed.pinnedApps)) dockWindow.pinnedApps = parsed.pinnedApps
                    if (typeof parsed.iconSize === "number") dockWindow.iconSize = parsed.iconSize
                    if (typeof parsed.autohide === "boolean") dockWindow.autohide = parsed.autohide
                    if (typeof parsed.position === "string") dockWindow.dockPosition = parsed.position
                    if (typeof parsed.bgOpacity === "number") dockWindow.bgOpacity = parsed.bgOpacity
                    if (typeof parsed.showRunning === "boolean") dockWindow.showRunning = parsed.showRunning
                } catch (e) {
                    console.log("dock: config parse error", e)
                }
                dockWindow.configLoaded = true
            }
        }
    }

    Process {
        id: configWriter
        property string pendingJson: ""
        command: ["bash", "-c", "mkdir -p \"$(dirname '" + dockWindow.configPath + "')\" && cat > '" + dockWindow.configPath + "' <<'DOCK_CFG_EOF'\n" + pendingJson + "\nDOCK_CFG_EOF"]
    }

    Timer {
        id: saveDebounce
        interval: 350
        onTriggered: {
            let payload = {
                pinnedApps: dockWindow.pinnedApps,
                iconSize: dockWindow.iconSize,
                autohide: dockWindow.autohide,
                position: dockWindow.dockPosition,
                bgOpacity: dockWindow.bgOpacity,
                showRunning: dockWindow.showRunning
            }
            configWriter.pendingJson = JSON.stringify(payload, null, 2)
            configWriter.running = false
            configWriter.running = true
        }
    }

    function saveConfig() { saveDebounce.restart() }

    onPinnedAppsChanged: if (configLoaded) saveConfig()
    onIconSizeChanged: if (configLoaded) saveConfig()
    onAutohideChanged: if (configLoaded) saveConfig()
    onDockPositionChanged: if (configLoaded) saveConfig()
    onBgOpacityChanged: if (configLoaded) saveConfig()
    onShowRunningChanged: if (configLoaded) saveConfig()

    Component.onCompleted: loadConfig()

    // =====================================================================
    // RUNNING WINDOWS (polled via hyprctl clients -j)
    // =====================================================================
    property var runningByClass: ({}) // classKeyLower -> {class, title, addresses:[], count}
    property var focusCursor: ({})    // classKeyLower -> last focused instance index (for cycling)

    Process {
        id: clientsFetcher
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let clients = JSON.parse(this.text)
                    let map = {}
                    for (let c of clients) {
                        let cls = (c.class || c.initialClass || "").trim()
                        if (cls === "") continue
                        let key = cls.toLowerCase()
                        if (!map[key]) map[key] = { class: cls, title: c.title || cls, addresses: [] }
                        map[key].addresses.push(c.address)
                        map[key].title = c.title || map[key].title
                    }
                    dockWindow.runningByClass = map
                } catch (e) {
                    console.log("dock: hyprctl clients parse error", e)
                }
            }
        }
    }

    Timer {
        interval: 900
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { clientsFetcher.running = false; clientsFetcher.running = true }
    }

    // =====================================================================
    // DOCK ITEMS (pinned, in order, + unpinned running apps)
    // =====================================================================
    property var dockItems: []

    function findRunningMatch(pinned) {
        let want = (pinned.wmclass || "").toLowerCase()
        if (want === "") return null
        if (dockWindow.runningByClass[want]) return { key: want, data: dockWindow.runningByClass[want] }
        for (let key in dockWindow.runningByClass) {
            if (key.indexOf(want) !== -1 || want.indexOf(key) !== -1) {
                return { key: key, data: dockWindow.runningByClass[key] }
            }
        }
        return null
    }

    function rebuildDockItems() {
        let items = []
        let consumedKeys = ({})

        for (let p of dockWindow.pinnedApps) {
            let match = findRunningMatch(p)
            items.push({
                name: p.name, exec: p.exec, icon: p.icon, wmclass: p.wmclass || "",
                pinned: true,
                running: !!match,
                classKey: match ? match.key : "",
                addresses: match ? match.data.addresses : [],
                title: match ? match.data.title : p.name
            })
            if (match) consumedKeys[match.key] = true
        }

        if (dockWindow.showRunning) {
            for (let key in dockWindow.runningByClass) {
                if (consumedKeys[key]) continue
                let r = dockWindow.runningByClass[key]
                items.push({
                    name: r.class, exec: "", icon: r.class, wmclass: key,
                    pinned: false,
                    running: true,
                    classKey: key,
                    addresses: r.addresses,
                    title: r.title
                })
            }
        }

        // Skip the reassignment if nothing actually changed. hyprctl polling
        // produces a brand-new object every 900ms even when nothing moved;
        // without this guard the Repeater tears down/rebuilds every icon on
        // each poll, the pill's width flickers for a frame, and that flicker
        // was toggling hover state and making the whole dock bounce up/down.
        let newSig = JSON.stringify(items)
        if (newSig === dockWindow._dockItemsSig) return
        dockWindow._dockItemsSig = newSig
        dockWindow.dockItems = items
    }

    property string _dockItemsSig: ""

    Connections { target: dockWindow; function onPinnedAppsChanged() { rebuildDockItems() } }
    Connections { target: dockWindow; function onRunningByClassChanged() { rebuildDockItems() } }
    Connections { target: dockWindow; function onShowRunningChanged() { rebuildDockItems() } }

    // =====================================================================
    // ACTIONS
    // =====================================================================
    function launch(execStr) {
        if (!execStr || execStr === "") return
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "--", execStr])
    }

    function focusOrCycle(item) {
        if (!item.addresses || item.addresses.length === 0) { launch(item.exec); return }
        let idx = dockWindow.focusCursor[item.classKey] || 0
        idx = idx % item.addresses.length
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.addresses[idx]])
        let cursor = dockWindow.focusCursor
        cursor[item.classKey] = idx + 1
        dockWindow.focusCursor = cursor
    }

    function isPinned(wmclassOrName, exec) {
        for (let p of dockWindow.pinnedApps) {
            if (exec && p.exec === exec) return true
            if (wmclassOrName && p.wmclass && p.wmclass.toLowerCase() === wmclassOrName.toLowerCase()) return true
        }
        return false
    }

    function pinApp(app) {
        if (isPinned(app.wmclass, app.exec)) return
        let arr = dockWindow.pinnedApps.slice()
        arr.push({ name: app.name, exec: app.exec, icon: app.icon, wmclass: app.wmclass || app.name.toLowerCase() })
        dockWindow.pinnedApps = arr
    }

    function togglePin(app) {
        if (isPinned(app.wmclass, app.exec)) {
            dockWindow.pinnedApps = dockWindow.pinnedApps.filter(p => p.exec !== app.exec)
        } else {
            pinApp(app)
        }
    }

    function unpinAt(index) {
        let arr = dockWindow.pinnedApps.slice()
        arr.splice(index, 1)
        dockWindow.pinnedApps = arr
    }

    function movePinned(index, dir) {
        let arr = dockWindow.pinnedApps.slice()
        let ni = index + dir
        if (ni < 0 || ni >= arr.length) return
        let tmp = arr[index]
        arr[index] = arr[ni]
        arr[ni] = tmp
        dockWindow.pinnedApps = arr
    }

    // =====================================================================
    // LAYOUT CONSTANTS
    // =====================================================================
    readonly property int dockPadding: 10
    readonly property int itemSpacing: 8
    readonly property int dockAreaHeight: iconSize + dockPadding * 2 + 14
    readonly property int revealStrip: autohide ? 10 : 0
    readonly property int panelBottomGap: 10

    property bool settingsOpen: false
    property int settingsTab: 0 // 0 = Genel, 1 = Uygulamalar

    // Raw hover flag, updated instantly by the MouseArea below.
    property bool pointerInside: false
    // Debounced flag actually driving the show/hide animation, so a
    // sub-threshold flicker at the edge of the hit area (or a momentary
    // layout reflow) can't retrigger the slide animation.
    property bool hoverSettled: false
    onPointerInsideChanged: {
        hoverSettleTimer.stop()
        if (pointerInside) hoverSettled = true
        else hoverSettleTimer.start()
    }
    Timer {
        id: hoverSettleTimer
        interval: 300
        onTriggered: dockWindow.hoverSettled = false
    }

    property bool revealed: !dockWindow.autohide || hoverSettled || settingsOpen

    // =====================================================================
    // HIT AREA (also defines the input mask so clicks pass through elsewhere)
    // =====================================================================
    Item {
        id: hitArea
        width: Math.max(pill.width, 420) + 60
        height: dockWindow.height
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: dockWindow.dockPosition === "center" ? parent.horizontalCenter : undefined
        anchors.left: dockWindow.dockPosition === "left" ? parent.left : undefined
        anchors.right: dockWindow.dockPosition === "right" ? parent.right : undefined
        anchors.leftMargin: dockWindow.dockPosition === "left" ? 24 : 0
        anchors.rightMargin: dockWindow.dockPosition === "right" ? 24 : 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: dockWindow.pointerInside = containsMouse
        }

        // ------------------------------------------------------------
        // THE PILL
        // ------------------------------------------------------------
        Rectangle {
            id: pill
            width: rowLayout.implicitWidth + dockWindow.dockPadding * 2
            height: dockWindow.dockAreaHeight
            radius: height / 2
            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, dockWindow.bgOpacity)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            anchors.horizontalCenter: parent.horizontalCenter
            y: dockWindow.revealed
                ? (parent.height - height - dockWindow.panelBottomGap)
                : (parent.height - dockWindow.revealStrip)

            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: rowLayout
                anchors.centerIn: parent
                spacing: dockWindow.itemSpacing

                Repeater {
                    model: dockWindow.dockItems

                    delegate: Item {
                        id: iconSlot
                        required property var modelData
                        required property int index

                        Layout.preferredWidth: dockWindow.iconSize
                        Layout.preferredHeight: dockWindow.iconSize

                        property bool hovered: iconMouse.containsMouse
                        scale: hovered ? 1.16 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: width * 0.28
                            color: iconSlot.hovered ? mocha.surface1 : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: parent.width * 0.72
                            height: parent.height * 0.72
                            source: modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon
                            sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            visible: modelData.running
                            width: 5; height: 5; radius: 2.5
                            color: mocha.blue
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -7
                        }

                        // Tooltip
                        Rectangle {
                            visible: iconSlot.hovered
                            radius: 6
                            color: mocha.crust
                            border.width: 1
                            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)
                            width: tipText.implicitWidth + 14
                            height: tipText.implicitHeight + 8
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: iconSlot.modelData.name
                                color: mocha.text
                                font.family: "Inter"
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            // Right-click quick-action menu (pin/unpin/close) is disabled for now;
                            // only left/middle click are wired up.
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    dockWindow.focusOrCycle(iconSlot.modelData)
                                } else if (mouse.button === Qt.MiddleButton) {
                                    dockWindow.launch(iconSlot.modelData.exec)
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    visible: dockWindow.dockItems.length > 0
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: dockWindow.iconSize * 0.6
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                }

                // Settings gear
                Item {
                    Layout.preferredWidth: dockWindow.iconSize * 0.72
                    Layout.preferredHeight: dockWindow.iconSize * 0.72
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: gearMouse.containsMouse || dockWindow.settingsOpen ? mocha.surface1 : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: mocha.subtext0
                        font.pixelSize: parent.width * 0.55
                        rotation: dockWindow.settingsOpen ? 45 : 0
                        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: gearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dockWindow.settingsOpen = !dockWindow.settingsOpen
                            if (dockWindow.settingsOpen && hitArea.allApps.length === 0) appFetcher.running = true
                        }
                    }
                }
            }
        }

        property var allApps: []

        Process {
            id: appFetcher
            command: ["python3", paths.home + "/.config/hypr/scripts/quickshell/dock/app_fetcher.py"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { hitArea.allApps = JSON.parse(this.text) } catch (e) { console.log("dock: app list parse error", e) }
                }
            }
        }

        // ------------------------------------------------------------
        // SETTINGS PANEL — big, tabbed, and only closes when you tell it
        // to (gear button or the ✕ here). It never disappears just
        // because the pointer left the dock; `settingsOpen` also keeps
        // the pill itself from autohiding while this is open.
        // ------------------------------------------------------------
        Rectangle {
            id: settingsPanel
            visible: dockWindow.settingsOpen
            width: 460
            height: 480
            radius: 16
            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.97)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1)
            anchors.bottom: pill.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            z: 60

            MouseArea { anchors.fill: parent } // eat clicks so they don't fall through to hide handlers

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // --- Header: title, tabs, close ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text { text: "Dock Ayarları"; color: mocha.text; font.family: "Inter"; font.bold: true; font.pixelSize: 15 }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 22; height: 22; radius: 7
                        color: closeSettingsMouse.containsMouse ? mocha.surface1 : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: mocha.subtext0 }
                        MouseArea { id: closeSettingsMouse; anchors.fill: parent; hoverEnabled: true; onClicked: dockWindow.settingsOpen = false }
                    }
                }

                // --- Tab bar ---
                Row {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [ { label: "Genel", idx: 0 }, { label: "Uygulamalar", idx: 1 } ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 120; height: 32; radius: 9
                            color: dockWindow.settingsTab === modelData.idx ? mocha.surface1 : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: dockWindow.settingsTab === modelData.idx ? mocha.text : mocha.subtext0
                                font.family: "Inter"
                                font.bold: dockWindow.settingsTab === modelData.idx
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: dockWindow.settingsTab = modelData.idx }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) }

                // ==========================================================
                // TAB 0 — GENEL
                // ==========================================================
                Flickable {
                    visible: dockWindow.settingsTab === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: generalCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: generalCol
                        width: parent.width
                        spacing: 16

                        // --- Icon size slider ---
                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Simge boyutu: " + dockWindow.iconSize + "px"; color: mocha.subtext0; font.family: "Inter"; font.pixelSize: 11 }
                            Rectangle {
                                id: sizeTrack
                                width: parent.width; height: 4; radius: 2
                                color: mocha.surface1
                                Rectangle {
                                    width: sizeTrack.width * ((dockWindow.iconSize - 32) / (80 - 32))
                                    height: parent.height; radius: 2; color: mocha.blue
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onPressed: (mouse) => updateFromX(mouse.x)
                                    onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
                                    function updateFromX(x) {
                                        let pct = Math.max(0, Math.min(1, x / sizeTrack.width))
                                        dockWindow.iconSize = Math.round(32 + pct * (80 - 32))
                                    }
                                }
                            }
                        }

                        // --- Background opacity slider ---
                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Arkaplan opaklığı: " + Math.round(dockWindow.bgOpacity * 100) + "%"; color: mocha.subtext0; font.family: "Inter"; font.pixelSize: 11 }
                            Rectangle {
                                id: opacityTrack
                                width: parent.width; height: 4; radius: 2
                                color: mocha.surface1
                                Rectangle {
                                    width: opacityTrack.width * dockWindow.bgOpacity
                                    height: parent.height; radius: 2; color: mocha.mauve
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onPressed: (mouse) => updateFromX(mouse.x)
                                    onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
                                    function updateFromX(x) {
                                        let pct = Math.max(0.2, Math.min(1, x / opacityTrack.width))
                                        dockWindow.bgOpacity = Math.round(pct * 100) / 100
                                    }
                                }
                            }
                        }

                        // --- Toggles ---
                        Column {
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: [
                                    { label: "Otomatik gizle", prop: "autohide" },
                                    { label: "Çalışan uygulamaları göster", prop: "showRunning" }
                                ]
                                delegate: Row {
                                    required property var modelData
                                    width: generalCol.width
                                    spacing: 8
                                    Text {
                                        text: modelData.label
                                        color: mocha.text
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                        width: parent.width - 44
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 36; height: 20; radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: dockWindow[modelData.prop] ? mocha.blue : mocha.surface2
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        Rectangle {
                                            width: 16; height: 16; radius: 8
                                            color: mocha.crust
                                            y: 2
                                            x: dockWindow[modelData.prop] ? parent.width - width - 2 : 2
                                            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: dockWindow[modelData.prop] = !dockWindow[modelData.prop]
                                        }
                                    }
                                }
                            }
                        }

                        // --- Position ---
                        Column {
                            width: parent.width
                            spacing: 4
                            Text { text: "Konum"; color: mocha.subtext0; font.family: "Inter"; font.pixelSize: 11 }
                            Row {
                                spacing: 6
                                Repeater {
                                    model: [ { label: "Sol", val: "left" }, { label: "Orta", val: "center" }, { label: "Sağ", val: "right" } ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 100; height: 28; radius: 8
                                        color: dockWindow.dockPosition === modelData.val ? mocha.blue : mocha.surface0
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: dockWindow.dockPosition === modelData.val ? mocha.crust : mocha.subtext0
                                            font.family: "Inter"
                                            font.pixelSize: 11
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: dockWindow.dockPosition = modelData.val }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================================
                // TAB 1 — UYGULAMALAR
                // ==========================================================
                ColumnLayout {
                    visible: dockWindow.settingsTab === 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    // --- Pinned apps: reorder + remove ---
                    Text { text: "Sabitlenmiş (" + dockWindow.pinnedApps.length + ")"; color: mocha.text; font.family: "Inter"; font.bold: true; font.pixelSize: 12 }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(pinnedCol.implicitHeight, 120)
                        clip: true
                        contentWidth: width
                        contentHeight: pinnedCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: pinnedCol
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: dockWindow.pinnedApps
                                delegate: Row {
                                    required property var modelData
                                    required property int index
                                    width: pinnedCol.width
                                    height: 30
                                    spacing: 4

                                    Image {
                                        width: 18; height: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon
                                        sourceSize: Qt.size(36, 36)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                    Text {
                                        text: modelData.name
                                        color: mocha.subtext0
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                        width: pinnedCol.width - 108
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 20; height: 20; radius: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: upMouse.containsMouse ? mocha.surface1 : "transparent"
                                        Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 8; color: mocha.subtext0 }
                                        MouseArea { id: upMouse; anchors.fill: parent; hoverEnabled: true; onClicked: dockWindow.movePinned(index, -1) }
                                    }
                                    Rectangle {
                                        width: 20; height: 20; radius: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: downMouse.containsMouse ? mocha.surface1 : "transparent"
                                        Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 8; color: mocha.subtext0 }
                                        MouseArea { id: downMouse; anchors.fill: parent; hoverEnabled: true; onClicked: dockWindow.movePinned(index, 1) }
                                    }
                                    Rectangle {
                                        width: 20; height: 20; radius: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: rmMouse.containsMouse ? mocha.red : mocha.surface0
                                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: rmMouse.containsMouse ? mocha.crust : mocha.subtext0 }
                                        MouseArea { id: rmMouse; anchors.fill: parent; hoverEnabled: true; onClicked: dockWindow.unpinAt(index) }
                                    }
                                }
                            }

                            Text {
                                visible: dockWindow.pinnedApps.length === 0
                                text: "Henüz sabitlenmiş uygulama yok — aşağıdan seç."
                                color: mocha.overlay0
                                font.family: "Inter"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) }

                    // --- Installed app browser ---
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Uygulama ara..."
                        color: mocha.text
                        background: Rectangle { color: mocha.surface0; radius: 8 }
                    }

                    GridView {
                        id: appsGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: 84
                        cellHeight: 86
                        model: hitArea.allApps.filter(a => a.name.toLowerCase().includes(searchField.text.toLowerCase()))

                        delegate: Item {
                            required property var modelData
                            width: appsGrid.cellWidth
                            height: appsGrid.cellHeight

                            property bool pinnedNow: dockWindow.isPinned(modelData.wmclass, modelData.exec)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 12
                                color: tileMouse.containsMouse
                                    ? mocha.surface1
                                    : (pinnedNow ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.16) : "transparent")
                                border.width: pinnedNow ? 1 : 0
                                border.color: mocha.blue

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 32; height: 32
                                        source: modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                    }
                                    Text {
                                        width: 72
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.name
                                        color: mocha.text
                                        font.family: "Inter"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    visible: pinnedNow
                                    width: 15; height: 15; radius: 7.5
                                    color: mocha.blue
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 9; color: mocha.crust }
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: dockWindow.togglePin(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
