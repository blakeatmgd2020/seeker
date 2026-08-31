# Hidden Hollow

A third-person open-world hide-and-seek game (Godot 4.7.1). Somewhere in the
valley, one of 20 searchable structures hides a wooden tag with a number on
it — find it.

Every calendar day generates a new world from that date's seed: terrain,
village layout, structure placement, your spawn point, the weather mood, and
the tag's number. The same day always rebuilds the same world (quit and
resume the same hunt), and the Esc menu lets you travel to any of the last
7 daily worlds, re-hide the tag for another round, restart the day, or quit —
each behind a confirmation dialog.

## Play

Double-click `play_hidden_hollow.bat`, or:

```
Godot_v4.7.1-stable_win64.exe --path <this folder>
```

WoW-style mouse: the cursor is free and independent of the camera.

- **Left-drag** orbits the camera (character keeps facing); **right-drag**
  steers the character; **both buttons** held = run forward; **wheel** zooms
- **Left-click** a structure to target it (gold ring + target frame);
  **right-click** targets and searches it if you're within ~4 m
- **WASD** move relative to facing (S backpedals slower), **Shift** sprint,
  **Space** jump, **E** search your current target
- **Esc** clears your target; pressed again it opens the menu
  (re-hide the tag, restart the day, day travel, quit)

## Tools

Three tools are hidden in three structures each day (never the tag's):

- **Map** — a minimap appears top-right: terrain, water, the village plaza,
  and a dot for every structure you've *discovered* (walked within ~20 m of,
  or spotted through the spyglass). Searched structures show gray. With the
  map alone the view is **view-up**: the map rotates with your camera around
  your position and the centered arrow always points up.
- **Compass** — a heading strip appears top-center showing the direction the
  camera faces. With map *and* compass the minimap locks **north-up** and
  your arrow rotates to show your facing instead.
- **Spyglass** — hold **Z** to zoom ~4×; unsearched structures with a clear
  line of sight get floating name-and-distance labels out to ~300 m, and
  anything you spot is added to the map.

Tools persist through re-hide rounds but reset with a new day (or day
restart/travel) — finding them is part of each day's puzzle.

## Development

All geometry and textures are generated procedurally at startup — no imported
assets. The single scene (`scenes/main.tscn`) is just a root node running
`scripts/main.gd`; everything else is built in code:

| File | Responsibility |
| --- | --- |
| `scripts/main.gd` | Orchestrator: daily seeds, world build/teardown, moods, tag & tool assignment, rounds |
| `scripts/terrain.gd` | Heightfield mesh + collision, splat shader, village flattening, water level, minimap texture |
| `scripts/village.gd` | Randomized village: houses, barn, well, loose structures |
| `scripts/structures.gd` | Factory for the 7 searchable structure types |
| `scripts/interactable.gd` | Search behavior: open animations, tag reveal, tool props, selection ring |
| `scripts/vegetation.gd` | MultiMesh pines/oaks/bushes/rocks/boulders with placement rules |
| `scripts/player.gd` | WoW-style controls, camera rig, targeting, spyglass, discovery |
| `scripts/hud.gd` | Target frame, minimap (view-up / north-up), compass strip, spyglass labels, toasts |
| `scripts/menu.gd` | Esc pause menu with confirmations and 7-day travel |
| `scripts/texf.gd` | Procedural NoiseTexture2D material factory |
| `scripts/util.gd` | Mesh/collision building helpers |

Worlds are seeded from the local calendar date (`_day_seed`), so a given day
is fully reproducible: same terrain, layout, spawn, weather, tag, and tool
locations.

### Headless smoke test

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . -s tests/smoke.gd
```

Verifies world generation, per-day determinism, the 20-structure budget,
tag reveal, tool placement/collection/persistence, targeting, and the
menu-driven re-hide. Exits 0 on pass.

### Screenshot mode

```
Godot_..._console.exe --path . -- --shot
```

Runs the game for a few seconds and saves interface screenshots (player
view, spyglass view, aerial, menu) to `HH_SHOT_DIR` (or `user://`), then
quits. Used for visual verification during development.
