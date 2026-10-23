# Plasma Syncthing Widget

A small KDE Plasma 6 widget that shows Syncthing status.

- Panel icon with a status dot: green (up to date), blue (syncing), red (error), grey (not reachable)
- Folder list with state, size and sync progress. Click a folder to open it.
- Device list with connection state
- Buttons to pause/resume all devices, rescan all folders and open the web UI
- Colored or monochrome (theme, light, dark) panel icon

The API key is read from `~/.local/state/syncthing/config.xml` or `~/.config/syncthing/config.xml`.
You can also set the key and web UI address in the widget settings.

## Requirements

- Plasma 6
- curl

## Install

    kpackagetool6 -t Plasma/Applet -i package

Then add "Syncthing" from *Add Widgets*.

## Update

    kpackagetool6 -t Plasma/Applet -u package
    systemctl --user restart plasma-plasmashell

## Test

    plasmawindowed org.amritanshu.syncthing

## License

Copyright (c) 2026 Amritanshu Pandey

GPL-2.0-or-later. See [LICENSE](LICENSE).

The Syncthing logo belongs to the Syncthing project.
