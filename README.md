# youpple

**youpple** is an experimental Liquid Glass customization layer for the YouTube iOS app.

The project is designed as an injectable tweak/patcher: provide a decrypted YouTube IPA, build the tweak, inject it into the IPA, then sign/install the resulting IPA using your preferred sideloading workflow.

## Current development target

The first prototype intentionally stays conservative:

- native Liquid Glass when `UIGlassEffect` is available;
- material-blur fallback on older iOS versions;
- runtime discovery of likely YouTube bottom navigation, mini-player and search surfaces;
- non-destructive glass backdrops rather than replacing YouTube controllers;
- diagnostics that log matched YouTube view classes so later versions can replace heuristics with exact hooks;
- a reusable IPA patching pipeline.

The eventual roadmap includes an Apple-like glass navigation system, integrated mini-player, player controls, menus, dynamic thumbnail tinting, and synced lyrics/karaoke sourced from YouTube captions where timing data permits.

## Build

Requirements:

- decrypted YouTube IPA;
- Theos;
- GNU make (`gmake`);
- `ldid`;
- `dpkg-deb`;
- `cyan` / `pyzule-rw`.

```bash
make build IPA=/path/to/YouTube.ipa
```

The patched unsigned IPA is written to `out/`.

## GitHub Actions

The included manual workflow accepts a direct URL to a decrypted IPA, builds the tweak, injects it, and uploads the resulting unsigned IPA as a workflow artifact.

Do not commit decrypted YouTube IPAs to this repository.

## Licensing / provenance

This project is GPL-3.0. Its build/tweak architecture is informed by the GPL-3.0 release `spoti.pw v0.21.1`; YouTube-specific integration is being implemented separately for this project. See `NOTICE.md` and `docs/ARCHITECTURE.md`.

YouTube and Google are trademarks of their respective owners. This project is not affiliated with Google, YouTube, Apple, or Spotify.
