# Klok

A macOS menu-bar clock inspired by the classic Windows freeware **ClocX**. Displays an analog clock on the desktop using ClocX-compatible skin files, with a full-featured menu bar icon, calendar popover, and alarm system.

![Klok screenshot](app.png)

## Features

- Analog clock window using ClocX `.ini` + image skin format
- Supports both BMP (cut-color masking) and PNG (real alpha) skins
- PNG hand sprites (`HourPNG`, `MinutePNG`, `SecondPNG`)
- Menu bar icon with live time, configurable date format and icon styles
- Calendar popover with system calendar event integration
- Alarm / reminder system with notifications
- Light & dark mode, multiple language support (EN / 简中 / 繁中 / 日本語)
- Requires macOS 13+

## ClocX Skin Compatibility

Klok reads the same `.ini` + image format used by the original Windows ClocX.  
Drop any ClocX skin folder into `~/Library/Application Support/Klok/Skins/` and it will appear in Preferences.

Community skins can be found at sites that host ClocX resources. Note that individual skins are copyrighted by their respective authors.

## Building

Requires Xcode Command Line Tools and Swift 5.9+.

```bash
# Debug run
swift run

# Build release .app bundle
./build_app.sh

# Build distributable .dmg
./build_dmg.sh
```

The `.app` is placed in `dist/Klok.app`.

## Project Structure

```
Sources/Klok/
  AppDelegate.swift          — app lifecycle, menu bar icon, status menu
  ClockWindowController.swift — borderless clock window, drag, right-click menu
  ClockView.swift            — analog clock rendering (hands, overlays)
  ClocXSkin.swift            — skin loader: INI parser, BGR color, hand sprites
  ImageSkinLoader.swift      — pure-image skin support (PNG without INI)
  CalendarPopover.swift      — calendar panel + event list
  PreferencesWindowController.swift — skin picker, general, alarms tabs
  AlarmManager.swift         — scheduling, UserNotifications
  Settings.swift             — UserDefaults-backed settings store
  L10n.swift                 — localization strings
Skins/                       — sample skin files (see licensing note below)
```

## Skin Licensing

The `Skins/` directory contains only `default.ini`, which is part of this project and released under the MIT License. Other skins you add are subject to their own authors' terms. Do not redistribute third-party skins without permission.

## License

MIT — see [LICENSE](LICENSE).

This project is not affiliated with or endorsed by the original ClocX author or any watch brand whose name appears in community skin filenames.
