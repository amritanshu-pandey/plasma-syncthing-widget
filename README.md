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

## Logo

The colored icon is the `syncthing` icon from your system icon theme.
The monochrome icon (`package/contents/icons/syncthing-symbolic.svg`) is made from the official Syncthing logo.

The Syncthing name and logo belong to the Syncthing project. They are not covered by this project's license.
This project is not part of, or endorsed by, the Syncthing project.
