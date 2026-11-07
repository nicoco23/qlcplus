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
