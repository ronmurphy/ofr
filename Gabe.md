# Diorama Renderer

## What it is

The Diorama is an optional 3D view of OFR's existing dungeon map. It shares the
same `GameState`, map cells, monsters, items, visibility, lighting and turn
logic as the classic renderer. It changes how the dungeon is drawn; it does not
create a second simulation or a separate map.

The camera looks down at the dungeon from an angle and turns in 90-degree steps.
Keyboard movement and controller directions are translated to match the
camera, so moving “up” continues to mean moving in the direction currently
shown as forward. The classic renderer remains available at any time.

## How the scene is drawn

Walls, natural rock, pillars, stalagmites, doors and chests use 3D meshes.
Ground cells use instanced floor meshes with surface styles for materials such
as flagstone, cave floor, rubble, water, mud, bones, fungus, stairs, traps and
pits. A dedicated shader adds material detail and carries per-cell tint. Solid
features receive a colored floor base, and door frames use masonry-colored
jambs and lintels that align with nearby walls. Open doors show the leaf swung
aside.

When the icon font has a picture for a creature, item or terrain feature, the
Diorama uses it as a camera-facing label. Terrain without a mapped picture
keeps its classic ASCII or extended glyph on the floor. This lets the view use
the art already shipped with the game while preserving its palette and
readability.

Lighting uses the current game state: the player's torch, lit braziers and
other luminous features contribute light, while visibility and explored-map
memory continue to control what is shown. The pause-menu text-size setting
scales Diorama labels and billboards as well.

## Controls

- `Q` switches between classic and Diorama views. The preference is saved.
- `[` and `]` turn the Diorama camera left or right in 90-degree steps.
- The controller's right stick turns the camera; d-pad up switches views by
  default.
- Left-click sets a walking destination. Travel uses the game's pathfinder and
  takes one deliberate step at a time when an enemy is watching.
- Right-click keeps the existing target/fire action.

## Source files

### Renderer and scene

- `src/render/diorama_view.gd` — the new renderer: it builds the 3D scene,
  chooses icon art or glyph fallbacks, handles camera rotation and mouse
  picking, and draws movement/target overlays.
- `src/render/shaders/diorama_surface.gdshader` — procedural surface detail,
  lighting response and per-instance terrain colors for the 3D meshes.
- `scenes/main.tscn` — adds the Diorama renderer alongside the classic grid.

### Shared view and input integration

- `src/render/main.gd` — selects the active renderer, shares game state and
  overlays, routes mouse actions, and translates directional input to the
  rotated camera.
- `src/render/render_theme.gd` — stores the renderer choice and keeps it
  separate from the classic letters/symbols/pictures theme.
- `src/render/glyph_grid.gd` — supplies a matching aim-state interface so both
  renderers can be controlled through the same game view code.
- `src/sim/pad_config.gd` and `src/ui/sidebar.gd` — bind and display the
  classic/3D view control for keyboard and controller users.
- `src/sim/game_state.gd` — keeps click-to-travel on the shared pathfinder and
  simulation rules; an explicit click advances one cell before queued travel
  stops when a threat is visible.

### Project notes

- `README.md`, `BACKLOG.md` and `CONTROLLER.md` describe the view, controls and
  current design status.

