import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Ui
import qs.Commons

Panel {
  id: root

  moduleName: "amin.display-settings"
  ipcTarget: "amin.display-settings"

  property string selectedId: "builtin"
  property real arrangementZoom: 1
  property var displays: [
    {
      id: "studio",
      name: "Studio Display",
      connector: "DP-2",
      resolution: "2560 × 1440",
      baseWidth: 238,
      baseHeight: 134,
      layoutX: 68,
      layoutY: 70,
      scale: "125",
      brightness: 78,
      refreshRate: "144",
      nightLight: false,
      scheduled: false,
      scheduleFrom: "21:00",
      scheduleTo: "07:00"
    },
    {
      id: "builtin",
      name: "Built-in Display",
      connector: "eDP-1",
      resolution: "1440 × 900",
      baseWidth: 210,
      baseHeight: 132,
      layoutX: 322,
      layoutY: 104,
      scale: "150",
      brightness: 64,
      refreshRate: "60",
      nightLight: true,
      scheduled: true,
      scheduleFrom: "21:00",
      scheduleTo: "07:00"
    },
    {
      id: "portrait",
      name: "Portrait Display",
      connector: "HDMI-A-1",
      resolution: "1200 × 1920",
      baseWidth: 98,
      baseHeight: 158,
      layoutX: 548,
      layoutY: 58,
      scale: "100",
      brightness: 52,
      refreshRate: "75",
      nightLight: true,
      scheduled: false,
      scheduleFrom: "22:00",
      scheduleTo: "06:30"
    }
  ]

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color background: bar ? bar.background : Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color muted: root.alpha(root.foreground, 0.58)
  readonly property var selectedDisplay: displayById(selectedId)
  readonly property var refreshOptions: [
    { value: "60", label: "60 Hz" },
    { value: "75", label: "75 Hz" },
    { value: "100", label: "100 Hz" },
    { value: "120", label: "120 Hz" },
    { value: "144", label: "144 Hz" },
    { value: "165", label: "165 Hz" }
  ]
  readonly property var timeOptions: [
    "18:00", "19:00", "20:00", "21:00", "22:00", "23:00",
    "00:00", "05:00", "06:00", "06:30", "07:00", "08:00"
  ]

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function displayById(id) {
    for (var i = 0; i < displays.length; i++)
      if (displays[i].id === id) return displays[i]
    return displays[0]
  }

  function updateDisplay(id, key, value) {
    var next = []
    for (var i = 0; i < displays.length; i++) {
      var source = displays[i]
      var copy = {}
      for (var field in source) copy[field] = source[field]
      if (copy.id === id) copy[key] = value
      next.push(copy)
    }
    displays = next
  }

  function updateSelected(key, value) {
    updateDisplay(selectedId, key, value)
  }

  function moveDisplay(id, x, y) {
    var scale = Math.max(0.5, arrangementZoom)
    updateDisplay(id, "layoutX", Math.round(x / scale))
    updateDisplay(id, "layoutY", Math.round(y / scale))
  }

  function resetArrangement() {
    var defaults = {
      studio: { x: 68, y: 70 },
      builtin: { x: 322, y: 104 },
      portrait: { x: 548, y: 58 }
    }
    var next = []
    for (var i = 0; i < displays.length; i++) {
      var source = displays[i]
      var copy = {}
      for (var field in source) copy[field] = source[field]
      copy.layoutX = defaults[copy.id].x
      copy.layoutY = defaults[copy.id].y
      next.push(copy)
    }
    displays = next
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: "▣"
    onPressed: function(button) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: panel.fittedContentWidth(Style.space(930))
    contentHeight: panel.cappedContentHeight(Style.space(790))

    Controls.ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
      Controls.ScrollBar.vertical.policy: contentColumn.implicitHeight > height
        ? Controls.ScrollBar.AsNeeded
        : Controls.ScrollBar.AlwaysOff

      Column {
        id: contentColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(titleIcon.implicitHeight, titleBlock.implicitHeight, previewBadge.implicitHeight)

          Text {
            id: titleIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "▣"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
          }

          Column {
            id: titleBlock
            anchors.left: titleIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: previewBadge.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Display Settings"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: "Arrange screens and tune each display"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          BorderSurface {
            id: previewBadge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: previewText.implicitWidth + Style.space(18)
            implicitHeight: previewText.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: Style.selectedFillFor(root.foreground, Color.accent)
            borderSpec: Border.controlSpec("selected", root.foreground, Color.accent)

            Text {
              id: previewText
              anchors.centerIn: parent
              text: "UI PREVIEW"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        BorderSurface {
          width: parent.width
          height: Style.space(318)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

          Item {
            id: arrangementHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(16)
            height: Style.space(32)

            Column {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              PanelSectionHeader {
                text: "ARRANGE DISPLAYS"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                text: "Drag a display to move it · click to edit"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs

              Button {
                text: "−"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                horizontalPadding: Style.space(11)
                enabled: root.arrangementZoom > 0.75
                opacity: enabled ? 1 : 0.4
                onClicked: root.arrangementZoom = Math.max(0.75, root.arrangementZoom - 0.25)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(48)
                text: Math.round(root.arrangementZoom * 100) + "%"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Button {
                text: "+"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                horizontalPadding: Style.space(11)
                enabled: root.arrangementZoom < 1.25
                opacity: enabled ? 1 : 0.4
                onClicked: root.arrangementZoom = Math.min(1.25, root.arrangementZoom + 0.25)
              }

              Button {
                text: "Reset"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.resetArrangement()
              }
            }
          }

          BorderSurface {
            id: canvas
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: arrangementHeader.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(16)
            anchors.topMargin: Style.space(12)
            radius: Math.max(0, Style.cornerRadius - Style.space(2))
            color: root.alpha(root.background, 0.62)
            borderSpec: Border.flat(root.alpha(root.foreground, 0.16), Math.max(1, Style.space(1)))
            clip: true

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.max(1, Style.space(1))
              height: parent.height
              color: root.alpha(root.foreground, 0.06)
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: Math.max(1, Style.space(1))
              color: root.alpha(root.foreground, 0.06)
            }

            Repeater {
              model: root.displays

              Item {
                id: displayTile
                required property var modelData
                required property int index

                readonly property bool selected: root.selectedId === modelData.id
                readonly property real zoom: root.arrangementZoom
                readonly property real bezel: Style.space(5)

                x: modelData.layoutX * zoom
                y: modelData.layoutY * zoom
                width: modelData.baseWidth * zoom
                height: (modelData.baseHeight + 30) * zoom
                z: pointer.drag.active ? 20 : (selected ? 10 : index)

                Behavior on x {
                  enabled: !pointer.drag.active
                  NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                  enabled: !pointer.drag.active
                  NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                BorderSurface {
                  id: monitorFace
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: modelData.baseHeight * displayTile.zoom
                  radius: Math.max(2, Style.cornerRadius * 0.65)
                  color: displayTile.selected
                    ? Style.selectedFillFor(root.foreground, Color.accent)
                    : root.alpha(root.foreground, 0.08)
                  borderSpec: Border.flat(
                    displayTile.selected ? Color.accent : root.alpha(root.foreground, 0.34),
                    displayTile.selected ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1)))

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: displayTile.bezel
                    radius: Math.max(1, parent.radius - displayTile.bezel)
                    gradient: Gradient {
                      GradientStop { position: 0; color: root.alpha(Color.accent, 0.36) }
                      GradientStop { position: 1; color: root.alpha(root.foreground, 0.05) }
                    }

                    Text {
                      anchors.centerIn: parent
                      width: parent.width - Style.space(16)
                      text: modelData.name
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }
                }

                Rectangle {
                  visible: modelData.id !== "portrait"
                  anchors.top: monitorFace.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: Style.space(26) * displayTile.zoom
                  height: Style.space(5) * displayTile.zoom
                  color: displayTile.selected ? Color.accent : root.alpha(root.foreground, 0.28)
                }

                Text {
                  anchors.top: monitorFace.bottom
                  anchors.topMargin: Style.space(8)
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width
                  text: modelData.connector + "  ·  " + modelData.resolution
                  color: displayTile.selected ? root.foreground : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Math.max(8, Style.font.caption * displayTile.zoom)
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }

                MouseArea {
                  id: pointer
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                  drag.target: displayTile
                  drag.minimumX: 0
                  drag.minimumY: 0
                  drag.maximumX: Math.max(0, canvas.width - displayTile.width)
                  drag.maximumY: Math.max(0, canvas.height - displayTile.height)
                  onPressed: root.selectedId = modelData.id
                  onReleased: root.moveDisplay(modelData.id, displayTile.x, displayTile.y)
                }
              }
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(selectedName.implicitHeight, selectedMeta.implicitHeight)

          Text {
            id: selectedName
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedDisplay ? root.selectedDisplay.name : "Display"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            id: selectedMeta
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedDisplay
              ? root.selectedDisplay.connector + "  ·  " + root.selectedDisplay.resolution
              : ""
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(14)

          BorderSurface {
            width: (parent.width - parent.spacing) * 0.59
            height: settingsColumn.implicitHeight + Style.space(30)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

            Column {
              id: settingsColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(15)
              spacing: Style.space(10)

              Item {
                width: parent.width
                implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessValue.implicitHeight)

                PanelSectionHeader {
                  id: brightnessHeader
                  anchors.left: parent.left
                  text: "BRIGHTNESS"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                Text {
                  id: brightnessValue
                  anchors.right: parent.right
                  text: Math.round(brightnessSlider.dragging
                    ? brightnessSlider.liveValue
                    : (root.selectedDisplay ? root.selectedDisplay.brightness : 0)) + "%"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "☼"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }

                PanelSlider {
                  id: brightnessSlider
                  width: parent.width - Style.space(54)
                  bar: root.bar
                  minimum: 1
                  maximum: 100
                  step: 1
                  integer: true
                  value: root.selectedDisplay ? root.selectedDisplay.brightness : 1
                  onMoved: function(value) { root.updateSelected("brightness", value) }
                  onReleased: function(value) { root.updateSelected("brightness", value) }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "☀"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
              }

              PanelSeparator { foreground: root.foreground }

              PanelSectionHeader {
                text: "SCALE"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Row {
                width: parent.width
                spacing: Style.spacing.xs

                Repeater {
                  model: ["100", "125", "150", "175", "200"]

                  Button {
                    required property string modelData
                    width: (settingsColumn.width - Style.spacing.xs * 4) / 5
                    text: modelData + "%"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    bordered: true
                    active: root.selectedDisplay && root.selectedDisplay.scale === modelData
                    onClicked: root.updateSelected("scale", modelData)
                  }
                }
              }

              PanelSeparator { foreground: root.foreground }

              Row {
                width: parent.width
                spacing: Style.space(12)

                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)

                  PanelSectionHeader {
                    text: "REFRESH RATE"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                  }

                  Dropdown {
                    width: parent.width
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.selectedDisplay ? root.selectedDisplay.refreshRate : "60"
                    options: root.refreshOptions
                    onChanged: function(value) { root.updateSelected("refreshRate", value) }
                  }
                }

                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)

                  PanelSectionHeader {
                    text: "RESOLUTION"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                  }

                  BorderSurface {
                    width: parent.width
                    height: Style.spacing.controlHeight
                    radius: Style.cornerRadius
                    color: "transparent"
                    borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                    Text {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.margins: Style.spacing.controlPaddingX
                      text: root.selectedDisplay ? root.selectedDisplay.resolution : ""
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }
          }

          BorderSurface {
            width: parent.width - parent.spacing - (parent.width - parent.spacing) * 0.59
            height: settingsColumn.implicitHeight + Style.space(30)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(15)
              spacing: Style.space(10)

              Item {
                width: parent.width
                implicitHeight: Math.max(nightTitle.implicitHeight, nightSwitch.implicitHeight)

                Column {
                  id: nightTitle
                  anchors.left: parent.left
                  anchors.right: nightSwitch.left
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: "Night Light"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    text: "Warmer colors after dark"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                ToggleSwitch {
                  id: nightSwitch
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  checked: root.selectedDisplay && root.selectedDisplay.nightLight
                  foreground: root.foreground
                  accent: Color.accent
                  onToggled: root.updateSelected("nightLight", !checked)
                }
              }

              PanelSeparator { foreground: root.foreground }

              Item {
                width: parent.width
                implicitHeight: Math.max(scheduleLabel.implicitHeight, scheduleSwitch.implicitHeight)
                opacity: root.selectedDisplay && root.selectedDisplay.nightLight ? 1 : 0.38

                Text {
                  id: scheduleLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Schedule"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                ToggleSwitch {
                  id: scheduleSwitch
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  enabled: root.selectedDisplay && root.selectedDisplay.nightLight
                  checked: root.selectedDisplay && root.selectedDisplay.scheduled
                  foreground: root.foreground
                  accent: Color.accent
                  onToggled: root.updateSelected("scheduled", !checked)
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(10)
                opacity: root.selectedDisplay
                  && root.selectedDisplay.nightLight
                  && root.selectedDisplay.scheduled ? 1 : 0.38

                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)

                  PanelSectionHeader {
                    text: "FROM"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                  }

                  Dropdown {
                    width: parent.width
                    enabled: root.selectedDisplay && root.selectedDisplay.nightLight && root.selectedDisplay.scheduled
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.selectedDisplay ? root.selectedDisplay.scheduleFrom : "21:00"
                    options: root.timeOptions
                    onChanged: function(value) { root.updateSelected("scheduleFrom", value) }
                  }
                }

                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)

                  PanelSectionHeader {
                    text: "TO"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                  }

                  Dropdown {
                    width: parent.width
                    enabled: root.selectedDisplay && root.selectedDisplay.nightLight && root.selectedDisplay.scheduled
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.selectedDisplay ? root.selectedDisplay.scheduleTo : "07:00"
                    options: root.timeOptions
                    onChanged: function(value) { root.updateSelected("scheduleTo", value) }
                  }
                }
              }

              Item { width: 1; height: Style.space(2) }

              Text {
                width: parent.width
                text: root.selectedDisplay && root.selectedDisplay.nightLight
                  ? (root.selectedDisplay.scheduled
                    ? "Active " + root.selectedDisplay.scheduleFrom + "–" + root.selectedDisplay.scheduleTo
                    : "Active until switched off")
                  : "Currently disabled"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }
        }

        BorderSurface {
          width: parent.width
          implicitHeight: footerText.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: root.alpha(Color.accent, 0.10)
          borderSpec: Border.flat(root.alpha(Color.accent, 0.34), Math.max(1, Style.space(1)))

          Text {
            id: footerText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(12)
            text: "Preview mode · Controls are interactive, but no display settings are applied yet."
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }

        Item { width: 1; height: Style.space(2) }
      }
    }
  }
}
