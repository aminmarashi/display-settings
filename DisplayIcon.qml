import QtQuick
import qs.Commons

Item {
  id: root

  property color color: Color.foreground
  property bool multiple: false

  implicitWidth: Style.font.displayLarge
  implicitHeight: implicitWidth

  readonly property real strokeWidth: Math.max(1, width * 0.075)
  readonly property real dualScreenWidth: Math.round(width * 0.68)
  readonly property real dualScreenHeight: Math.round(height * 0.46)
  readonly property real rearScreenX: Math.round(width * 0.04)
  readonly property real rearScreenY: Math.round(height * 0.08)
  readonly property real frontScreenX: Math.round(width * 0.27)
  readonly property real frontScreenY: Math.round(height * 0.27)

  Rectangle {
    id: screen
    visible: !root.multiple
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(parent.height * 0.12)
    width: Math.round(parent.width * 0.82)
    height: Math.round(parent.height * 0.58)
    color: "transparent"
    border.color: root.color
    border.width: root.strokeWidth
    radius: Math.max(1, root.strokeWidth * 0.6)
  }

  Rectangle {
    visible: !root.multiple
    anchors.horizontalCenter: parent.horizontalCenter
    y: screen.y + screen.height - root.strokeWidth / 2
    width: root.strokeWidth
    height: parent.height * 0.17
    color: root.color
  }

  Rectangle {
    visible: !root.multiple
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.84
    width: parent.width * 0.46
    height: root.strokeWidth
    color: root.color
    radius: height / 2
  }

  // Draw only the visible edges of the rear display so it appears behind the
  // foreground display without needing to know the panel's background color.
  Rectangle {
    visible: root.multiple
    x: root.rearScreenX
    y: root.rearScreenY
    width: root.dualScreenWidth
    height: root.strokeWidth
    color: root.color
    radius: height / 2
  }

  Rectangle {
    visible: root.multiple
    x: root.rearScreenX
    y: root.rearScreenY
    width: root.strokeWidth
    height: root.dualScreenHeight
    color: root.color
    radius: width / 2
  }

  Rectangle {
    visible: root.multiple
    x: root.rearScreenX + root.dualScreenWidth - root.strokeWidth
    y: root.rearScreenY
    width: root.strokeWidth
    height: root.frontScreenY - root.rearScreenY
    color: root.color
    radius: width / 2
  }

  Rectangle {
    visible: root.multiple
    x: root.rearScreenX
    y: root.rearScreenY + root.dualScreenHeight - root.strokeWidth
    width: root.frontScreenX - root.rearScreenX
    height: root.strokeWidth
    color: root.color
    radius: height / 2
  }

  Rectangle {
    id: frontScreen
    visible: root.multiple
    x: root.frontScreenX
    y: root.frontScreenY
    width: root.dualScreenWidth
    height: root.dualScreenHeight
    color: "transparent"
    border.color: root.color
    border.width: root.strokeWidth
    radius: Math.max(1, root.strokeWidth * 0.6)
  }

  Rectangle {
    id: frontStand
    visible: root.multiple
    x: frontScreen.x + (frontScreen.width - width) / 2
    y: frontScreen.y + frontScreen.height - root.strokeWidth / 2
    width: root.strokeWidth
    height: Math.round(root.height * 0.15)
    color: root.color
  }

  Rectangle {
    visible: root.multiple
    x: frontScreen.x + (frontScreen.width - width) / 2
    y: frontStand.y + frontStand.height - root.strokeWidth / 2
    width: Math.round(root.width * 0.34)
    height: root.strokeWidth
    color: root.color
    radius: height / 2
  }
}
