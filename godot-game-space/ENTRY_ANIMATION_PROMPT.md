# Entry animation: Gemini (Veo) prompt - red aggressive gaming theme

Length: **8 seconds** (Veo's maximum; well inside your 30 s limit). Aspect ratio **16:9**, 1080p if offered, no audio needed.

## Prompt (paste as is)

```
Cinematic game-booster boot sequence, 8 seconds, 16:9, ultra detailed, aggressive esports gaming theme, strictly red and black color palette with orange-amber accents, no other hues.
Shot 1 (0-2s): pitch-black screen, a thin crimson laser line sweeps top to bottom, revealing a dark carbon-fiber mecha cockpit; heavy black armor plates with glowing red edges are closed in the center of the frame.
Shot 2 (2-4.5s): the armor plates slam open horizontally with sparks, red energy lights run along the borders like LED strips; a glowing red hexagonal energy core ignites in the center, circular turbine cooling rings spin up faster and faster around it, holographic red CPU and GPU dials surge from low to maximum.
Shot 3 (4.5-6.5s): the core overloads - a red and orange shockwave blasts outward with lightning arcs, embers and sparks flying toward the camera, rapid push-in, motion blur, red speed lines, heat haze.
Shot 4 (6.5-8s): the energy settles into a sharp glowing red lightning-bolt-in-hexagon emblem on a dark carbon background, pulsing once, then a quick bright red flash to black.
Style: dark cyberpunk mecha HUD, volumetric red light, deep blacks, high contrast, smooth 60fps feel, dramatic camera, no humans, no characters, no text, no letters, no numbers, no logos, no watermark.
```

## Negative prompt (if Gemini asks)
`text, letters, numbers, logos, watermark, people, faces, blue, cyan, green, purple, pastel colors, low contrast, blurry, cartoon`

## After you generate it
1. Download the MP4 and convert it for Godot (it only plays Ogg Theora natively):
   `ffmpeg -i entry.mp4 -vf scale=1280:-2 -c:v libtheora -q:v 7 -an booster_entry.ogv`
2. Put the file at `godot-game-space/assets/entry/booster_entry.ogv` and rebuild the APK
   (`godot --headless --path . --export-debug "Android" build/GameBooster-debug.apk`), or just send it to me and I will rebuild.
3. The intro then plays your clip behind the live HUD (dials, RAM sweep, "LAUNCHING: game name"). Without the file the built-in procedural red intro plays.
