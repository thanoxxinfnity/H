# Game Space Demo (Godot 4.3)

* **Game Space sidebar** - Vivo-style panel: swipe in from the left edge (or tap the `›` handle). Do Not Disturb, FPS counter, performance modes (30/60/120 FPS cap), upscaler controls, screenshot, video generator.
* **CAS upscaler** - the game renders in a `SubViewport` at 50-100 % of the window size and is shown through an AMD FidelityFX-style Contrast Adaptive Sharpening shader (`shaders/cas.gdshader`). Add your own game as a child of `CasUpscaler` via `add_game_node()`.
* **AI video client** - `scripts/video_api_client.gd` talks to the Revana API (`https://api.revana.si/v1`): submit, poll, download. Default model `minimax-h3-free`. Enter your API key in the generator panel; it is stored only in `user://settings.cfg` on the device, never in the project.

Open the folder in Godot 4.3 and press F5. Godot cannot play MP4, so finished videos are saved in `user://videos/` and opened with the system player (double-click in the list). Generated videos are AI-generated; label them as such.

Notes: not yet run in the editor (see the chat message). Tweak `Settings` defaults in `autoload/settings.gd`.
