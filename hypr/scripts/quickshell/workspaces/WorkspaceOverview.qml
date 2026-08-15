kimport QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    anchors.fill: parent
    property var wsData: ({})
    property int activeWs: 1

    Component.onCompleted: fetchData.running = true

    Process {
        id: fetchData
        command: ["bash", "-c", "printf '%s|||%s' \"$(hyprctl clients -j)\" \"$(hyprctl activeworkspace -j)\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim().split("|||")
                if (raw.length < 2) return
                try {
                    var clients = JSON.parse(raw[0].trim())
                    var active  = JSON.parse(raw[1].trim())
                    activeWs = active.id
                    var map = {}
                    for (var i = 1; i <= 10; i++) map[i] = []
                    for (var c of clients) {
                        var wid = c.workspace ? c.workspace.id : -1
                        if (wid >= 1 && wid <= 10) {
                            map[wid].push({
                                title : c.title  || c.class || "?",
                                cls   : c.class  || "",
                                x : c.at[0],   y : c.at[1],
                                w : c.size[0], h : c.size[1]
                            })
                        }
                    }
                    wsData = map
                } catch(e) { console.log("parse err", e) }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 22

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "W O R K S P A C E S"
                color: "#1c1c1c"
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.letterSpacing: 6
            }

            GridLayout {
                columns: 5
                rowSpacing: 10
                columnSpacing: 10
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: 10
                    delegate: Rectangle {
                        id: card
                        width: 170
                        height: 110
                        radius: 10
                        color: (index+1) === activeWs ? "#121212" : "#090909"
                        border.color: (index+1) === activeWs ? "#2a2a2a" : "#131313"
                        border.width: 1
                        clip: true

                        property var wins: wsData[index+1] || []

                        // Workspace numarası
                        Text {
                            anchors { top: parent.top; left: parent.left; margins: 8 }
                            text: index + 1
                            color: (index+1) === activeWs ? "#444444" : "#1e1e1e"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                        }

                        // Pencere mini haritası
                        Item {
                            anchors { fill: parent; margins: 8; topMargin: 22 }

                            Repeater {
                                model: card.wins.length
                                delegate: Rectangle {
                                    property var win: card.wins[index]
                                    property real scaleX: (card.width - 16) / 1920.0
                                    property real scaleY: (card.height - 30) / 1080.0

                                    x: Math.max(0, win.x * scaleX)
                                    y: Math.max(0, win.y * scaleY)
                                    width:  Math.max(20, win.w * scaleX)
                                    height: Math.max(12, win.h * scaleY)
                                    radius: 3
                                    color: (index+1) === activeWs ? "#1e1e1e" : "#141414"
                                    border.color: "#252525"
                                    border.width: 1
                                    clip: true

                                    Text {
                                        anchors { left: parent.left; top: parent.top; margins: 3 }
                                        width: parent.width - 6
                                        text: win.cls
                                        color: "#303030"
                                        font.pixelSize: 6
                                        font.family: "JetBrains Mono"
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Boş workspace
                            Text {
                                visible: card.wins.length === 0
                                anchors.centerIn: parent
                                text: "—"
                                color: "#111111"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 14
                            }
                        }

                        // Hover + tıklama
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: card.color = "#1a1a1a"
                            onExited:  card.color = (index+1) === activeWs ? "#121212" : "#090909"
                            onClicked: {
                                var ws = index + 1
                                Qt.createQmlObject(
                                    'import Quickshell.Io; Process { command: ["hyprctl","dispatch","workspace","' + ws + '"]; running: true }',
                                    card
                                )
                                Qt.callLater(function() {
                                    Qt.createQmlObject(
                                        'import Quickshell.Io; Process { command: ["bash","-c","echo close > /tmp/qs_widget_state"]; running: true }',
                                        card
                                    )
                                })
                            }
                        }
                    }
                }
            }

            // Alt kısayol ipuçları
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Repeater {
                    model: [["tıkla", "geç"], ["Super+M", "pencere taşı"], ["Esc", "kapat"]]
                    delegate: RowLayout {
                        spacing: 6
                        Rectangle {
                            width: hintKey.width + 12
                            height: 18
                            radius: 4
                            color: "#0f0f0f"
                            border.color: "#1a1a1a"
                            border.width: 1
                            Text {
                                id: hintKey
                                anchors.centerIn: parent
                                text: modelData[0]
                                color: "#252525"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 9
                            }
                        }
                        Text {
                            text: modelData[1]
                            color: "#1a1a1a"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
