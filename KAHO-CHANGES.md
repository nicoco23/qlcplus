# KAHO fork of QLC+

This repository is a fork of [Q Light Controller Plus](https://github.com/mcallegari/qlcplus)
by Massimo Callegari and contributors, distributed under the Apache License 2.0
(see `COPYING`). As required by section 4 of the license, this file lists what
the fork changes. All original copyright notices are kept.

## Changes (QLC+ 5 / `qmlui` interface)

- **Playbacks window** (`qmlui/playbackmanager.*`, `qmlui/qml/Playbacks.qml`,
  `qmlui/qml/PlaybackFader.qml`): console style surface with 8 pages of
  8 playback faders (GO, back, FLASH, release), a 8 × 7 grid of execute buttons
  and a Grand Master. Any function can be assigned from the side list.
  Pages are saved in the workspace file (`<Playbacks>` element, ignored by
  upstream QLC+).
- **Akai APC mini (1st generation) support** in the Playbacks window: the
  controller is detected and patched automatically (input and LED feedback).
  Faders 1-8 = playbacks, fader 9 = Grand Master, bottom pad row = FLASH,
  other pads = execute buttons, buttons under the grid = GO (SHIFT + GO =
  release), right column = pages (SHIFT + last = release all). Soft takeover
  after a page change.
- **KAHO look**: KAHO charter colors in `qmlui/qml/UISettings.qml` (dark
  surfaces, soft mauve accent), rounded display face *Nunito* (SIL OFL 1.1,
  `resources/fonts/NunitoRounded.ttf`, renamed instance of Nunito ExtraBold,
  license in `resources/fonts/OFL-Nunito.txt`), window title "KAHO Console",
  About box mentions the fork and keeps the QLC+ credits.
- **Playbacks, second pass**: custom name and color per playback / execute
  button, named pages, execute buttons in toggle or momentary FLASH mode,
  drag & drop from a searchable, type-filtered function list (double-click =
  first free slot), slot options on right click (rename, color, move, remove),
  keyboard shortcuts (1-8 GO, Ctrl+1-8 release, Alt+1-8 flash, Page Up/Down),
  running slots filled with their color. Saved as `Name`, `Label`, `Color`
  and `Mode` attributes of the `<Playbacks>` element.
- **CLEAR key** in the status bar: shows how many channels the Simple Desk is
  holding over the cue stack and releases them all (`SimpleDesk::resetAll()`,
  `overrideCount` property added to `qmlui/simpledesk.*`). Grand Master
  warning (level / flashing BLACKOUT) next to it. Simple Desk held channels
  use a soft tint and a red marker instead of a solid red strip
  (`qmlui/qml/SimpleDesk.qml`).
- **Programmer window** (`qmlui/programmermanager.*`, `qmlui/qml/Programmer.qml`, F2):
  MagicQ style programmer. Fixture group keys (SHIFT to add), odd/even
  selection, intensity, strobe, colour swatches and hue bar, pan/tilt pad
  with position presets and fan spread, zoom, ready made effects (relative
  EFX for movement, RGB matrices for colour and intensity) with tempo and
  size, and RECORD: the programmer becomes a Scene (plus a Collection with
  the effects) placed on the first free playback or armed to be placed by
  hand. Uses the existing ContextManager dump values as the programmer;
  `ContextManager::dumpValues()` and `ContextManager::unsetDumpChannels()`
  were added for it. The Virtual Console key moves to F7.
- **KahoStage scene import** (`qmlui/kahostageimport.*`, Actions menu > File):
  reads the `KahoStage-scene.json` written by the KahoStage Minecraft plugin
  and places the fixtures (matched by name) and the trusses in the 2D / 3D
  views of the current project, without touching the programming.
- **Console layout**: slim status bar on top (KAHO wordmark opening the
  Actions menu, current window, clock, BPM), big window keys at the bottom
  (`qmlui/qml/ConsoleWindowKey.qml`) with F1-F6 shortcuts, instead of the
  top toolbar tabs.
- Files touched to wire the above: `qmlui/app.*`, `qmlui/contextmanager.cpp`,
  `qmlui/qml/MainView.qml`, `qmlui/qml/MenuBarEntry.qml`, `qmlui/qml/popup/PopupAbout.qml`,
  `qmlui/qmlui.qrc`, `resources/fonts/fonts.qrc`,
  `qmlui/CMakeLists.txt`.
- CI: `.github/workflows/kaho-windows.yml` builds the Windows installer on every
  push; the upstream matrix (`build.yml`) only runs on pull requests or on demand.
