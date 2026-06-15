# AGENTS.md

## Project overview

Godot 4.6 (Forward Plus renderer) game project in GDScript. A 2.5D isometric farm sim ("QQ Farm").

## Key architecture

- **Entry scene**: `Login.tscn` → validates token against Go backend → transitions to `Farm.tscn`
- **Farm game** (`farm.gd`, ~2300 lines): All gameplay + rendering in a single script. UI is 100% custom-drawn via `_draw()` — no Control nodes for game UI. Isometric grid: 6 cols × 5 rows, tile size 168×84.
- **Login** (`login.gd`): Uses `ApiConfig.API_BASE` autoload for backend URL. Expects backend with `/auth/login`, `/auth/register`, `/profile` endpoints.
- **Crop atlas** (`scripts/crop_atlas.gd`): Static class managing per-crop stage textures (4 growth stages each). Texture cache via `load()`.
- **Plot anchors**: `Farm.tscn` has a `PlotAnchors` node with 30 child nodes (`Plot_0_0` through `Plot_4_5`) defining isometric tile positions. Each uses `scripts/plot_anchor_tile.gd` (`@tool` script for editor preview).

## Running and testing

- Open in Godot Editor 4.6+ and press F5. No CLI build/test/lint toolchain exists in this repo.
- Main scene is `Login.tscn`. To skip login during dev, change `run/main_scene` in `project.godot` to `res://Farm.tscn`.
- Save file: `user://qq_farm_save.json` (platform-dependent user data dir).
- Auth token: `user://auth.json`.

## Conventions

- All game strings are in Chinese (UI labels, crop names, toast messages).
- Crop data is defined inline as arrays in `farm.gd:_ready()` — CROPS[i] = [name, seed_cost, sell_price, grow_time_seconds, texture_key].
- Tool modes are integer indices (0–9) mapped to behavior via match statements in `_do_tile_action()`.
- The `@tool` annotation is used on `plot_anchor_tile.gd` for editor-time visualization.
- Window: 1448×1086, canvas_items stretch, keep aspect. Min window: 960×720.
- Physics engine is Jolt (3D), irrelevant to these 2D games.

## Addons

- `godot_mcp` (v1.0.6): MCP server for AI assistants (scene editing, script management, debugging). Auto-starts on load. Referenced in `project.godot` autoload as `MCPRuntimeProbe`.

## Gotchas

- `farm.gd` is monolithic — rendering, input, game logic, save/load all in one file. Read carefully before editing; the `_draw()` function spans 800+ lines with layered render passes.
- The `CROPS` array indices are used as keys in `inventory` dict and `cell["crop_id"]`. Changing crop order breaks save compatibility.
- `PlotAnchors` node positions are hardcoded in the .tscn. Moving them changes the isometric layout.
- Login scene builds its UI in code (`_build_ui()`), not in the .tscn file.
- No `.gdignore` on `assets/` — Godot imports all PNGs. The `.godot/imported/` dir is gitignored.
