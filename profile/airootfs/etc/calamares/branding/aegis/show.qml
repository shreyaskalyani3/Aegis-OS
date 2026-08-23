/* Aegis OS — Calamares slideshow (API v2). Text-only, no external assets. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function onActivate()   { presentation.startAutoAdvance(9000); }
    function onLeave()      { presentation.stopAutoAdvance(); }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            Column {
                anchors.centerIn: parent
                spacing: 18
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "AEGIS OS"
                    color: "#f0f6fc"
                    font.pixelSize: 46
                    font.bold: true
                    font.letterSpacing: 8
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "— SENTINEL —"
                    color: "#ff2e4d"
                    font.pixelSize: 20
                    font.letterSpacing: 6
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Offensive & Defensive Security · Agent-Native"
                    color: "#8b949e"
                    font.pixelSize: 16
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { text: "A complete arsenal";  color: "#f0f6fc"; font.pixelSize: 30; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "2800+ security tools on tap via the BlackArch repositories."; color: "#c9d1d9"; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Install a group any time:  tools install web"; color: "#39c5cf"; font.pixelSize: 15; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { text: "AI agents, built in"; color: "#f0f6fc"; font.pixelSize: 30; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Claude Code · OpenCode · Aider · Codex"; color: "#c9d1d9"; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Launch one:  ai        Configure keys:  setup"; color: "#39c5cf"; font.pixelSize: 15; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { text: "For authorized use only"; color: "#f0f6fc"; font.pixelSize: 28; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Only test systems you own or have written permission to assess."; color: "#c9d1d9"; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}
