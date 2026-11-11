# QingLu · 轻录

Native macOS screen recording for tutorials: screen, system audio, microphone narration and camera picture-in-picture. Local processing, no account, no watermark.

[Download](https://github.com/Jin-Hsu/recordmac/releases) · [中文](README.md) · [Report an issue](https://github.com/Jin-Hsu/recordmac/issues)

## Install

Download `QingLu-1.2.1-arm64.dmg` from Releases and drag the app to Applications. Requires **Apple Silicon and macOS 15+**. Allow screen/system audio, microphone and camera access when needed, then restart the app. Record a short test before an important session.

This is an **ad-hoc signed, unnotarized public beta**. macOS may block first launch. Use Privacy & Security → Open Anyway only after verifying the source; do not disable system-wide security protections.

## Features

- Full-screen / selected-region recording with recording indicators.
- System audio, microphone and optional camera picture-in-picture.
- Camera position and size configured before recording.
- Quality presets, 30/60 fps capture, countdown, timed stop and destination folder.

## Limitations

Camera composition exports at 30 fps. The layout thumbnail and final aspect ratio need refinement. Synchronization uses estimated startup offsets; long sessions and multiple devices have not been validated. No live camera repositioning, pause/resume, device picker, automatic updates or recovery UI. Temporary media may remain after failures. Build/package verification is not full end-to-end recording certification.

## Build

Use Swift 6 and a macOS 15+ SDK: `bash scripts/build.sh`. Outputs are written to `dist/`. See [contributing](CONTRIBUTING.md) and [privacy](PRIVACY.md).

## License

Copyright © 2026 Jin-Hsu and contributors. [CC BY-NC 4.0](LICENSE): attribution required; noncommercial sharing and adaptations permitted under the license. Commercial uses require separate permission. This is a source-available project, not OSI-approved open source. Presentation is inspired by Mos; no Mos code or branding is included.
