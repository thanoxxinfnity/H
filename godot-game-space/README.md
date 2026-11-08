# Game Space Booster (Godot 4.3, GL Compatibility, Android landscape)

Vivo "Game Space / Ultra Game Mode" style system: cinematic booster intro, edge-swipe glass drawer,
CAS super-resolution, live telemetry, AI-generated entry animation through a REST API.

## 1. Setup
```bash
# desktop test
godot --path godot-game-space            # or open the folder in Godot 4.3 and press F5

# Android: install the Android export template + JDK 17 + Android SDK (Editor > Editor Settings > Export > Android)
cp export_presets.cfg.example export_presets.cfg   # or create it via Project > Export
godot --headless --path godot-game-space --export-debug "Android" build/GameSpace.apk
adb install -r build/GameSpace.apk
```
Project settings already set in `project.godot`: GL Compatibility (also for mobile), sensor-landscape,
`canvas_items` + `expand` stretch (18:9, 20:9, 21:9 all fill the screen), fractional scaling, MSAA off,
ETC2/ASTC textures, `emulate_touch_from_mouse` (test touch gestures with the mouse on desktop), 60 FPS cap.

```
godot-game-space/
  project.godot
  autoload/   settings.gd (saved prefs + API key, user://)   telemetry.gd (FPS/ms/temp/CPU/RAM)
              performance_booster.gd (fps modes, memory clean, Android-plugin bridge)
  shaders/    cas.gdshader (CAS sharpen)   glass.gdshader (blur + tint + rounded rim)
  scripts/    main.gd  demo_game.gd
    systems/  upscaler_manager.gd  ai_video_generator.gd  screen_recorder.gd
    ui/       game_space_sidebar.gd  booster_entry_animation.gd  telemetry_hud.gd
              safe_area_container.gd  icons.gd (SVG vector "drawables", rasterised at runtime)
  scenes/main.tscn
```

## 2. Scene tree (`scenes/main.tscn`)
```
Main (Node)                       main.gd
├─ Upscaler (Control, full rect)  UpscalerManager  -> SubViewport (game) + TextureRect (CAS material)
├─ Generator (Node)               AIVideoGenerator
├─ Recorder (Node)                ScreenRecorder
└─ UiLayer (CanvasLayer, 10)
   ├─ SafeArea (MarginContainer)  SafeAreaContainer  (notch / cutout margins)
   │   └─ HudRoot (Control)
   │       ├─ TelemetryHud (PanelContainer, top-center)
   │       └─ Toast (Label)       demo notification, hidden by Do Not Disturb
   ├─ Sidebar (Control, full rect) GameSpaceSidebar
   │   ├─ _dim (ColorRect)  _pill_l/_pill_r (edge hints)
   │   ├─ _drawer (Control) -> _glass (ColorRect, glass.gdshader) -> Margin -> Scroll -> VBox (sections)
   │   └─ CanvasLayer 90 -> brightness-lock dimmer
   └─ BoosterEntry (Control, full rect)  BoosterEntryAnimation (AnimationPlayer + CPUParticles2D, built in code)
```

## 3. How the pieces connect
* `main.gd` calls `sidebar.setup(upscaler, generator, recorder)`; the drawer buttons call `UpscalerManager.set_mode()`
  (Off 100 % / Balanced 77 % / Ultra Performance 59 % render scale, CAS sharpness 0 / .55 / .85),
  `PerformanceBooster.apply_mode()` (30 / 60 / up to 120 FPS cap, keep-screen-on, plugin hook) and `ScreenRecorder`.
* Put your real game under the upscaler: `upscaler.add_game_node(my_game_scene.instantiate())`.
  Input the UI does not use is forwarded into the SubViewport automatically (positions rescaled).
* Anything in group `cleanable` that has `clean_up()` is called by **Clean RAM**.
* Edge swipe: touch starts within 40 px of the left/right border in the **upper half** of the screen and moves
  70 px inward -> drawer opens from that side; swipe back outward, tap the dimmed game, or Android Back closes it.
  The SceneTree is never paused.
* Intro: `BoosterEntryAnimation.play(path)`; with a cached AI clip it plays behind the HUD, otherwise (API offline,
  unsupported format, no key) the procedural version runs. Tap after 0.8 s to skip.

## 4. AI video / animation API (`AIVideoGenerator.gd`)
Providers: `revana` (tested), `replicate`, `luma` (written from their public docs, **not tested live**).
`Authorization: Bearer <key>`; create task -> poll every 4 s (20 min max) -> stream the file to
`user://cache/animations/<provider>_<model>_<prompthash>.<ext>` (same prompt = cache hit, no cost).
Set the key in the drawer; it is saved only in `user://settings.cfg` on the device.

**Playback limits (important):** Godot 4.3 decodes only Ogg Theora (`.ogv`) natively. MP4/WebM results need the
EIRTeam.FFmpeg GDExtension (class `FFmpegVideoStream`, auto-detected) or a spritesheet (png/webp, 4x4 by default).
Without that the drawer says so and the procedural intro is used. Easiest path: generate with a provider that can
return a spritesheet, or convert to `.ogv` (`ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -an out.ogv`) and drop it in the cache folder.

## 4b. GT-style aggressive gaming features
* **GT Mode:** Eco 30 / Balanced 60 / Performance (up to 90) / X-Boost (display max, up to 144 FPS cap) + auto thermal guard
  (drops to Balanced at 43 C) + Clean RAM.
* **Cyber Light:** animated RGB border strip (Cyan / Magenta / Rainbow / Red alert / Cyber duo); turns red when the phone is hot.
* **Air Triggers:** two on-screen shoulder pads (upper corners); each injects a touch at the spot you map with *Map L / Map R*; hold and multi-touch work.
* **Cooling & charging:** thermal guard, bypass-charging toggle (needs the Android plugin, hardware specific).
* **HUD:** FPS, frame time, ping (HTTP 204 probe), battery temp, session and total play time.
* **Intro:** armor plates slide open, cooling turbines spin up with the CPU dial, RGB border lights up, ignition burst.
These are modelled on the publicly known feature set of gaming phones in the GT class. They are not a copy of any vendor's
firmware (proprietary) and I do not know the unreleased GT 50 Pro's feature list, so "same to same" is not possible; tell me
specific features and I will add them.

## 5. What is real and what needs an Android plugin
Works in-engine: FPS/frame-time, FPS cap modes, intro, drawer, CAS upscaler, software brightness lock, screenshot,
JPG-sequence screen capture (15 fps, 20 s cap), in-app notification suppression, API client.
Needs the optional Android plugin singleton `GameSpaceAndroid` (methods `setSustainedPerformance(bool)`,
`trimMemory()`, `setDnd(bool)`, `setBrightness(float)`, `startScreenRecord()`, `stopScreenRecord()`); without it those calls
are skipped silently. Battery temperature and CPU frequency come from `/sys` and are only readable on some devices (shown as `--` otherwise).
Not verified: this was written without a Godot editor/device available, only syntax-checked with gdparse. Run it and report any error text.

Generated videos are AI-generated; label them as such.
