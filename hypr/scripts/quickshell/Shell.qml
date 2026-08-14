//@ pragma UseQApplication
import QtQuick
import Quickshell
import "dynamic-island" as DynamicIslandModule

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main {}
    TopBar {}
    DynamicIslandModule.DynamicIslandHost {}
    Floating {}
}
