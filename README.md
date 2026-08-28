# Display Settings

An Omarchy shell plugin for arranging displays and tuning per-monitor settings from the bar.

## Features

- Select and drag the displays reported by Hyprland to arrange the desktop.
- Change per-display scale and refresh rate using modes supported by the monitor.
- Control brightness through Omarchy's internal-backlight, DDC/CI, and Apple display support.
- Enable Night Light immediately or schedule it for a daily time range.
- Apply changes live and persist display settings across login and reboot.

Display configuration is saved in a marked `amin.display-settings` block in `~/.config/hypr/monitors.lua`. The original file is backed up to `~/.config/omarchy/monitors.lua.before-display-settings` before the first write.

Enabling the Night Light schedule backs up `~/.config/hypr/hyprsunset.conf`, installs the selected schedule, and enables the existing `hyprsunset` user service. Disabling the schedule restores that backup.

Brightness is shown as unavailable when the selected monitor does not expose a supported control method.

## Install

```bash
omarchy plugin add https://github.com/aminmarashi/display-settings.git --enable
```

Open **Display Settings** from the `▣` icon in the Omarchy bar.

## Test

```bash
./tests/display-settings-test.sh
omarchy plugin validate .
```

## Author

[Amin Marashi](https://amin.codes)

## License

MIT
