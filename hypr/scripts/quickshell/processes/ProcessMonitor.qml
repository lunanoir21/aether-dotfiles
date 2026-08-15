//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    MatugenColors { id: _theme }

    readonly property color cBase: _theme.base
    readonly property color cMantle: _theme.mantle
    readonly property color cSurface0: _theme.surface0
    readonly property color cSurface1: _theme.surface1
    readonly property color cText: _theme.text
    readonly property color cSubtext0: _theme.subtext0
    readonly property color cMauve: _theme.mauve
    readonly property color cRed: _theme.red
    readonly property color cGreen: _theme.green
    readonly property color cYellow: _theme.yellow

    property string iconFont: "Font Awesome 6 Free Solid"
    property string currentUser: Quickshell.env("USER") || ""

    // =========================================================
    // --- SAFETY: processes that can never be killed from here
    // =========================================================
    readonly property var protectedNames: [
        "hyprland", "quickshell", "systemd", "init", "xwayland",
        "pipewire", "wireplumber", "dbus-daemon", "polkitd", "polkit-agent",
        "networkmanager", "bluetoothd", "sddm", "gdm", "gdm-wayland-session",
        "hypridle", "hyprpaper", "kwalletd5", "kwalletd6", "gnome-keyring-d", "sshd",
        "kthreadd", "systemd-journal", "systemd-logind", "systemd-udevd",
        "polkit", "upowerd", "colord", "cupsd", "avahi-daemon", "logind"
    ]

    // A process is protected if it's a known critical daemon, owned by
    // another user (we have no business touching those), a kernel thread,
    // or sits at a suspiciously low PID (almost always core system infra).
    function isProtected(pid, name, user, isKernel) {
        if (pid <= 1) return true;
        if (isKernel) return true;
        if (pid < 300) return true;
        if (root.currentUser !== "" && user !== "" && user !== root.currentUser) return true;
        let n = (name || "").toLowerCase();
        for (let i = 0; i < protectedNames.length; i++) {
            if (n === protectedNames[i]) return true;
        }
        return false;
    }

    // =========================================================
    // --- ICON LOOKUP (desktop file Exec -> Icon map, built once per open)
    // =========================================================
    property var iconMap: ({})

    Process {
        id: iconProc
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/processes/proc_icons.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try { root.iconMap = JSON.parse(raw); } catch (e) {}
            }
        }
    }

    // Only returns an icon name when we have a confirmed match from an
    // installed .desktop file. Guessing (e.g. assuming the icon theme has
    // an icon literally named after the binary) produced wrong/generic
    // squares for most CLI and background processes, so we don't do that —
    // those rows just show the plain fallback glyph instead.
    function iconFor(name) {
        let key = (name || "").toLowerCase();
        return root.iconMap[key] || "";
    }

    // =========================================================
    // --- DATA: fetched only while this popup is actually open
    // =========================================================
    property var allProcs: []
    property int sortMode: 0 // 0: CPU, 1: RAM
    property bool groupedMode: false
    property bool isLoading: false
    property string searchText: ""

    property var filteredProcs: {
        let arr = root.allProcs;
        if (root.searchText.trim() !== "") {
            let q = root.searchText.trim().toLowerCase();
            arr = arr.filter(p => p.name.toLowerCase().indexOf(q) !== -1 || String(p.pid).indexOf(q) !== -1);
        }
        return arr;
    }

    property var groupedProcs: {
        let map = {};
        let arr = root.filteredProcs;
        for (let i = 0; i < arr.length; i++) {
            let p = arr[i];
            let key = p.name;
            if (!map[key]) {
                map[key] = { pid: p.pid, pids: [], name: p.name, cpu: 0, rss: 0, user: p.user, isKernel: p.isKernel, count: 0 };
            }
            map[key].pids.push(p.pid);
            map[key].cpu += p.cpu;
            map[key].rss += p.rss;
            map[key].count += 1;
            if (p.user !== map[key].user) map[key].user = ""; // mixed owners -> treat conservatively
        }
        return Object.values(map);
    }

    property var sortedProcs: {
        let arr = (root.groupedMode ? root.groupedProcs : root.filteredProcs).slice();
        if (root.sortMode === 0) arr.sort((a, b) => b.cpu - a.cpu);
        else arr.sort((a, b) => b.rss - a.rss);
        return arr.slice(0, 40);
    }

    property var topCpu: {
        let arr = root.allProcs;
        if (arr.length === 0) return null;
        return arr.reduce((a, b) => (b.cpu > a.cpu ? b : a));
    }

    property var topMem: {
        let arr = root.allProcs;
        if (arr.length === 0) return null;
        return arr.reduce((a, b) => (b.rss > a.rss ? b : a));
    }

    function fmtMem(rssKb) {
        if (rssKb >= 1048576) return (rssKb / 1048576).toFixed(1) + " GB";
        return (rssKb / 1024).toFixed(0) + " MB";
    }

    Process {
        id: psProc
        // %U = owning user, last field flags kernel threads (no resident memory, bracketed comm)
        command: ["bash", "-c", "ps -eo pid,user,pcpu,pmem,rss,comm --no-headers | awk '{print $1\"|\"$2\"|\"$3\"|\"$4\"|\"$5\"|\"$6}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false;
                let raw = this.text.trim();
                if (raw === "") return;
                let list = [];
                let lines = raw.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split("|");
                    if (parts.length < 6) continue;
                    // Skip our own transient scan helpers so they never show up
                    // as "top offender" — they're artifacts of this very scan.
                    if (parts[5] === "ps" || parts[5] === "awk") continue;
                    let rss = parseFloat(parts[4]);
                    list.push({
                        pid: parseInt(parts[0]),
                        user: parts[1],
                        cpu: parseFloat(parts[2]),
                        mem: parseFloat(parts[3]),
                        rss: rss,
                        name: parts[5],
                        isKernel: rss === 0
                    });
                }
                root.allProcs = list;
            }
        }
    }

    function refresh() {
        if (!root.visible) return;
        root.isLoading = true;
        psProc.running = true;
    }

    // =========================================================
    // --- LIVE SYSTEM TOTALS (reuses the shared, ref-counted SysData
    // singleton so this costs nothing extra while other widgets are open,
    // and stops polling entirely the moment we unsubscribe on close)
    // =========================================================
    Component.onCompleted: { SysData.subscribe(); refresh(); iconProc.running = true; }
    Component.onDestruction: SysData.unsubscribe()

    // Only polls while the popup is actually visible on screen.
    // Nothing runs, no data is fetched, while this window is closed —
    // the whole item (and this timer with it) is destroyed on close.
    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    onVisibleChanged: {
        if (visible) refresh();
        else killArm.armedPid = -1;
    }

    QtObject {
        id: killArm
        property int armedPid: -1
    }

    Timer {
        id: killArmResetTimer
        interval: 3000
        onTriggered: killArm.armedPid = -1
    }

    function requestKill(row) {
        let pids = row.pids ? row.pids : [row.pid];
        let anyProtected = false;
        for (let i = 0; i < pids.length; i++) {
            if (root.isProtected(pids[i], row.name, row.user, row.isKernel)) anyProtected = true;
        }
        if (anyProtected) return;

        if (killArm.armedPid === row.pid) {
            for (let i = 0; i < pids.length; i++) {
                Quickshell.execDetached(["kill", String(pids[i])]);
            }
            killArm.armedPid = -1;
            killArmResetTimer.stop();
            Qt.callLater(root.refresh);
        } else {
            killArm.armedPid = row.pid;
            killArmResetTimer.restart();
        }
    }

    // =========================================================
    // --- UI
    // =========================================================
    Rectangle {
        anchors.fill: parent
        color: root.cBase
        radius: 14
        border.width: 1
        border.color: root.cSurface1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            // --- HEADER ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Process Monitor"
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 18
                    color: root.cText
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        rotation: root.isLoading ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 400 } }
                        font.family: root.iconFont
                        font.pixelSize: 12
                        color: root.cText
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                }
            }

            // --- TOTAL SYSTEM USAGE ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        Text { text: "Toplam CPU"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0 }
                        Item { Layout.fillWidth: true }
                        Text { text: SysData.cpu + "%"; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 13; color: SysData.cpu > 80 ? root.cRed : root.cText }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        Text { text: "Toplam RAM"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0 }
                        Item { Layout.fillWidth: true }
                        Text { text: SysData.ramPercent + "% (" + SysData.ramGb.toFixed(1) + " GB)"; font.family: "JetBrains Mono"; font.bold: true; font.pixelSize: 13; color: SysData.ramPercent > 85 ? root.cRed : root.cText }
                    }
                }
            }

            // --- TOP OFFENDERS SUMMARY ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        Text { text: ""; font.family: root.iconFont; font.pixelSize: 13; color: root.cMauve }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.topCpu ? ("En çok CPU: " + root.topCpu.name + " (" + root.topCpu.cpu.toFixed(1) + "%)") : "—"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: root.cText
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        Text { text: ""; font.family: root.iconFont; font.pixelSize: 13; color: root.cGreen }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.topMem ? ("En çok RAM: " + root.topMem.name + " (" + root.fmtMem(root.topMem.rss) + ")") : "—"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: root.cText
                        }
                    }
                }
            }

            // --- SEARCH + TABS ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 8
                    color: root.cSurface0
                    border.width: 1
                    border.color: searchField.activeFocus ? root.cMauve : root.cSurface1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        Text { text: ""; font.family: root.iconFont; font.pixelSize: 11; color: root.cSubtext0 }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "Süreç ara..."
                            color: root.cText
                            placeholderTextColor: root.cSubtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            background: null
                            onTextChanged: root.searchText = text
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 180
                    height: 32
                    radius: 8
                    color: root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    Rectangle {
                        x: 2 + root.sortMode * ((parent.width - 4) / 2)
                        y: 2
                        width: (parent.width - 4) / 2
                        height: parent.height - 4
                        radius: 6
                        color: root.cMauve
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                    }
                    Row {
                        anchors.fill: parent
                        anchors.margins: 2
                        Repeater {
                            model: ["CPU", "RAM"]
                            Item {
                                width: 88; height: parent.height
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: "JetBrains Mono"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: root.sortMode === index ? root.cMantle : root.cText
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sortMode = index }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 100
                    height: 32
                    radius: 8
                    color: root.groupedMode ? root.cMauve : root.cSurface0
                    border.width: 1; border.color: root.cSurface1
                    Text {
                        anchors.centerIn: parent
                        text: "Grupla"
                        font.family: "JetBrains Mono"
                        font.bold: true
                        font.pixelSize: 12
                        color: root.groupedMode ? root.cMantle : root.cText
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.groupedMode = !root.groupedMode }
                }
            }

            // --- LIST HEADER ---
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.preferredWidth: 28; text: ""; font.pixelSize: 11 }
                Text { Layout.preferredWidth: 55; text: root.groupedMode ? "Adet" : "PID"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0 }
                Text { Layout.fillWidth: true; text: "İsim"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0 }
                Text { Layout.preferredWidth: 70; text: "CPU"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0; horizontalAlignment: Text.AlignRight }
                Text { Layout.preferredWidth: 80; text: "RAM"; font.family: "JetBrains Mono"; font.pixelSize: 11; color: root.cSubtext0; horizontalAlignment: Text.AlignRight }
                Text { Layout.preferredWidth: 36; text: ""; font.pixelSize: 11 }
            }

            // --- LIST ---
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.sortedProcs
                spacing: 4

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 38
                    radius: 8
                    color: root.cSurface0

                    property bool protected_: root.isProtected(modelData.pid, modelData.name, modelData.user, modelData.isKernel)
                    property bool armed: killArm.armedPid === modelData.pid

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10

                        // App icon — only attempted for processes we could confidently
                        // match to an installed app (see iconFor()); everything else
                        // just gets the plain fallback glyph instead of a wrong/generic icon.
                        Item {
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20

                            property string resolvedIcon: root.iconFor(modelData.name)

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: parent.resolvedIcon !== "" ? ("image://icon/" + parent.resolvedIcon) : ""
                                asynchronous: true
                                visible: parent.resolvedIcon !== "" && status === Image.Ready
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: ""
                                font.family: root.iconFont
                                font.pixelSize: 11
                                color: root.cSubtext0
                            }
                        }

                        Text {
                            Layout.preferredWidth: 55
                            text: root.groupedMode ? String(modelData.count) : String(modelData.pid)
                            font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.cSubtext0
                        }
                        Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.cText }
                        Text { Layout.preferredWidth: 70; text: modelData.cpu.toFixed(1) + "%"; horizontalAlignment: Text.AlignRight; font.family: "JetBrains Mono"; font.pixelSize: 12; color: modelData.cpu > 50 ? root.cRed : root.cText }
                        Text { Layout.preferredWidth: 80; text: root.fmtMem(modelData.rss); horizontalAlignment: Text.AlignRight; font.family: "JetBrains Mono"; font.pixelSize: 12; color: root.cText }

                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            radius: 7
                            visible: !protected_
                            color: armed ? root.cRed : "transparent"
                            border.width: 1
                            border.color: armed ? root.cRed : root.cSubtext0
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: root.iconFont
                                font.pixelSize: 11
                                color: armed ? root.cMantle : root.cSubtext0
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.requestKill(modelData)
                            }
                        }

                        Item {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            visible: protected_
                            Text { anchors.centerIn: parent; text: ""; font.family: root.iconFont; font.pixelSize: 11; color: root.cSubtext0 }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Bir işlemi kapatmak için çöp kutusuna tıkla, onaylamak için tekrar tıkla (3 sn içinde). Kilit ikonu = korumalı/başkasına ait süreç."
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                color: root.cSubtext0
                wrapMode: Text.WordWrap
            }
        }
    }
}
