//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    // =========================================================
    // --- MODULE CAPABILITIES EXPORT
    // =========================================================
    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string iconFont: "Font Awesome 6 Free Solid"
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    // =========================================================
    // --- SCALING & DIMENSIONS
    // =========================================================
    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(400)
    property real baseL: s(340)

    property real preferredWidth: safeActiveEdge === "bottom" ? baseL + 50 : baseW
    property real preferredExtraLength: safeActiveEdge === "bottom" ? baseW : baseL

    property real counterRotation: {
        if (safeActiveEdge === "right") return 180;
        if (safeActiveEdge === "bottom") return 90;
        return 0;
    }

    // =========================================================
    // --- MATUGEN THEMING & STYLING (MINIMALIST)
    // =========================================================
    property color cBase: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.base : "#1e1e2e"
    property color cMantle: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.mantle : "#181825"
    property color cSurface0: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.surface0 : "#313244"
    property color cSurface1: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.surface1 : "#45475a"
    property color cText: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.text : "#cdd6f4"
    property color cSubtext0: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.subtext0 : "#a6adc8"
    property color cMauve: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.mauve : "#cba6f7"
    property color cGreen: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.green : "#a6e3a1"
    property color cRed: typeof mochaColors !== "undefined" && mochaColors ? mochaColors.red : "#f38ba8"

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    // =========================================================
    // --- PERSISTENCE (JSON on disk via cat / base64)
    // =========================================================
    Caching { id: paths }

    property string stateDir: paths.getStateDir("todo")
    property string stateFile: stateDir + "/todo.json"

    property var items: []
    property bool loaded: false

    function loadFromDisk() {
        loadProc.command = ["bash", "-c", "cat '" + stateFile + "' 2>/dev/null"];
        loadProc.running = true;
    }

    Process {
        id: loadProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loaded = true;
                let raw = this.text.trim();
                if (raw === "") return;
                try {
                    root.items = JSON.parse(decodeURIComponent(Qt.atob(raw)));
                } catch (e) {}
            }
        }
    }

    Process { id: saveProc }

    Timer {
        id: saveDebounce
        interval: 250
        onTriggered: {
            let payload = Qt.btoa(encodeURIComponent(JSON.stringify(root.items)));
            saveProc.command = ["bash", "-c", "echo '" + payload + "' | base64 -d > '" + root.stateFile + "'"];
            saveProc.running = true;
        }
    }

    function persist() { saveDebounce.restart(); }

    Component.onCompleted: loadFromDisk()

    function addTodo(text) {
        let trimmed = text.trim();
        if (trimmed === "") return;
        let temp = root.items.slice();
        temp.push({ id: Date.now(), text: trimmed, done: false });
        root.items = temp;
        persist();
    }

    function toggleTodo(id) {
        let temp = root.items.map(it => it.id === id ? { id: it.id, text: it.text, done: !it.done } : it);
        root.items = temp;
        persist();
    }

    function removeTodo(id) {
        root.items = root.items.filter(it => it.id !== id);
        persist();
    }

    function clearDone() {
        root.items = root.items.filter(it => !it.done);
        persist();
    }

    property int doneCount: root.items.filter(it => it.done).length

    // =========================================================
    // --- MASTER ORIENTATION CONTAINER
    // =========================================================
    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.cMantle
            radius: root.s(10)
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(15)
            spacing: root.s(10)

            // --- HEADER ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "To-Do"
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: root.s(16)
                    color: root.cText
                    Layout.fillWidth: true
                }
                Text {
                    text: (root.items.length - root.doneCount) + " left"
                    font.family: "JetBrains Mono"
                    font.pixelSize: root.s(11)
                    color: root.cSubtext0
                }
            }

            // --- INPUT ROW ---
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Rectangle {
                    Layout.fillWidth: true
                    height: root.s(36)
                    radius: root.s(8)
                    color: root.cSurface0
                    border.width: 1
                    border.color: inputField.activeFocus ? root.cMauve : root.cSurface1

                    TextField {
                        id: inputField
                        anchors.fill: parent
                        anchors.leftMargin: root.s(10)
                        anchors.rightMargin: root.s(10)
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: "Add a task..."
                        color: root.cText
                        placeholderTextColor: root.cSubtext0
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(13)
                        background: null
                        onAccepted: {
                            root.addTodo(text);
                            text = "";
                        }
                    }
                }

                Rectangle {
                    width: root.s(36); height: root.s(36); radius: root.s(8)
                    color: root.cMauve
                    Text { anchors.centerIn: parent; text: ""; font.family: root.iconFont; font.pixelSize: root.s(14); color: root.cMantle }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.addTodo(inputField.text); inputField.text = ""; }
                    }
                }
            }

            // --- LIST ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: root.items.length === 0
                    text: root.loaded ? "No tasks yet" : "Loading..."
                    font.family: "JetBrains Mono"
                    font.pixelSize: root.s(12)
                    color: root.cSubtext0
                }

                ListView {
                    anchors.fill: parent
                    model: root.items
                    spacing: root.s(6)
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: root.s(38)
                        radius: root.s(8)
                        color: root.cSurface0
                        border.width: 1
                        border.color: root.cSurface1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.s(10)
                            anchors.rightMargin: root.s(10)
                            spacing: root.s(10)

                            Rectangle {
                                width: root.s(20); height: root.s(20); radius: root.s(6)
                                color: modelData.done ? root.cGreen : "transparent"
                                border.width: 1.5
                                border.color: modelData.done ? root.cGreen : root.cSubtext0

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.done
                                    text: ""
                                    font.family: root.iconFont
                                    font.pixelSize: root.s(10)
                                    color: root.cMantle
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleTodo(modelData.id)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.text
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(12)
                                color: modelData.done ? root.cSubtext0 : root.cText
                                font.strikeout: modelData.done
                                elide: Text.ElideRight
                            }

                            Text {
                                text: ""
                                font.family: root.iconFont
                                font.pixelSize: root.s(12)
                                color: root.cSubtext0
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: root.s(-6)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeTodo(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // --- FOOTER ---
            RowLayout {
                Layout.fillWidth: true
                visible: root.doneCount > 0
                Item { Layout.fillWidth: true }
                Text {
                    text: "Clear completed"
                    font.family: "JetBrains Mono"
                    font.pixelSize: root.s(11)
                    color: root.cSubtext0
                    MouseArea { anchors.fill: parent; anchors.margins: root.s(-6); cursorShape: Qt.PointingHandCursor; onClicked: root.clearDone() }
                }
            }
        }
    }
}
