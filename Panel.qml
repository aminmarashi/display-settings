import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root

  moduleName: "amin.display-settings"
  ipcTarget: "amin.display-settings"

  property string selectedId: ""
  property real arrangementZoom: 1
  property var displays: []
  property bool draggingDisplay: false
  property bool stateLoaded: false
  property bool nightLightEnabled: false
  property bool scheduleEnabled: false
  property string scheduleFrom: "21:00"
  property string scheduleTo: "07:00"
  property int brightnessValue: 50
  property bool brightnessAvailable: false
  property bool brightnessLoading: false
  property string brightnessMonitor: ""
  property bool brightnessEditing: false
  property var brightnessDragSnapshot: null
  property string brightnessEditMonitor: ""
  property int pendingBrightnessValue: 50
  property bool brightnessSetQueued: false
  property bool brightnessCommitPending: false
  property bool brightnessRollbackPending: false
  property bool brightnessHardwareTouched: false
  property string brightnessRollbackMonitor: ""
  property int brightnessRollbackValue: 50
  property string brightnessApplyError: ""
  property string statusMessage: ""
  property bool statusIsError: false
  property string pendingSuccess: ""
  property bool pendingBrightnessReload: false
  property string actionError: ""
  property var optimisticSnapshot: null
  property int uiGeneration: 0
  property bool stateRefreshPending: false
  property bool brightnessRefreshPending: false
  property bool scheduleDraftDirty: false
  property bool retainPanelOpen: false

  readonly property string backendPath: Qt.resolvedUrl("bin/display-settings").toString().replace("file://", "")
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color background: bar ? bar.background : Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color muted: alpha(foreground, 0.58)
  readonly property var selectedDisplay: displayById(selectedId)
  readonly property bool brightnessBusy: brightnessEditing || brightnessCommitPending
    || brightnessRollbackPending || brightnessApplyProc.running || brightnessRollbackProc.running
  readonly property bool applying: actionProc.running || brightnessBusy
  readonly property var scaleOptions: [1, 1.25, 1.6, 2]
  readonly property var timeOptions: [
    "18:00", "19:00", "20:00", "21:00", "22:00", "23:00",
    "00:00", "05:00", "06:00", "06:30", "07:00", "08:00"
  ]
  readonly property real layoutMinX: layoutBound("minX")
  readonly property real layoutMinY: layoutBound("minY")
  readonly property real layoutMaxX: layoutBound("maxX")
  readonly property real layoutMaxY: layoutBound("maxY")

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function open() {
    controller.show()
  }

  function close() {
    retainPanelOpen = false
    panelRetentionTimer.stop()
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function restorePanelAfterAction() {
    if (!retainPanelOpen) return
    if (!opened) controller.show()
    panelRetentionTimer.restart()
  }

  function displayById(id) {
    for (var i = 0; i < displays.length; i++)
      if (displays[i].name === id) return displays[i]
    return null
  }

  function cloneDisplays(source) {
    var result = []
    for (var i = 0; i < source.length; i++) {
      var copy = {}
      for (var field in source[i]) {
        var value = source[i][field]
        copy[field] = value && typeof value.slice === "function" ? value.slice() : value
      }
      result.push(copy)
    }
    return result
  }

  function snapshotUi() {
    return {
      displays: cloneDisplays(displays),
      selectedId: selectedId,
      nightLightEnabled: nightLightEnabled,
      scheduleEnabled: scheduleEnabled,
      scheduleFrom: scheduleFrom,
      scheduleTo: scheduleTo,
      scheduleDraftDirty: scheduleDraftDirty,
      brightnessValue: brightnessValue,
      brightnessAvailable: brightnessAvailable
    }
  }

  function restoreUi(snapshot) {
    if (!snapshot) return
    displays = cloneDisplays(snapshot.displays || [])
    selectedId = snapshot.selectedId || ""
    nightLightEnabled = !!snapshot.nightLightEnabled
    scheduleEnabled = !!snapshot.scheduleEnabled
    scheduleFrom = snapshot.scheduleFrom || "21:00"
    scheduleTo = snapshot.scheduleTo || "07:00"
    scheduleDraftDirty = !!snapshot.scheduleDraftDirty
    brightnessValue = Number(snapshot.brightnessValue)
    brightnessAvailable = !!snapshot.brightnessAvailable
  }

  function updateDisplay(name, changes) {
    var next = cloneDisplays(displays)
    for (var i = 0; i < next.length; i++) {
      if (next[i].name !== name) continue
      for (var field in changes) next[i][field] = changes[field]
      break
    }
    displays = next
  }

  function logicalWidth(display) {
    if (!display) return 1
    return ((display.transform % 2) ? display.height : display.width) / Math.max(0.1, display.scale)
  }

  function logicalHeight(display) {
    if (!display) return 1
    return ((display.transform % 2) ? display.width : display.height) / Math.max(0.1, display.scale)
  }

  function layoutBound(kind) {
    if (displays.length === 0) return 0
    var value
    for (var i = 0; i < displays.length; i++) {
      var display = displays[i]
      var candidate
      if (kind === "minX") candidate = display.x
      else if (kind === "minY") candidate = display.y
      else if (kind === "maxX") candidate = display.x + logicalWidth(display)
      else candidate = display.y + logicalHeight(display)
      if (value === undefined || (kind.indexOf("min") === 0 ? candidate < value : candidate > value)) value = candidate
    }
    return value || 0
  }

  function displayLabel(display) {
    if (!display) return "Display"
    var description = String(display.description || "").trim()
    return description === "" ? display.name : description
  }

  function displayResolution(display) {
    return display ? display.width + " × " + display.height : ""
  }

  function formatRate(rate) {
    var number = Number(rate)
    if (!isFinite(number)) return String(rate)
    return Math.abs(number - Math.round(number)) < 0.01 ? String(Math.round(number)) : number.toFixed(2)
  }

  function parseMode(mode) {
    var match = String(mode).match(/^(\d+)x(\d+)@([0-9.]+)Hz$/)
    return match ? { width: Number(match[1]), height: Number(match[2]), rate: Number(match[3]) } : null
  }

  function refreshOptionsFor(display) {
    if (!display) return []
    var options = []
    var seen = {}
    var modes = display.availableModes || []
    for (var i = 0; i < modes.length; i++) {
      var parsed = parseMode(modes[i])
      if (!parsed || parsed.width !== display.width || parsed.height !== display.height) continue
      var key = parsed.rate.toFixed(3)
      if (seen[key]) continue
      seen[key] = true
      options.push({ value: String(modes[i]), label: formatRate(parsed.rate) + " Hz" })
    }
    if (options.length === 0) {
      var fallback = display.width + "x" + display.height + "@" + display.refreshRate + "Hz"
      options.push({ value: fallback, label: formatRate(display.refreshRate) + " Hz" })
    }
    return options
  }

  function currentModeFor(display) {
    if (!display) return ""
    var options = refreshOptionsFor(display)
    var closest = options[0].value
    var difference = Number.MAX_VALUE
    for (var i = 0; i < options.length; i++) {
      var parsed = parseMode(options[i].value)
      if (!parsed) continue
      var candidate = Math.abs(parsed.rate - Number(display.refreshRate))
      if (candidate < difference) {
        closest = options[i].value
        difference = candidate
      }
    }
    return closest
  }

  function refresh() {
    if (actionProc.running || draggingDisplay || brightnessBusy) {
      stateRefreshPending = true
      return
    }
    if (stateProc.running) {
      stateRefreshPending = true
      return
    }
    stateRefreshPending = false
    stateProc.requestGeneration = uiGeneration
    stateProc.output = ""
    stateProc.running = true
  }

  function loadBrightness() {
    if (!selectedDisplay) return
    if (actionProc.running || brightnessBusy) {
      brightnessRefreshPending = true
      return
    }
    if (brightnessProc.running) {
      brightnessRefreshPending = true
      return
    }
    brightnessRefreshPending = false
    brightnessMonitor = selectedId
    brightnessLoading = true
    brightnessProc.requestGeneration = uiGeneration
    brightnessProc.output = ""
    brightnessProc.command = [backendPath, "brightness", selectedId]
    brightnessProc.running = true
  }

  function beginBrightnessEdit() {
    brightnessDragSnapshot = snapshotUi()
    brightnessEditMonitor = selectedId
    brightnessHardwareTouched = false
    brightnessSetQueued = false
    brightnessCommitPending = false
    brightnessRollbackPending = false
    brightnessEditing = true
    uiGeneration += 1
    stateRefreshPending = false
    brightnessRefreshPending = false
    reconcileTimer.stop()
  }

  function previewBrightness(value) {
    brightnessValue = Math.round(value)
    pendingBrightnessValue = brightnessValue
    brightnessSetQueued = true
    if (!brightnessApplyProc.running && !brightnessThrottle.running) brightnessThrottle.start()
  }

  function startBrightnessApply() {
    if (!brightnessSetQueued || brightnessApplyProc.running || brightnessRollbackPending) return
    brightnessSetQueued = false
    brightnessApplyError = ""
    brightnessHardwareTouched = true
    brightnessApplyProc.command = [backendPath, "brightness", brightnessEditMonitor, String(pendingBrightnessValue)]
    brightnessApplyProc.running = true
  }

  function commitBrightness(value) {
    brightnessEditing = false
    brightnessCommitPending = true
    brightnessThrottle.stop()
    pendingBrightnessValue = Math.round(value)
    brightnessValue = pendingBrightnessValue
    brightnessSetQueued = true
    startBrightnessApply()
  }

  function finishBrightnessCommit() {
    brightnessCommitPending = false
    brightnessHardwareTouched = false
    brightnessDragSnapshot = null
    stateRefreshPending = false
    brightnessRefreshPending = false
    showStatus("Brightness updated", false)
    reconcileTimer.reloadBrightness = true
    reconcileTimer.restart()
  }

  function abortBrightnessEdit(message) {
    var snapshot = brightnessDragSnapshot
    if (!snapshot) return

    brightnessThrottle.stop()
    brightnessSetQueued = false
    brightnessCommitPending = false
    brightnessEditing = false
    brightnessDragSnapshot = null
    uiGeneration += 1
    stateRefreshPending = false
    brightnessRefreshPending = false

    brightnessRollbackMonitor = brightnessEditMonitor
    brightnessRollbackValue = Math.round(Number(snapshot.brightnessValue))
    brightnessRollbackPending = brightnessHardwareTouched
    restoreUi(snapshot)
    if (brightnessSlider.dragging) brightnessSlider.cancelDrag()

    if (message) showStatus(message, true)
    if (brightnessRollbackPending && !brightnessApplyProc.running) Qt.callLater(startBrightnessRollback)
  }

  function startBrightnessRollback() {
    if (!brightnessRollbackPending || brightnessApplyProc.running || brightnessRollbackProc.running) return
    brightnessRollbackPending = false
    brightnessRollbackProc.error = ""
    brightnessRollbackProc.command = [backendPath, "brightness", brightnessRollbackMonitor, String(brightnessRollbackValue)]
    brightnessRollbackProc.running = true
  }

  function runAction(args, successMessage, reloadBrightness, snapshot) {
    if (actionProc.running || brightnessBusy) {
      if (snapshot) restoreUi(snapshot)
      return false
    }
    retainPanelOpen = opened
    panelRetentionTimer.stop()
    optimisticSnapshot = snapshot || snapshotUi()
    uiGeneration += 1
    stateRefreshPending = false
    brightnessRefreshPending = false
    pendingSuccess = successMessage
    pendingBrightnessReload = reloadBrightness === true
    actionError = ""
    actionProc.command = [backendPath].concat(args)
    actionProc.running = true
    return true
  }

  function showStatus(message, error) {
    statusMessage = message
    statusIsError = error === true
    statusTimer.restart()
  }

  function applyArrangement(movedName, screenX, screenY) {
    if (canvas.layoutScale <= 0) return
    var movedX = Math.round(((screenX - canvas.originX) / canvas.layoutScale) / 10) * 10
    var movedY = Math.round(((screenY - canvas.originY) / canvas.layoutScale) / 10) * 10
    var layout = []
    var minimumX = Number.MAX_VALUE
    var minimumY = Number.MAX_VALUE

    for (var i = 0; i < displays.length; i++) {
      var display = displays[i]
      var x = display.name === movedName ? movedX : display.x
      var y = display.name === movedName ? movedY : display.y
      layout.push({ name: display.name, x: x, y: y })
      minimumX = Math.min(minimumX, x)
      minimumY = Math.min(minimumY, y)
    }

    var optimistic = []
    for (var j = 0; j < layout.length; j++) {
      layout[j].x = Math.max(0, Math.round(layout[j].x - minimumX))
      layout[j].y = Math.max(0, Math.round(layout[j].y - minimumY))
      var source = displayById(layout[j].name)
      var copy = {}
      for (var field in source) copy[field] = source[field]
      copy.x = layout[j].x
      copy.y = layout[j].y
      optimistic.push(copy)
    }
    var snapshot = snapshotUi()
    displays = optimistic
    runAction(["arrange", JSON.stringify(layout)], "Display arrangement saved", false, snapshot)
  }

  Component.onCompleted: refresh()
  onSelectedIdChanged: {
    brightnessAvailable = false
    brightnessLoading = false
    Qt.callLater(loadBrightness)
  }
  onOpenedChanged: {
    if (opened) refresh()
    else if (retainPanelOpen) Qt.callLater(restorePanelAfterAction)
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusTimer
    interval: 4000
    onTriggered: root.statusMessage = ""
  }

  Timer {
    id: reconcileTimer
    // A successful backend exit is authoritative. Reconcile later so a
    // compositor/output transition cannot flash the previous hardware state.
    interval: 5000
    property bool reloadBrightness: false
    onTriggered: {
      root.refresh()
      if (reloadBrightness) Qt.callLater(root.loadBrightness)
      reloadBrightness = false
    }
  }

  Timer {
    id: panelRetentionTimer
    interval: 2000
    onTriggered: root.retainPanelOpen = false
  }

  Timer {
    id: brightnessThrottle
    interval: 75
    onTriggered: root.startBrightnessApply()
  }

  Process {
    id: stateProc
    command: [root.backendPath, "state"]
    property string output: ""
    property int requestGeneration: -1

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: stateProc.output = String(text || "")
    }
    stderr: StdioCollector {
      id: stateError
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var current = requestGeneration === root.uiGeneration
        && !actionProc.running && !root.draggingDisplay && !root.brightnessBusy
      if (exitCode !== 0) {
        if (current) root.showStatus(String(stateError.text || "Could not read display settings").trim(), true)
      } else if (current) {
        try {
          var state = JSON.parse(stateProc.output || "{}")
          root.displays = state.displays || []
          root.nightLightEnabled = !!(state.nightLight && state.nightLight.enabled)
          root.scheduleEnabled = !!(state.nightLight && state.nightLight.schedule && state.nightLight.schedule.enabled)
          if (state.nightLight && state.nightLight.schedule
              && (root.scheduleEnabled || !root.scheduleDraftDirty)) {
            root.scheduleFrom = state.nightLight.schedule.from || "21:00"
            root.scheduleTo = state.nightLight.schedule.to || "07:00"
            root.scheduleDraftDirty = false
          }
          if (!root.displayById(root.selectedId)) {
            root.selectedId = ""
            for (var i = 0; i < root.displays.length; i++)
              if (root.displays[i].focused) root.selectedId = root.displays[i].name
            if (root.selectedId === "" && root.displays.length > 0) root.selectedId = root.displays[0].name
          }
          root.stateLoaded = true
          Qt.callLater(root.loadBrightness)
        } catch (error) {
          root.showStatus("Display state was not valid JSON", true)
        }
      }
      if (root.stateRefreshPending && !actionProc.running
          && !root.draggingDisplay && !root.brightnessBusy) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: brightnessProc
    property string output: ""
    property int requestGeneration: -1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: brightnessProc.output = String(text || "")
    }
    onExited: function(exitCode) {
      root.brightnessLoading = false
      var current = requestGeneration === root.uiGeneration
        && !actionProc.running && !root.brightnessBusy
        && root.selectedId === root.brightnessMonitor
      if (exitCode === 0 && current) {
        try {
          var result = JSON.parse(brightnessProc.output || "{}")
          root.brightnessAvailable = !!result.available
          if (result.available) root.brightnessValue = Math.round(Number(result.value))
        } catch (error) {
          root.brightnessAvailable = false
        }
      }
      if ((root.brightnessRefreshPending || root.selectedId !== root.brightnessMonitor)
          && !actionProc.running && !root.brightnessBusy) Qt.callLater(root.loadBrightness)
    }
  }

  Process {
    id: brightnessApplyProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.brightnessApplyError = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (root.brightnessRollbackPending) {
        Qt.callLater(root.startBrightnessRollback)
        return
      }
      if (exitCode !== 0) {
        root.abortBrightnessEdit(root.brightnessApplyError || "Could not update brightness")
        return
      }
      if (root.brightnessSetQueued) {
        if (root.brightnessCommitPending) Qt.callLater(root.startBrightnessApply)
        else brightnessThrottle.restart()
      } else if (root.brightnessCommitPending) {
        root.finishBrightnessCommit()
      }
    }
  }

  Process {
    id: brightnessRollbackProc
    property string error: ""
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: brightnessRollbackProc.error = String(text || "").trim()
    }
    onExited: function(exitCode) {
      root.brightnessHardwareTouched = false
      if (exitCode !== 0) root.showStatus(brightnessRollbackProc.error || "Could not restore the previous brightness", true)
      reconcileTimer.reloadBrightness = true
      reconcileTimer.restart()
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionError = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.optimisticSnapshot = null
        root.showStatus(root.pendingSuccess, false)
        root.stateRefreshPending = false
        root.brightnessRefreshPending = false
        reconcileTimer.reloadBrightness = root.pendingBrightnessReload
        reconcileTimer.restart()
      } else {
        root.uiGeneration += 1
        root.restoreUi(root.optimisticSnapshot)
        root.optimisticSnapshot = null
        root.stateRefreshPending = false
        root.brightnessRefreshPending = false
        root.showStatus(root.actionError || "The display change failed", true)
      }
      root.pendingBrightnessReload = false
      Qt.callLater(root.restorePanelAfterAction)
    }
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "▦" : "▣"
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
      Controls.ScrollBar.vertical.policy: contentColumn.implicitHeight > height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff

      Column {
        id: contentColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(titleIcon.implicitHeight, titleBlock.implicitHeight, liveBadge.implicitHeight)

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
            anchors.right: liveBadge.left
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
              text: root.displays.length === 1 ? "1 connected display" : root.displays.length + " connected displays"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          BorderSurface {
            id: liveBadge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: liveText.implicitWidth + Style.space(18)
            implicitHeight: liveText.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: root.alpha(Color.accent, 0.16)
            borderSpec: Border.flat(root.alpha(Color.accent, 0.48), Math.max(1, Style.space(1)))
            Text {
              id: liveText
              anchors.centerIn: parent
              text: root.applying ? "APPLYING" : "LIVE"
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
              PanelSectionHeader { text: "ARRANGE DISPLAYS"; foreground: root.foreground; fontFamily: root.fontFamily }
              Text {
                text: root.displays.length > 1 ? "Drag a display to reposition it · click to edit" : "Connect another display to arrange your desktop"
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
                text: "−"; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true
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
                text: "+"; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true
                horizontalPadding: Style.space(11)
                enabled: root.arrangementZoom < 1.25
                opacity: enabled ? 1 : 0.4
                onClicked: root.arrangementZoom = Math.min(1.25, root.arrangementZoom + 0.25)
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

            readonly property real layoutWidth: Math.max(1, root.layoutMaxX - root.layoutMinX)
            readonly property real layoutHeight: Math.max(1, root.layoutMaxY - root.layoutMinY)
            readonly property real baseScale: Math.min(
              Math.max(0.01, (width - Style.space(56)) / layoutWidth),
              Math.max(0.01, (height - Style.space(64)) / layoutHeight))
            readonly property real layoutScale: baseScale * root.arrangementZoom
            readonly property real originX: (width - layoutWidth * layoutScale) / 2 - root.layoutMinX * layoutScale
            readonly property real originY: (height - layoutHeight * layoutScale) / 2 - root.layoutMinY * layoutScale

            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1; height: parent.height; color: root.alpha(root.foreground, 0.06) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.alpha(root.foreground, 0.06) }
            Text {
              visible: root.stateLoaded && root.displays.length === 0
              anchors.centerIn: parent
              text: "No active displays found"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Repeater {
              model: root.displays
              Item {
                id: displayTile
                required property var modelData
                required property int index
                readonly property bool selected: root.selectedId === modelData.name
                readonly property real bezel: Style.space(5)
                x: canvas.originX + modelData.x * canvas.layoutScale
                y: canvas.originY + modelData.y * canvas.layoutScale
                width: root.logicalWidth(modelData) * canvas.layoutScale
                height: root.logicalHeight(modelData) * canvas.layoutScale + Style.space(28)
                z: pointer.drag.active ? 20 : (selected ? 10 : index)
                Behavior on x { enabled: !pointer.drag.active; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !pointer.drag.active; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                BorderSurface {
                  id: monitorFace
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: parent.height - Style.space(28)
                  radius: Math.max(2, Style.cornerRadius * 0.65)
                  color: displayTile.selected ? Style.selectedFillFor(root.foreground, Color.accent) : root.alpha(root.foreground, 0.08)
                  borderSpec: Border.flat(displayTile.selected ? Color.accent : root.alpha(root.foreground, 0.34), displayTile.selected ? 2 : 1)
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
                      text: root.displayLabel(modelData)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }
                }
                Text {
                  anchors.top: monitorFace.bottom
                  anchors.topMargin: Style.space(7)
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.width
                  text: modelData.name + "  ·  " + root.displayResolution(modelData)
                  color: displayTile.selected ? root.foreground : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                }
                MouseArea {
                  id: pointer
                  anchors.fill: parent
                  enabled: !actionProc.running && !root.brightnessBusy
                  hoverEnabled: true
                  cursorShape: drag.active ? Qt.ClosedHandCursor : (root.displays.length > 1 ? Qt.OpenHandCursor : Qt.PointingHandCursor)
                  drag.target: root.displays.length > 1 ? displayTile : undefined
                  drag.minimumX: 0
                  drag.minimumY: 0
                  drag.maximumX: Math.max(0, canvas.width - displayTile.width)
                  drag.maximumY: Math.max(0, canvas.height - displayTile.height)
                  onPressed: { root.selectedId = modelData.name; root.draggingDisplay = root.displays.length > 1 }
                  onReleased: {
                    if (root.draggingDisplay) root.applyArrangement(modelData.name, displayTile.x, displayTile.y)
                    root.draggingDisplay = false
                  }
                  onCanceled: root.draggingDisplay = false
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
            text: root.displayLabel(root.selectedDisplay)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            id: selectedMeta
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedDisplay ? root.selectedDisplay.name + "  ·  " + root.displayResolution(root.selectedDisplay) : ""
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
                implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessValueLabel.implicitHeight)
                PanelSectionHeader { id: brightnessHeader; anchors.left: parent.left; text: "BRIGHTNESS"; foreground: root.foreground; fontFamily: root.fontFamily }
                Text {
                  id: brightnessValueLabel
                  anchors.right: parent.right
                  text: root.brightnessLoading ? "Detecting…" : (root.brightnessAvailable ? root.brightnessValue + "%" : "Unavailable")
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
              Row {
                width: parent.width
                spacing: Style.space(10)
                opacity: root.brightnessAvailable ? 1 : 0.38
                Text { anchors.verticalCenter: parent.verticalCenter; text: "☼"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.title }
                DisplaySlider {
                  id: brightnessSlider
                  width: parent.width - Style.space(54)
                  enabled: root.brightnessAvailable && !actionProc.running
                    && !root.brightnessCommitPending && !root.brightnessRollbackPending
                    && !brightnessRollbackProc.running
                  bar: root.bar
                  minimum: 1; maximum: 100; step: 1; integer: true
                  value: root.brightnessValue
                  onPressed: function(value) { root.beginBrightnessEdit() }
                  onMoved: function(value) { root.previewBrightness(value) }
                  onReleased: function(value) { root.commitBrightness(value) }
                  onCanceled: root.abortBrightnessEdit("")
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "☀"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title }
              }

              PanelSeparator { foreground: root.foreground }
              PanelSectionHeader { text: "SCALE"; foreground: root.foreground; fontFamily: root.fontFamily }
              Row {
                width: parent.width
                spacing: Style.spacing.xs
                Repeater {
                  model: root.scaleOptions
                  Button {
                    required property real modelData
                    width: (settingsColumn.width - Style.spacing.xs * (root.scaleOptions.length - 1)) / root.scaleOptions.length
                    text: Math.round(modelData * 100) + "%"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    bordered: true
                    active: root.selectedDisplay && Math.abs(root.selectedDisplay.scale - modelData) < 0.01
                    enabled: !!root.selectedDisplay && !root.applying
                    onClicked: {
                      var scale = modelData
                      var snapshot = root.snapshotUi()
                      root.updateDisplay(root.selectedId, { scale: scale })
                      root.runAction(["scale", root.selectedId, String(scale)], "Display scale updated", false, snapshot)
                    }
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
                  PanelSectionHeader { text: "REFRESH RATE"; foreground: root.foreground; fontFamily: root.fontFamily }
                  Dropdown {
                    width: parent.width
                    enabled: !!root.selectedDisplay && !root.applying
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.currentModeFor(root.selectedDisplay)
                    options: root.refreshOptionsFor(root.selectedDisplay)
                    onChanged: function(value) {
                      var mode = root.parseMode(value)
                      var snapshot = root.snapshotUi()
                      if (mode) root.updateDisplay(root.selectedId, {
                          width: mode.width,
                          height: mode.height,
                          refreshRate: mode.rate
                      })
                      root.runAction(["mode", root.selectedId, value], "Refresh rate updated", false, snapshot)
                    }
                  }
                }
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)
                  PanelSectionHeader { text: "RESOLUTION"; foreground: root.foreground; fontFamily: root.fontFamily }
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
                      text: root.displayResolution(root.selectedDisplay)
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
                  Text { width: parent.width; text: "Night Light"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle; font.bold: true }
                  Text { width: parent.width; text: "Warmer colors on every display"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                }
                ToggleSwitch {
                  id: nightSwitch
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  busy: root.applying
                  checked: root.nightLightEnabled
                  foreground: root.foreground
                  accent: Color.accent
                  onToggled: {
                    var next = !checked
                    var snapshot = root.snapshotUi()
                    root.nightLightEnabled = next
                    root.runAction(["nightlight", next ? "on" : "off"], next ? "Night Light enabled" : "Night Light disabled", false, snapshot)
                  }
                }
              }
              PanelSeparator { foreground: root.foreground }
              Item {
                width: parent.width
                implicitHeight: Math.max(scheduleLabel.implicitHeight, scheduleSwitch.implicitHeight)
                Text { id: scheduleLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Schedule"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                ToggleSwitch {
                  id: scheduleSwitch
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  busy: root.applying
                  checked: root.scheduleEnabled
                  foreground: root.foreground
                  accent: Color.accent
                  onToggled: {
                    var next = !checked
                    var snapshot = root.snapshotUi()
                    root.scheduleEnabled = next
                    root.scheduleDraftDirty = true
                    root.runAction(next ? ["schedule", "on", root.scheduleFrom, root.scheduleTo] : ["schedule", "off"], next ? "Night Light schedule enabled" : "Night Light schedule disabled", false, snapshot)
                  }
                }
              }
              Row {
                width: parent.width
                spacing: Style.space(10)
                opacity: root.scheduleEnabled ? 1 : 0.38
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)
                  PanelSectionHeader { text: "FROM"; foreground: root.foreground; fontFamily: root.fontFamily }
                  Dropdown {
                    width: parent.width
                    enabled: !root.applying
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.scheduleFrom
                    options: root.timeOptions
                    onChanged: function(value) {
                      var snapshot = root.snapshotUi()
                      root.scheduleFrom = value
                      root.scheduleDraftDirty = true
                      if (root.scheduleEnabled) root.runAction(["schedule", "on", root.scheduleFrom, root.scheduleTo], "Night Light schedule updated", false, snapshot)
                    }
                  }
                }
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(5)
                  PanelSectionHeader { text: "TO"; foreground: root.foreground; fontFamily: root.fontFamily }
                  Dropdown {
                    width: parent.width
                    enabled: !root.applying
                    showLabel: false
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    value: root.scheduleTo
                    options: root.timeOptions
                    onChanged: function(value) {
                      var snapshot = root.snapshotUi()
                      root.scheduleTo = value
                      root.scheduleDraftDirty = true
                      if (root.scheduleEnabled) root.runAction(["schedule", "on", root.scheduleFrom, root.scheduleTo], "Night Light schedule updated", false, snapshot)
                    }
                  }
                }
              }
              Item { width: 1; height: Style.space(2) }
              Text {
                width: parent.width
                text: root.scheduleEnabled ? "Scheduled " + root.scheduleFrom + "–" + root.scheduleTo : (root.nightLightEnabled ? "Enabled until switched off" : "Currently disabled")
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
          color: root.statusMessage !== "" ? root.alpha(root.statusIsError ? Color.urgent : Color.accent, 0.12) : root.alpha(Color.accent, 0.08)
          borderSpec: Border.flat(root.alpha(root.statusMessage !== "" && root.statusIsError ? Color.urgent : Color.accent, 0.34), 1)
          Text {
            id: footerText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(12)
            text: root.statusMessage !== "" ? root.statusMessage : "Arrangement, scale, refresh rate, and schedules are saved for the next login."
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
