# Seeker

A third-person open-world hide-and-seek game (Godot 4.7.1). Twenty
searchable structures are scattered across the valley — crates, hollow
logs, dirt piles, wardrobes, nests atop great trees. Find and open them
all; your time is scored when the last one falls.

Every calendar day generates a new world from that date's seed: **one of four
biomes** (Green Meadow, Autumn Vale, Winter Highlands, Sunscar Badlands —
equal odds), terrain, village layout and architecture, structure placement,
your spawn point, the sky mood, the weather, and the tag's number. The same
day always rebuilds the same world (quit and resume the same hunt), and the
Esc menu lets you travel to any of the last 7 daily worlds, re-hide the tag
for another round, restart the day, or quit — each behind a confirmation
dialog.

Each biome has its own flora, village style (plaster/timber/alpine/adobe),
and structure pool with overlap — snow mounds and firewood stacks in winter,
clay urns and bone piles in the desert, leaf piles and scarecrows in autumn.
Weather is uncommon and biome-appropriate: rain (or snowfall) about 1 day in
4, fog or high winds (leaf gales, blizzards, dust storms) about 1 in 10.

Structures rest naturally on the land: the world is laid out before the
terrain mesh is built, so buildings sit on foundation cuts and rigid objects
on small carved terraces; mounds stay vertical and sink so their skirts meet
the slope; fallen logs lie along the slope contour.

## Play

The title screen offers two modes:

- **Daily Map** — the date-seeded world (same for the whole day; the Esc
  menu can travel to the last 7 days).
- **Random Map** — a fresh seed every time. Type a seed (numbers or words)
  to replay a specific map; the seed shows on the HUD, and the Esc menu
  gains "New random map".

Press **F8** anytime to leave a playtest note (Bug / Feel / Idea / Balance
plus free text). Notes and an end-of-session telemetry summary are written
to `feedback/session_*.md` (gitignored) for review between sessions.

Double-click `play_seeker.bat`, or:

```
Godot_v4.7.1-stable_win64.exe --path <this folder>
```

WoW-style mouse: the cursor is free and independent of the camera.

- **Left-drag** orbits the camera (character keeps facing); **right-drag**
  steers the character; **both buttons** held = run forward; **wheel** zooms
- **Left-click** a structure to target it (gold ring + target frame);
  **right-click** targets and searches it if you're within ~4 m
- **WASD** move relative to facing (S backpedals slower), **Space** jump,
  **E** search your current target
- **Shift** sprints while the stamina meter lasts (~5 s); it refills after
  a short breather — the bar above the prompt shows its state
- **Esc** clears your target; pressed again it opens the menu
  (restart, day travel, return to title, quit)

## Tools

Seven tools are hidden in seven distinct structures each world:

- **Map** — a minimap appears top-right (terrain, water, village plaza) and
  **M** opens the full map. With the map alone the minimap is **view-up**
  (rotates around your position, centered arrow up); nothing is marked on it
  yet — a bare map records nothing.
- **Compass** — a heading strip appears top-center. With map *and* compass
  the minimap locks **north-up** and your arrow rotates instead.
- **Spyglass** — hold **Z** for a proper scope: circular viewport,
  crosshairs, ~4× zoom. Unsearched structures with a clear line of sight
  get floating name-and-distance labels out to ~300 m.
- **Pencil** — the record-keeper. With pencil + map, your path is inked onto
  the map as you walk (permanent unless erased) and discovered structures
  finally appear as dots. In the M map view, left-drag draws freehand notes.
- **Notepad** — an alternate writing surface: with spyglass + pencil + (map
  or notepad), a structure is *logged* when you aim the scope's crosshairs
  right at it: it turns green on the map until searched, and a **Spotted**
  list appears bottom-right. **Tab** cycles the selection; with the compass,
  a green caret on the heading strip points at the selected node's bearing.
- **Eraser** — trail ink and drawings are permanent without it. With it,
  right-drag in the M map view erases strokes and trail alike.
- **Climbing irons** — two structures per world are nests atop great trees
  (stone spires in the desert). With the irons, hold **W** against the trunk
  to climb up to them; without, those heights stay out of reach.
- **Cup of coffee** — a one-use consumable hidden like the tools. Once found,
  a "Drink coffee" button appears bottom-left: two minutes of unlimited
  sprint, with a countdown while the caffeine lasts.

## Underground

Not every node is on the surface. Most worlds hide more: the barn may have a
**cellar** (a stairwell cut through the foundation, a lantern, and an extra
crate below), and the wilds may hold a **cave** — a boulder mound with a
stone arch, steps descending into a crystal-lit chamber with two more nodes.
The search counter counts everything, so "20 / 23" is your hint to look
below ground.

Tools persist through re-hide rounds but reset with a new day (or day
restart/travel) — finding them is part of each day's puzzle.

## Development

All geometry and textures are generated procedurally at startup — no imported
assets. The single scene (`scenes/main.tscn`) is just a root node running
`scripts/main.gd`; everything else is built in code:

| File | Responsibility |
| --- | --- |
| `scripts/main.gd` | Orchestrator: daily seeds, layout→carve→build order, moods, weather, tag & tool assignment, rounds |
| `scripts/biomes.gd` | Biome definitions: palettes, flora counts, structure pools, moods, weather tables |
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
