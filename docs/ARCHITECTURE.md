# Architecture

## Principle

The IPA is disposable; the tweak is the product.

`youpple` should be able to take a compatible decrypted YouTube IPA, build one injectable dylib/deb, apply the small plist compatibility patch, and produce an unsigned patched IPA.

## Layers

### 1. Patcher

`scripts/pipeline.sh`:

1. validates the IPA;
2. reads the YouTube app version and bundle identifier;
3. builds the Theos tweak;
4. injects it with `cyan`;
5. applies the Liquid Glass compatibility plist;
6. writes a new unsigned IPA.

### 2. Runtime compatibility layer

The first prototype deliberately uses runtime discovery instead of hard-coding unverified YouTube private classes. It scans visible view trees after screen transitions and records classes whose names/geometry resemble:

- bottom/pivot navigation;
- mini-player surfaces;
- search surfaces.

This gives a safe first IPA for device testing and produces the class information needed for exact hooks later.

### 3. Glass renderer

`YPGlass` uses `NSClassFromString(@"UIGlassEffect")` so the tweak can compile without requiring an iOS 26 SDK. On systems where `UIGlassEffect` is unavailable, it falls back to a system material blur.

### 4. Exact YouTube hooks (next stage)

After the first instrumented build runs on a real YouTube IPA, replace each heuristic with exact version-aware hooks. Keep a fallback heuristic for unknown future YouTube versions so a minor update does not crash the app.

Planned compatibility model:

```text
exact known class / selector
        ↓ missing
compatible superclass/protocol
        ↓ missing
runtime hierarchy signature
        ↓ missing
stock YouTube UI (feature disabled)
```

## Planned feature modules

- Glass bottom navigation
- Integrated glass mini-player
- Search/header controls
- Watch-page action controls and menus
- Full-screen player controls
- Dynamic thumbnail-derived tint
- Channel/playlist sheets
- Shorts UI
- Caption-backed synced lyrics
- Karaoke highlighting when word-level timing exists

## GPL boundary

The development base is the GPL-3.0-compatible `spoti.pw v0.21.1` architecture. Code or implementations unique to later restricted releases must not be copied into this repository. Later behavior may be studied and independently reimplemented.
