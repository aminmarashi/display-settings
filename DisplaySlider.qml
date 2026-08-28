import QtQuick
import qs.Ui
import qs.Commons

Item {
  id: root

  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property color trackColor: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "#333"
  property color fillColor: bar ? bar.foreground : Color.foreground
  property color knobColor: bar ? bar.foreground : Color.foreground
  property bool dragging: false
  property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
  property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
  property real liveValue: value

  signal pressed(real value)
  signal moved(real value)
  signal released(real value)
  signal canceled()

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.md)

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool hot: pointer.containsMouse || dragging

  onValueChanged: if (!dragging) liveValue = value
  onEnabledChanged: if (!enabled) cancelDrag()
  onVisibleChanged: if (!visible) cancelDrag()

  function cancelDrag() {
    if (!dragging) return
    dragging = false
    liveValue = value
    canceled()
  }

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: root.trackHeight
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    anchors.left: track.left
    anchors.verticalCenter: track.verticalCenter
    height: track.height
    width: track.width * root.progress
    radius: track.radius
    color: root.fillColor

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  BorderSurface {
    width: root.knobSize
    height: root.knobSize
    radius: root.knobSize / 2
    color: root.knobColor
    borderSpec: Border.flat(root.bar ? root.bar.background : "#101315", Math.max(1, Style.space(2)))
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * root.progress - width / 2))
    scale: root.hot ? 1.15 : 1

    Behavior on x {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
      NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    function valueFromX(x) {
      var clamped = Math.max(0, Math.min(track.width, x))
      var next = root.minimum + (clamped / Math.max(1, track.width)) * root.range
      if (root.integer) next = Math.round(next)
      return Math.max(root.minimum, Math.min(root.maximum, next))
    }

    onPressed: function(mouse) {
      root.dragging = true
      root.pressed(root.value)
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onReleased: function(mouse) {
      if (!root.dragging) return
      var committed = root.liveValue
      root.dragging = false
      root.released(committed)
      root.liveValue = root.value
    }
    onCanceled: root.cancelDrag()
    onWheel: function(wheel) {
      var delta = wheel.angleDelta.y > 0 ? root.step : -root.step
      var next = Math.max(root.minimum, Math.min(root.maximum, root.liveValue + delta))
      if (root.integer) next = Math.round(next)
      root.pressed(root.value)
      root.liveValue = next
      root.moved(next)
      root.released(next)
      root.liveValue = root.value
    }
  }
}
