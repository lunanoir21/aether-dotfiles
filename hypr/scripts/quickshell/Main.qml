//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "dynamic-island" as DynamicIslandModule

// The one thing this shell hosts right now — everything else was removed
// on purpose (see the repo README) and gets rebuilt from scratch here as
// it's designed, not migrated back in wholesale.
ShellRoot {
    DynamicIslandModule.DynamicIslandHost {}

    // Real NotificationServer, per Dynamic Island's own README: the island
    // is the surface, not a notification daemon, so whatever hosts it has
    // to actually own this. Feeds notifyWithActions over IPC and answers
    // back through notificationBridge when a call is answered/declined or
    // a reply is sent — see dynamic-island/README.md's "Calls and inline
    // reply" section for the full explanation.
    NotificationServer {
        id: notifications
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true

        property var live: ({})
        property int counter: 0

        onNotification: (n) => {
            n.tracked = true
            counter++
            live[counter] = n

            let actions = []
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++)
                    actions.push({ id: n.actions[i].identifier, text: n.actions[i].text })
            }

            Quickshell.execDetached(["quickshell", "-p", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/Main.qml",
                "ipc", "call", "dynamicIsland", "notifyWithActions",
                n.appName, n.summary, n.body,
                n.image !== "" ? n.image : n.appIcon,
                Qt.btoa(JSON.stringify(actions)), String(counter),
                n.hasInlineReply ? "true" : "false", n.inlineReplyPlaceholder])
        }
    }

    IpcHandler {
        target: "notificationBridge"

        function invokeAction(uid: string, actionId: string): void {
            let n = notifications.live[uid]
            if (!n || !n.actions) return
            for (let i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === actionId) { n.actions[i].invoke(); break }
            }
        }

        function sendInlineReply(uid: string, text: string): void {
            let n = notifications.live[uid]
            if (n && n.hasInlineReply) n.sendInlineReply(text)
        }
    }
}
