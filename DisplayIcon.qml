import QtQuick
import qs.Commons

Item {
  id: root

  property color color: Color.foreground

  implicitWidth: Style.font.displayLarge
  implicitHeight: implicitWidth

  readonly property real strokeWidth: Math.max(1, width * 0.075)

  Rectangle {
    id: screen
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
    anchors.horizontalCenter: parent.horizontalCenter
    y: screen.y + screen.height - root.strokeWidth / 2
    width: root.strokeWidth
    height: parent.height * 0.17
    color: root.color
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.84
    width: parent.width * 0.46
    height: root.strokeWidth
    color: root.color
    radius: height / 2
  }
}
