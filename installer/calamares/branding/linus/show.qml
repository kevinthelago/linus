/* Linus installer slideshow — shown during the copy phase. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        id: slideTimer
        interval: 5000
        repeat:   true
        running:  false
        triggeredOnStart: true
        onTriggered: {
            if (!presentation.goToNextSlide())
                presentation.currentSlide = 0
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#1a1a2e"; z: -1 }
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Welcome to linus")
                font.pointSize: 28
                font.bold: true
                color: "#e8e8f0"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Installing your new desktop…")
                font.pointSize: 16
                color: "#a0a0c0"
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#16213e"; z: -1 }
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Powered by mantle")
                font.pointSize: 24
                font.bold: true
                color: "#e8e8f0"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("A Wayland desktop shell built for the modern web stack")
                font.pointSize: 14
                color: "#a0a0c0"
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#0f3460"; z: -1 }
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Almost there")
                font.pointSize: 24
                font.bold: true
                color: "#e8e8f0"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Configuring your system and installing the bootloader…")
                font.pointSize: 14
                color: "#a0a0c0"
            }
        }
    }

    function onActivate() { slideTimer.running = true  }
    function onLeave()    { slideTimer.running = false }
}
